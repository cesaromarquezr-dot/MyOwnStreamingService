-- Household chat, guardian review, profile-specific library rules, and social
-- customization metadata. Apply after streaming_service.sql, live_persistence.sql,
-- social_home.sql, and social_v2_migration.sql.

alter table public.profiles
  add column if not exists date_of_birth date,
  add column if not exists parental_controls_enabled boolean not null default false,
  add column if not exists block_explicit_music boolean not null default true,
  add column if not exists block_explicit_lyrics boolean not null default true;

alter table public.social_communities
  add column if not exists created_by_profile_id text,
  add column if not exists category text not null default 'general';

alter table public.social_conversations
  add column if not exists system_key text;

create unique index if not exists social_conversations_account_system_key_uq
  on public.social_conversations (created_by_account_id, system_key)
  where system_key is not null;

create table if not exists public.profile_guardians (
  child_profile_id uuid not null references public.profiles(id) on delete cascade,
  guardian_profile_id uuid not null references public.profiles(id) on delete cascade,
  relationship_label text not null default 'Guardian',
  created_at timestamptz not null default now(),
  primary key (child_profile_id, guardian_profile_id),
  check (child_profile_id <> guardian_profile_id)
);
create index if not exists profile_guardians_guardian_idx
  on public.profile_guardians (guardian_profile_id, child_profile_id);

create table if not exists public.profile_media_access_rules (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  decision text not null check (decision in ('allow', 'block', 'review')),
  changed_by_profile_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, media_catalog_id)
);

create table if not exists public.profile_content_preferences (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  content_level text not null default 'kids'
    check (content_level in ('little_kids','kids','older_kids','teen','mature','unrestricted','custom')),
  block_explicit_music boolean not null default true,
  block_explicit_lyrics boolean not null default true,
  block_mature_music_videos boolean not null default true,
  restrict_communities boolean not null default true,
  restrict_direct_messages boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_community_access (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  community_id uuid not null references public.social_communities(id) on delete cascade,
  decision text not null check (decision in ('allow', 'block', 'review')),
  changed_by_profile_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, community_id)
);

-- One system group chat per account; active profiles are automatically members.
create or replace function public.ensure_household_profile_conversation(p_account_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  active_profiles integer;
  conversation_uuid uuid;
  owner_profile_id text;
begin
  if p_account_id is null then return; end if;

  select count(*)::integer into active_profiles
    from public.profiles p
   where p.account_id = p_account_id
     and p.is_active = true
     and p.external_profile_id is not null;
  if active_profiles < 2 then return; end if;

  select p.external_profile_id into owner_profile_id
    from public.profiles p
   where p.account_id = p_account_id
     and p.is_active = true
     and p.external_profile_id is not null
   order by p.is_owner desc, p.created_at asc
   limit 1;

  insert into public.social_conversations (
    kind, title, created_by_account_id, created_by_profile_id, system_key
  ) values (
    'group', 'Home Server Profiles', p_account_id, owner_profile_id, 'household'
  )
  on conflict (created_by_account_id, system_key) where system_key is not null
  do nothing;

  select sc.id into conversation_uuid
    from public.social_conversations sc
   where sc.created_by_account_id = p_account_id
     and sc.system_key = 'household'
   limit 1;
  if conversation_uuid is null then return; end if;

  insert into public.social_conversation_members (conversation_id, account_id, profile_id, role)
  select conversation_uuid, p.account_id, p.external_profile_id,
         case when p.is_owner then 'owner' else 'member' end
    from public.profiles p
   where p.account_id = p_account_id
     and p.is_active = true
     and p.external_profile_id is not null
  on conflict (conversation_id, account_id, profile_id)
  do update set role = excluded.role;

  delete from public.social_conversation_members scm
   where scm.conversation_id = conversation_uuid
     and scm.account_id = p_account_id
     and not exists (
       select 1 from public.profiles p
        where p.account_id = p_account_id
          and p.is_active = true
          and p.external_profile_id = scm.profile_id
     );
end;
$function$;

create or replace function public.sync_household_profile_conversation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if tg_op = 'UPDATE' and old.account_id is distinct from new.account_id then
    perform public.ensure_household_profile_conversation(old.account_id);
  end if;
  perform public.ensure_household_profile_conversation(new.account_id);
  return new;
end;
$function$;

drop trigger if exists profiles_household_conversation_sync on public.profiles;
create trigger profiles_household_conversation_sync
  after insert or update of account_id, external_profile_id, is_active, is_owner
  on public.profiles
  for each row execute function public.sync_household_profile_conversation();

do $seed$
declare account_row record;
begin
  for account_row in
    select p.account_id from public.profiles p
     where p.is_active = true and p.external_profile_id is not null
     group by p.account_id having count(*) >= 2
  loop
    perform public.ensure_household_profile_conversation(account_row.account_id);
  end loop;
end;
$seed$;

-- Guardian review queue for inbound friend requests sent to child profiles.
alter table public.social_friendships
  add column if not exists requires_guardian_review boolean not null default false;

create table if not exists public.social_friendship_guardian_reviews (
  friendship_id uuid not null references public.social_friendships(id) on delete cascade,
  child_profile_id uuid not null references public.profiles(id) on delete cascade,
  guardian_profile_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'blocked')),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (friendship_id, guardian_profile_id)
);
create index if not exists social_friendship_guardian_reviews_queue_idx
  on public.social_friendship_guardian_reviews (guardian_profile_id, status, created_at desc);

create or replace function public.set_friend_request_guardian_review()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare child_profile public.profiles%rowtype;
begin
  select p.* into child_profile
    from public.profiles p
   where p.account_id = new.recipient_account_id
     and p.external_profile_id = new.recipient_profile_id
     and p.is_active = true
   limit 1;
  new.requires_guardian_review := false;
  if child_profile.id is not null
     and child_profile.date_of_birth is not null
     and child_profile.date_of_birth > (current_date - interval '18 years')::date
     and exists (select 1 from public.profile_guardians pg where pg.child_profile_id = child_profile.id) then
    new.requires_guardian_review := true;
  end if;
  return new;
end;
$function$;

drop trigger if exists social_friendships_guardian_review_flag on public.social_friendships;
create trigger social_friendships_guardian_review_flag
  before insert or update of recipient_account_id, recipient_profile_id
  on public.social_friendships
  for each row execute function public.set_friend_request_guardian_review();

create or replace function public.create_guardian_friendship_reviews()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare child_uuid uuid;
begin
  if new.requires_guardian_review is not true then return new; end if;
  select p.id into child_uuid from public.profiles p
   where p.account_id = new.recipient_account_id
     and p.external_profile_id = new.recipient_profile_id
     and p.is_active = true limit 1;
  if child_uuid is null then return new; end if;
  insert into public.social_friendship_guardian_reviews (
    friendship_id, child_profile_id, guardian_profile_id, status
  )
  select new.id, child_uuid, pg.guardian_profile_id, 'pending'
    from public.profile_guardians pg where pg.child_profile_id = child_uuid
  on conflict (friendship_id, guardian_profile_id) do nothing;
  return new;
end;
$function$;

drop trigger if exists social_friendships_guardian_review_create on public.social_friendships;
create trigger social_friendships_guardian_review_create
  after insert or update of requires_guardian_review
  on public.social_friendships
  for each row execute function public.create_guardian_friendship_reviews();

create or replace function public.apply_guardian_friendship_review()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare blocked_exists boolean; pending_exists boolean;
begin
  if new.status = old.status then return new; end if;
  if new.status in ('approved', 'blocked') then
    update public.social_friendship_guardian_reviews
       set reviewed_at = coalesce(reviewed_at, now())
     where friendship_id = new.friendship_id
       and guardian_profile_id = new.guardian_profile_id;
  end if;
  if new.status not in ('approved', 'blocked') then return new; end if;

  select exists (select 1 from public.social_friendship_guardian_reviews r
    where r.friendship_id = new.friendship_id and r.status = 'blocked') into blocked_exists;
  if blocked_exists then
    update public.social_friendships set status = 'declined', requires_guardian_review = false, updated_at = now()
     where id = new.friendship_id and status = 'pending';
    return new;
  end if;
  select exists (select 1 from public.social_friendship_guardian_reviews r
    where r.friendship_id = new.friendship_id and r.status = 'pending') into pending_exists;
  if not pending_exists then
    update public.social_friendships set requires_guardian_review = false, updated_at = now()
     where id = new.friendship_id and status = 'pending';
  end if;
  return new;
end;
$function$;

drop trigger if exists social_friendship_guardian_review_apply on public.social_friendship_guardian_reviews;
create trigger social_friendship_guardian_review_apply
  after update of status on public.social_friendship_guardian_reviews
  for each row execute function public.apply_guardian_friendship_review();

alter table public.profile_guardians enable row level security;
alter table public.profile_media_access_rules enable row level security;
alter table public.profile_content_preferences enable row level security;
alter table public.profile_community_access enable row level security;
alter table public.social_friendship_guardian_reviews enable row level security;

revoke all on function public.ensure_household_profile_conversation(uuid) from public, anon, authenticated;
revoke all on function public.sync_household_profile_conversation() from public, anon, authenticated;
revoke all on function public.set_friend_request_guardian_review() from public, anon, authenticated;
revoke all on function public.create_guardian_friendship_reviews() from public, anon, authenticated;
revoke all on function public.apply_guardian_friendship_review() from public, anon, authenticated;

comment on column public.profiles.date_of_birth is
  'Private birth date for guardian-managed age calculations. Never expose publicly.';
comment on column public.social_friendships.requires_guardian_review is
  'When true, hide the inbound request from the child until all guardians approve.';
