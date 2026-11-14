-- Community reviews and title-specific discussion boards.
-- Requires streaming_service.sql (accounts, profiles and my_account_id()).
create extension if not exists pgcrypto;

create table if not exists public.media_community_reviews (
  id uuid primary key default gen_random_uuid(),
  media_key text not null,
  media_title text not null,
  media_type text not null,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  profile_name text not null,
  rating smallint not null check (rating between 1 and 5),
  review_text text not null check (char_length(review_text) between 3 and 3000),
  has_play_activity boolean not null default false,
  visibility text not null default 'global' check (visibility in ('global', 'account')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (media_key, profile_id),
  check (has_play_activity = true)
);

create index if not exists media_community_reviews_media_created_idx
  on public.media_community_reviews (media_key, created_at desc);

create table if not exists public.media_discussion_threads (
  id uuid primary key default gen_random_uuid(),
  media_key text not null,
  media_title text not null,
  media_type text not null,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  profile_name text not null,
  title text not null check (char_length(title) between 3 and 120),
  body text not null check (char_length(body) between 3 and 5000),
  contains_spoilers boolean not null default false,
  visibility text not null default 'global' check (visibility in ('global', 'account')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists media_discussion_threads_media_created_idx
  on public.media_discussion_threads (media_key, created_at desc);

create table if not exists public.media_discussion_replies (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.media_discussion_threads(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  profile_name text not null,
  body text not null check (char_length(body) between 2 and 3000),
  created_at timestamptz not null default now()
);

create index if not exists media_discussion_replies_thread_created_idx
  on public.media_discussion_replies (thread_id, created_at);

-- Always derive displayed profile names from the authenticated account's own
-- profile row, never from arbitrary client-provided strings.
create or replace function public.set_media_community_profile_name()
returns trigger
language plpgsql
security invoker
as $$
declare
  resolved_name text;
begin
  select p.name into resolved_name
  from public.profiles p
  where p.id = new.profile_id
    and p.account_id = new.account_id
    and p.account_id = public.my_account_id()
    and p.is_active = true;

  if resolved_name is null then
    raise exception 'Profile does not belong to the authenticated account.';
  end if;
  new.profile_name := resolved_name;
  return new;
end;
$$;

drop trigger if exists media_community_reviews_profile_name on public.media_community_reviews;
create trigger media_community_reviews_profile_name
before insert or update of profile_id, account_id on public.media_community_reviews
for each row execute function public.set_media_community_profile_name();

drop trigger if exists media_discussion_threads_profile_name on public.media_discussion_threads;
create trigger media_discussion_threads_profile_name
before insert or update of profile_id, account_id on public.media_discussion_threads
for each row execute function public.set_media_community_profile_name();

drop trigger if exists media_discussion_replies_profile_name on public.media_discussion_replies;
create trigger media_discussion_replies_profile_name
before insert or update of profile_id, account_id on public.media_discussion_replies
for each row execute function public.set_media_community_profile_name();

alter table public.media_community_reviews enable row level security;
alter table public.media_discussion_threads enable row level security;
alter table public.media_discussion_replies enable row level security;

drop policy if exists media_community_reviews_read on public.media_community_reviews;
create policy media_community_reviews_read on public.media_community_reviews
for select to authenticated
using (visibility = 'global' or account_id = public.my_account_id());

drop policy if exists media_community_reviews_insert on public.media_community_reviews;
create policy media_community_reviews_insert on public.media_community_reviews
for insert to authenticated
with check (
  account_id = public.my_account_id()
  and has_play_activity = true
  and exists (
    select 1 from public.profiles p
    where p.id = profile_id
      and p.account_id = public.my_account_id()
      and p.is_active = true
  )
);

drop policy if exists media_community_reviews_update on public.media_community_reviews;
create policy media_community_reviews_update on public.media_community_reviews
for update to authenticated
using (account_id = public.my_account_id() and profile_id in (
  select p.id from public.profiles p where p.account_id = public.my_account_id()
))
with check (
  account_id = public.my_account_id()
  and has_play_activity = true
  and exists (
    select 1 from public.profiles p
    where p.id = profile_id
      and p.account_id = public.my_account_id()
      and p.is_active = true
  )
);

drop policy if exists media_discussion_threads_read on public.media_discussion_threads;
create policy media_discussion_threads_read on public.media_discussion_threads
for select to authenticated
using (visibility = 'global' or account_id = public.my_account_id());

drop policy if exists media_discussion_threads_insert on public.media_discussion_threads;
create policy media_discussion_threads_insert on public.media_discussion_threads
for insert to authenticated
with check (
  account_id = public.my_account_id()
  and exists (
    select 1 from public.profiles p
    where p.id = profile_id
      and p.account_id = public.my_account_id()
      and p.is_active = true
  )
);

drop policy if exists media_discussion_threads_update on public.media_discussion_threads;
create policy media_discussion_threads_update on public.media_discussion_threads
for update to authenticated
using (account_id = public.my_account_id() and profile_id in (
  select p.id from public.profiles p where p.account_id = public.my_account_id()
))
with check (account_id = public.my_account_id());

drop policy if exists media_discussion_replies_read on public.media_discussion_replies;
create policy media_discussion_replies_read on public.media_discussion_replies
for select to authenticated
using (
  exists (
    select 1 from public.media_discussion_threads t
    where t.id = thread_id
      and (t.visibility = 'global' or t.account_id = public.my_account_id())
  )
);

drop policy if exists media_discussion_replies_insert on public.media_discussion_replies;
create policy media_discussion_replies_insert on public.media_discussion_replies
for insert to authenticated
with check (
  account_id = public.my_account_id()
  and exists (
    select 1 from public.profiles p
    where p.id = profile_id
      and p.account_id = public.my_account_id()
      and p.is_active = true
  )
  and exists (
    select 1 from public.media_discussion_threads t
    where t.id = thread_id
      and (t.visibility = 'global' or t.account_id = public.my_account_id())
  )
);

grant select, insert, update on public.media_community_reviews to authenticated;
grant select, insert, update on public.media_discussion_threads to authenticated;
grant select, insert on public.media_discussion_replies to authenticated;
