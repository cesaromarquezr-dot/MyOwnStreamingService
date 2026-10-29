-- MyOwnStreamingService: repair/normalize profile presence storage.
-- Safe to re-run. Presence is ephemeral activity state; this does not touch
-- media-library, playback-progress, playlist, or account data.
begin;

create table if not exists public.social_profile_presence (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  availability text not null default 'active',
  activity_type text,
  activity_text text,
  nickname text,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id)
);

alter table public.social_profile_presence
  add column if not exists availability text default 'active',
  add column if not exists activity_type text,
  add column if not exists activity_text text,
  add column if not exists nickname text,
  add column if not exists last_seen_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

update public.social_profile_presence
set availability = 'active'
where availability is null or availability not in ('active', 'away', 'busy');

update public.social_profile_presence
set activity_type = null
where activity_type is not null
  and activity_type not in ('watching', 'listening', 'shopping', 'ordering_food', 'planning_marathon');

update public.social_profile_presence
set last_seen_at = coalesce(last_seen_at, now()),
    updated_at = coalesce(updated_at, last_seen_at, now());

alter table public.social_profile_presence
  alter column availability set default 'active',
  alter column availability set not null,
  alter column last_seen_at set default now(),
  alter column last_seen_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

-- Presence is transient. If an old schema accumulated duplicate rows, retain
-- only the freshest row per account/profile pair before enforcing uniqueness.
with ranked as (
  select ctid,
         row_number() over (
           partition by account_id, profile_id
           order by updated_at desc nulls last, last_seen_at desc nulls last, ctid desc
         ) as row_num
  from public.social_profile_presence
)
delete from public.social_profile_presence p
using ranked r
where p.ctid = r.ctid and r.row_num > 1;

create unique index if not exists social_profile_presence_account_profile_uidx
  on public.social_profile_presence(account_id, profile_id);
create index if not exists social_profile_presence_last_seen_idx
  on public.social_profile_presence(last_seen_at);

-- Replace only checks that constrain these two presence columns.
do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select conname
    from pg_constraint
    where conrelid = 'public.social_profile_presence'::regclass
      and contype = 'c'
      and (
        pg_get_constraintdef(oid) ilike '%availability%'
        or pg_get_constraintdef(oid) ilike '%activity_type%'
      )
  loop
    execute format('alter table public.social_profile_presence drop constraint %I', constraint_name);
  end loop;
end $$;

alter table public.social_profile_presence
  add constraint social_profile_presence_availability_check
    check (availability in ('active', 'away', 'busy')),
  add constraint social_profile_presence_activity_type_check
    check (activity_type is null or activity_type in (
      'watching', 'listening', 'shopping', 'ordering_food', 'planning_marathon'
    ));

alter table public.social_profile_presence enable row level security;

commit;
