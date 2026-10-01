-- Master Product Architecture persistence additions.
-- Run after the existing streaming_service.sql / membership migrations.
-- These additions are additive; existing media, radio, ARM, commerce and
-- playback tables remain intact.

-- ---------------------------------------------------------------------------
-- PROFILE GOVERNANCE
-- ---------------------------------------------------------------------------
alter table public.accounts
  add column if not exists profile_administration_policy jsonb not null default
    '{"allowMembersToManageOwnProfiles":false}'::jsonb;

alter table public.profiles
  add column if not exists governance jsonb not null default '{}'::jsonb;

comment on column public.accounts.profile_administration_policy is
  'Account-wide profile governance policy. Owner remains authoritative.';

comment on column public.profiles.governance is
  'Profile content/admin policy. Never store raw profile PINs here.';

-- ---------------------------------------------------------------------------
-- MEMBER -> PROFILE ASSIGNMENTS
-- ---------------------------------------------------------------------------
create table if not exists public.account_member_profiles (
  account_member_id uuid not null references public.account_members(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (account_member_id, profile_id)
);

create unique index if not exists idx_account_member_profiles_primary
  on public.account_member_profiles(account_member_id)
  where is_primary = true;

create index if not exists idx_account_member_profiles_profile
  on public.account_member_profiles(profile_id);

-- Backfill the legacy single profile assignment when present.
insert into public.account_member_profiles(account_member_id, profile_id, is_primary)
select id, profile_id, true
from public.account_members
where profile_id is not null
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- EVENTS / OCCASIONS / THEMES
-- ---------------------------------------------------------------------------
create table if not exists public.media_events (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  event_type text not null default 'custom'
    check (event_type in ('season','holiday','cultural','sports','special','custom')),
  theme_id uuid,
  start_month_day text,
  end_month_day text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.media_event_associations (
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  media_event_id uuid not null references public.media_events(id) on delete cascade,
  relevance numeric(5,4) not null default 1.0 check (relevance >= 0 and relevance <= 1),
  source text not null default 'editorial',
  created_at timestamptz not null default now(),
  primary key (media_catalog_id, media_event_id)
);

create index if not exists idx_media_event_associations_event
  on public.media_event_associations(media_event_id, relevance desc);

-- ---------------------------------------------------------------------------
-- LOCAL MEDIA SERVER AGENT
-- ---------------------------------------------------------------------------
create table if not exists public.media_server_agents (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  agent_id text not null,
  status text not null default 'offline'
    check (status in ('offline','online','degraded','updating')),
  storage_status text not null default 'offline'
    check (storage_status in ('offline','available','receiving','migrating','degraded')),
  nas_name text,
  total_bytes bigint not null default 0,
  free_bytes bigint not null default 0,
  current_job_id text,
  last_heartbeat_at timestamptz,
  agent_version text,
  metadata jsonb not null default '{}'::jsonb,
  unique(server_id, agent_id)
);

create index if not exists idx_media_server_agents_server
  on public.media_server_agents(server_id);

-- ---------------------------------------------------------------------------
-- LONG-RUNNING IMPORT JOBS
-- ---------------------------------------------------------------------------
create table if not exists public.media_import_jobs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  server_id uuid references public.servers(id) on delete set null,
  drive_id text,
  import_kind text not null check (import_kind in ('movie','tv','music')),
  state text not null default 'detecting'
    check (state in ('detecting','ripping','staging','analyzing','verifying','matching','review','approved','transferring','completed','failed','cancelled')),
  progress numeric(6,5) not null default 0 check (progress >= 0 and progress <= 1),
  title text,
  verified_items integer not null default 0,
  total_items integer not null default 0,
  error text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_media_import_jobs_account_updated
  on public.media_import_jobs(account_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- AUDIT CATEGORIES
-- ---------------------------------------------------------------------------
comment on table public.audit_log is
  'Security and platform audit trail. Use for profile governance, imports, server operations, commerce and permission changes.';
