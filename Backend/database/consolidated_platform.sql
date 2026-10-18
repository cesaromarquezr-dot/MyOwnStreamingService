-- CONSOLIDATED SQL BUNDLE: consolidated_platform.sql
-- Combines the following original Backend/database scripts in the listed order.
-- Review dependencies and apply to staging before production. This file is not an automatic migration runner.


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: master_product_architecture.sql
------------------------------------------------------------------------------
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
    check (event_type in ('season','holiday','cultural','special','custom')),
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
------------------------------------------------------------------------------
-- END ORIGINAL FILE: master_product_architecture.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: expanded_platform_features.sql
------------------------------------------------------------------------------
-- Expanded platform capabilities: additive Supabase schema.
-- Apply after the project's existing migrations. No media binaries or secrets
-- are stored here; personal media remains on the authorized TrueNAS/media host.

create extension if not exists pgcrypto;

create table if not exists public.user_media_scene_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  media_key text not null check (length(trim(media_key)) between 1 and 500),
  position_ms bigint not null check (position_ms >= 0),
  label text check (label is null or length(label) <= 160),
  note text check (note is null or length(note) <= 2000),
  created_at timestamptz not null default now()
);
create index if not exists idx_scene_bookmarks_user_media_position
  on public.user_media_scene_bookmarks(user_id, media_key, position_ms);

create table if not exists public.hey_media_memory_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  memory_key text not null check (length(trim(memory_key)) between 1 and 100),
  memory_value text not null check (length(trim(memory_value)) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, memory_key)
);
create index if not exists idx_hey_media_memory_updated
  on public.hey_media_memory_entries(user_id, updated_at desc);

create table if not exists public.platform_user_preferences (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  preferred_audio_languages text[] not null default '{}',
  preferred_subtitle_languages text[] not null default '{}',
  captions_enabled boolean not null default false,
  audio_description_enabled boolean not null default false,
  reduce_motion boolean not null default false,
  text_scale numeric(3,2) not null default 1.0 check (text_scale between 0.75 and 2.0),
  personalization_enabled boolean not null default true,
  ai_memory_enabled boolean not null default true,
  activity_visibility text not null default 'private'
    check (activity_visibility in ('private','friends','public')),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_notification_preferences (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  social_enabled boolean not null default true,
  order_updates_enabled boolean not null default true,
  media_jobs_enabled boolean not null default true,
  recommendations_enabled boolean not null default true,
  reminders_enabled boolean not null default true,
  quiet_hours jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.user_media_activity_timeline (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  activity_type text not null check (activity_type in
    ('started','completed','rated','reviewed','saved','imported','attended','achievement')),
  media_key text,
  title_snapshot text not null check (length(title_snapshot) <= 500),
  details jsonb not null default '{}'::jsonb,
  visibility text not null default 'private'
    check (visibility in ('private','friends','public')),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists idx_user_media_activity_timeline
  on public.user_media_activity_timeline(user_id, occurred_at desc);

create table if not exists public.user_media_collections (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 160),
  description text check (description is null or length(description) <= 2000),
  visibility text not null default 'private'
    check (visibility in ('private','friends','public')),
  is_collaborative boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_user_media_collections_owner
  on public.user_media_collections(owner_user_id, updated_at desc);

create table if not exists public.user_media_collection_items (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.user_media_collections(id) on delete cascade,
  media_key text not null check (length(trim(media_key)) between 1 and 500),
  note text check (note is null or length(note) <= 1000),
  position integer not null default 0,
  added_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(collection_id, media_key)
);
create index if not exists idx_collection_items_order
  on public.user_media_collection_items(collection_id, position, created_at);

create table if not exists public.user_shopping_wishlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null default 'My Wishlist' check (length(trim(name)) between 1 and 120),
  visibility text not null default 'private'
    check (visibility in ('private','friends','public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_shopping_wishlists_user
  on public.user_shopping_wishlists(user_id, updated_at desc);

create table if not exists public.user_shopping_wishlist_items (
  id uuid primary key default gen_random_uuid(),
  wishlist_id uuid not null references public.user_shopping_wishlists(id) on delete cascade,
  product_reference text not null check (length(trim(product_reference)) between 1 and 500),
  product_title text not null check (length(trim(product_title)) between 1 and 300),
  product_url text,
  target_price numeric(12,2) check (target_price is null or target_price >= 0),
  last_seen_price numeric(12,2) check (last_seen_price is null or last_seen_price >= 0),
  notify_on_restock boolean not null default false,
  notify_on_price_drop boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(wishlist_id, product_reference)
);

create table if not exists public.user_registered_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  device_label text not null check (length(trim(device_label)) between 1 and 160),
  device_type text not null check (device_type in ('mobile','tablet','desktop','tv','browser','other')),
  platform text,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_registered_devices_user
  on public.user_registered_devices(user_id, created_at desc);

create table if not exists public.media_scene_search_index (
  id uuid primary key default gen_random_uuid(),
  media_key text not null check (length(trim(media_key)) between 1 and 500),
  segment_key text not null,
  start_ms bigint not null check (start_ms >= 0),
  end_ms bigint check (end_ms is null or end_ms >= start_ms),
  segment_type text not null default 'caption'
    check (segment_type in ('caption','transcript','chapter','scene_description','metadata')),
  content text not null check (length(content) <= 10000),
  language_code text,
  source text not null default 'user_or_owned_library',
  created_at timestamptz not null default now(),
  unique(media_key, segment_key, language_code)
);
create index if not exists idx_media_scene_search_media_time
  on public.media_scene_search_index(media_key, start_ms);

create table if not exists public.platform_clubs (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  description text check (description is null or length(description) <= 3000),
  topic text not null default 'general',
  visibility text not null default 'private'
    check (visibility in ('private','invite_only','public')),
  moderation_settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.platform_club_members (
  club_id uuid not null references public.platform_clubs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','moderator','member')),
  status text not null default 'active' check (status in ('invited','active','muted','banned')),
  joined_at timestamptz not null default now(),
  primary key(club_id, user_id)
);
create table if not exists public.platform_club_events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.platform_clubs(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 200),
  starts_at timestamptz not null,
  ends_at timestamptz,
  media_key text,
  spoiler_policy jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);
create table if not exists public.platform_club_event_rsvps (
  event_id uuid not null references public.platform_club_events(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  response text not null default 'going' check (response in ('going','interested','not_going')),
  updated_at timestamptz not null default now(),
  primary key(event_id, user_id)
);

create table if not exists public.creator_workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 200),
  description text,
  status text not null default 'draft' check (status in ('draft','in_review','scheduled','published','archived')),
  scheduled_at timestamptz,
  revision integer not null default 1 check (revision > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.creator_workspace_members (
  workspace_id uuid not null references public.creator_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'reviewer' check (role in ('owner','editor','reviewer','viewer')),
  created_at timestamptz not null default now(),
  primary key(workspace_id, user_id)
);

create table if not exists public.platform_events (
  id uuid primary key default gen_random_uuid(),
  organizer_user_id uuid references auth.users(id) on delete set null,
  title text not null check (length(trim(title)) between 1 and 240),
  description text,
  event_type text not null default 'screening'
    check (event_type in ('screening','concert','fan_event','community_meetup','other')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  venue_name text,
  venue_address text,
  accessibility_info jsonb not null default '{}'::jsonb,
  ticket_url text,
  status text not null default 'draft' check (status in ('draft','published','cancelled','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);
create table if not exists public.platform_event_rsvps (
  event_id uuid not null references public.platform_events(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  response text not null default 'interested' check (response in ('going','interested','not_going')),
  updated_at timestamptz not null default now(),
  primary key(event_id, user_id)
);

-- External subscriptions are user-entered or imported with explicit consent;
-- this table must never hold provider passwords or session tokens.
create table if not exists public.user_subscription_tracker (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  service_name text not null check (length(trim(service_name)) between 1 and 160),
  monthly_cost numeric(12,2) check (monthly_cost is null or monthly_cost >= 0),
  currency_code char(3),
  renewal_at timestamptz,
  billing_period text not null default 'monthly' check (billing_period in ('weekly','monthly','quarterly','yearly','other')),
  reminder_enabled boolean not null default true,
  source text not null default 'manual' check (source in ('manual','authorized_integration')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_gift_records (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  recipient_label text,
  gift_type text not null check (gift_type in ('gift_card','eligible_subscription','merchandise','restaurant_voucher','group_contribution','other')),
  provider_reference text,
  scheduled_for timestamptz,
  status text not null default 'draft' check (status in ('draft','purchased','scheduled','sent','redeemed','cancelled','refunded')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_playback_diagnostics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  media_key text,
  device_type text,
  issue_type text not null check (issue_type in ('buffering','unsupported_codec','missing_media','network','subtitle_sync','audio_track','other')),
  summary text not null check (length(trim(summary)) between 1 and 500),
  diagnostic_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_playback_diagnostics_user
  on public.user_playback_diagnostics(user_id, created_at desc);

create table if not exists public.platform_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  notification_type text not null,
  channel text not null default 'in_app' check (channel in ('in_app','push','email')),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check (status in ('queued','sending','sent','failed','cancelled')),
  available_at timestamptz not null default now(),
  sent_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error text,
  created_at timestamptz not null default now()
);
create index if not exists idx_notification_outbox_claim
  on public.platform_notification_outbox(status, available_at, created_at)
  where status in ('queued','failed');

create table if not exists public.platform_rewards_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null,
  points_delta integer not null,
  description text not null check (length(trim(description)) between 1 and 300),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(user_id, event_key)
);

create table if not exists public.platform_background_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  resource_key text,
  status text not null default 'queued'
    check (status in ('queued','running','retrying','completed','failed','cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  max_attempts integer not null default 5 check (max_attempts > 0),
  progress numeric(6,5) not null default 0 check (progress between 0 and 1),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  last_error text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_platform_jobs_claim
  on public.platform_background_jobs(status, available_at, created_at)
  where status in ('queued','retrying');

create table if not exists public.platform_feature_flags (
  flag_key text primary key check (length(trim(flag_key)) between 1 and 120),
  description text,
  enabled_globally boolean not null default false,
  rollout_percent integer not null default 0 check (rollout_percent between 0 and 100),
  updated_at timestamptz not null default now()
);
create table if not exists public.platform_feature_flag_assignments (
  flag_key text not null references public.platform_feature_flags(flag_key) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  enabled boolean not null,
  created_at timestamptz not null default now(),
  primary key(flag_key, user_id)
);

create table if not exists public.platform_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null check (length(trim(action)) between 1 and 160),
  resource_type text,
  resource_key text,
  outcome text not null default 'success' check (outcome in ('success','denied','failure')),
  request_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_platform_audit_events_created
  on public.platform_audit_events(created_at desc);

create table if not exists public.user_library_health_findings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  media_key text,
  finding_type text not null check (finding_type in
    ('duplicate','missing_file','missing_episode','metadata_mismatch','unavailable_server','corrupt_file','missing_artwork','other')),
  severity text not null default 'info' check (severity in ('info','warning','error')),
  summary text not null check (length(trim(summary)) between 1 and 500),
  details jsonb not null default '{}'::jsonb,
  resolution_status text not null default 'open'
    check (resolution_status in ('open','dismissed','resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_library_health_user_status
  on public.user_library_health_findings(user_id, resolution_status, created_at desc);

-- Row-level security: private user-owned data is only visible to its owner.
alter table public.user_media_scene_bookmarks enable row level security;
drop policy if exists scene_bookmarks_owner_all on public.user_media_scene_bookmarks;
create policy scene_bookmarks_owner_all on public.user_media_scene_bookmarks
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.hey_media_memory_entries enable row level security;
drop policy if exists hey_media_memory_owner_all on public.hey_media_memory_entries;
create policy hey_media_memory_owner_all on public.hey_media_memory_entries
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.platform_user_preferences enable row level security;
drop policy if exists platform_user_preferences_owner_all on public.platform_user_preferences;
create policy platform_user_preferences_owner_all on public.platform_user_preferences
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.platform_notification_preferences enable row level security;
drop policy if exists platform_notification_preferences_owner_all on public.platform_notification_preferences;
create policy platform_notification_preferences_owner_all on public.platform_notification_preferences
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.user_media_activity_timeline enable row level security;
drop policy if exists activity_timeline_owner_all on public.user_media_activity_timeline;
create policy activity_timeline_owner_all on public.user_media_activity_timeline
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.user_media_collections enable row level security;
drop policy if exists media_collections_owner_all on public.user_media_collections;
create policy media_collections_owner_all on public.user_media_collections
  for all to authenticated using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
alter table public.user_media_collection_items enable row level security;
drop policy if exists media_collection_items_owner_all on public.user_media_collection_items;
create policy media_collection_items_owner_all on public.user_media_collection_items
  for all to authenticated using (exists (select 1 from public.user_media_collections c where c.id = collection_id and c.owner_user_id = auth.uid()))
  with check (exists (select 1 from public.user_media_collections c where c.id = collection_id and c.owner_user_id = auth.uid()));

alter table public.user_shopping_wishlists enable row level security;
drop policy if exists shopping_wishlists_owner_all on public.user_shopping_wishlists;
create policy shopping_wishlists_owner_all on public.user_shopping_wishlists
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
alter table public.user_shopping_wishlist_items enable row level security;
drop policy if exists shopping_wishlist_items_owner_all on public.user_shopping_wishlist_items;
create policy shopping_wishlist_items_owner_all on public.user_shopping_wishlist_items
  for all to authenticated using (exists (select 1 from public.user_shopping_wishlists w where w.id = wishlist_id and w.user_id = auth.uid()))
  with check (exists (select 1 from public.user_shopping_wishlists w where w.id = wishlist_id and w.user_id = auth.uid()));

alter table public.user_registered_devices enable row level security;
drop policy if exists registered_devices_owner_all on public.user_registered_devices;
create policy registered_devices_owner_all on public.user_registered_devices
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Search index is writable only by trusted server/service role. Authenticated
-- clients can search only through a backend endpoint that enforces media access.
alter table public.media_scene_search_index enable row level security;
drop policy if exists media_scene_search_service_only on public.media_scene_search_index;
create policy media_scene_search_service_only on public.media_scene_search_index
  for all to service_role using (true) with check (true);

alter table public.platform_clubs enable row level security;
drop policy if exists clubs_owner_all on public.platform_clubs;
create policy clubs_owner_all on public.platform_clubs
  for all to authenticated using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
alter table public.platform_club_members enable row level security;
drop policy if exists club_members_self_or_owner on public.platform_club_members;
create policy club_members_self_or_owner on public.platform_club_members
  for all to authenticated using (
    user_id = auth.uid() or exists (select 1 from public.platform_clubs c where c.id = club_id and c.owner_user_id = auth.uid())
  ) with check (
    user_id = auth.uid() or exists (select 1 from public.platform_clubs c where c.id = club_id and c.owner_user_id = auth.uid())
  );
alter table public.platform_club_events enable row level security;
drop policy if exists club_events_owner_or_member on public.platform_club_events;
create policy club_events_owner_or_member on public.platform_club_events
  for all to authenticated using (
    created_by = auth.uid() or exists (select 1 from public.platform_clubs c where c.id = club_id and c.owner_user_id = auth.uid())
    or exists (select 1 from public.platform_club_members m where m.club_id = platform_club_events.club_id and m.user_id = auth.uid() and m.status = 'active')
  ) with check (
    created_by = auth.uid() or exists (select 1 from public.platform_clubs c where c.id = club_id and c.owner_user_id = auth.uid())
    or exists (select 1 from public.platform_club_members m where m.club_id = platform_club_events.club_id and m.user_id = auth.uid() and m.status = 'active')
  );
alter table public.platform_club_event_rsvps enable row level security;
drop policy if exists club_event_rsvps_owner_all on public.platform_club_event_rsvps;
create policy club_event_rsvps_owner_all on public.platform_club_event_rsvps
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.creator_workspaces enable row level security;
drop policy if exists creator_workspaces_owner_all on public.creator_workspaces;
create policy creator_workspaces_owner_all on public.creator_workspaces
  for all to authenticated using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
alter table public.creator_workspace_members enable row level security;
drop policy if exists creator_workspace_members_owner_or_self on public.creator_workspace_members;
create policy creator_workspace_members_owner_or_self on public.creator_workspace_members
  for all to authenticated using (
    user_id = auth.uid() or exists (select 1 from public.creator_workspaces w where w.id = workspace_id and w.owner_user_id = auth.uid())
  ) with check (
    user_id = auth.uid() or exists (select 1 from public.creator_workspaces w where w.id = workspace_id and w.owner_user_id = auth.uid())
  );

alter table public.platform_event_rsvps enable row level security;
drop policy if exists event_rsvps_owner_all on public.platform_event_rsvps;
create policy event_rsvps_owner_all on public.platform_event_rsvps
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.user_subscription_tracker enable row level security;
drop policy if exists subscription_tracker_owner_all on public.user_subscription_tracker;
create policy subscription_tracker_owner_all on public.user_subscription_tracker
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.user_gift_records enable row level security;
drop policy if exists gift_records_sender_all on public.user_gift_records;
create policy gift_records_sender_all on public.user_gift_records
  for all to authenticated using (sender_user_id = auth.uid()) with check (sender_user_id = auth.uid());

alter table public.user_playback_diagnostics enable row level security;
drop policy if exists playback_diagnostics_owner_all on public.user_playback_diagnostics;
create policy playback_diagnostics_owner_all on public.user_playback_diagnostics
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.platform_rewards_ledger enable row level security;
drop policy if exists rewards_ledger_owner_read on public.platform_rewards_ledger;
create policy rewards_ledger_owner_read on public.platform_rewards_ledger
  for select to authenticated using (user_id = auth.uid());

-- Operations-only tables: RLS is enabled with no authenticated-user policy.
-- Backend workers must use service-role credentials server-side only.
alter table public.platform_background_jobs enable row level security;
alter table public.platform_feature_flags enable row level security;
alter table public.platform_feature_flag_assignments enable row level security;
alter table public.platform_audit_events enable row level security;
alter table public.platform_notification_outbox enable row level security;
alter table public.platform_events enable row level security;
drop policy if exists platform_events_published_read on public.platform_events;
create policy platform_events_published_read on public.platform_events
  for select to authenticated using (status = 'published' or organizer_user_id = auth.uid());
drop policy if exists platform_events_owner_write on public.platform_events;
create policy platform_events_owner_write on public.platform_events
  for all to authenticated using (organizer_user_id = auth.uid()) with check (organizer_user_id = auth.uid());

alter table public.user_library_health_findings enable row level security;
drop policy if exists library_health_owner_all on public.user_library_health_findings;
create policy library_health_owner_all on public.user_library_health_findings
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

comment on table public.hey_media_memory_entries is
  'Explicit, user-managed Hey Media preferences/memory. Do not store credentials, secrets, or sensitive inferred attributes.';
comment on table public.platform_background_jobs is
  'Durable asynchronous work queue; only trusted server workers may read or mutate jobs.';
comment on table public.media_scene_search_index is
  'Index only content the requesting user is authorized to access; query via a permission-checking backend endpoint.';
comment on table public.platform_audit_events is
  'Security and operational audit metadata. Never put tokens, passwords, or payment credentials in details.';
------------------------------------------------------------------------------
-- END ORIGINAL FILE: expanded_platform_features.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: expanded_platform_phase2.sql
------------------------------------------------------------------------------
-- Phase 2 foundations for proactive Hey Media, themed spaces, provenance,
-- franchise ordering, NAS health and recovery. Media binaries stay on TrueNAS.
create extension if not exists pgcrypto;

create table if not exists public.user_hey_media_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  suggestion_type text not null check (length(trim(suggestion_type)) between 1 and 80),
  title text not null check (length(trim(title)) between 1 and 160),
  body text not null check (length(trim(body)) between 1 and 2000),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','accepted','dismissed','expired')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_hey_media_suggestions_user_status
  on public.user_hey_media_suggestions(user_id, status, created_at desc);
alter table public.user_hey_media_suggestions enable row level security;
drop policy if exists "Users read own Hey Media suggestions" on public.user_hey_media_suggestions;
create policy "Users read own Hey Media suggestions" on public.user_hey_media_suggestions
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users dismiss own Hey Media suggestions" on public.user_hey_media_suggestions;
create policy "Users dismiss own Hey Media suggestions" on public.user_hey_media_suggestions
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
-- Suggestions should be created by a trusted backend, not by arbitrary clients.

create table if not exists public.user_media_spaces (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  description text check (description is null or length(description) <= 2000),
  artwork_reference text,
  visibility text not null default 'private' check (visibility in ('private','friends','public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(id, user_id)
);
create index if not exists idx_user_media_spaces_owner_created
  on public.user_media_spaces(user_id, created_at desc);
alter table public.user_media_spaces enable row level security;
drop policy if exists "Users manage own media spaces" on public.user_media_spaces;
create policy "Users manage own media spaces" on public.user_media_spaces
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.user_media_space_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  space_id uuid not null,
  media_key text not null check (length(trim(media_key)) between 1 and 500),
  sort_order integer not null default 0,
  added_at timestamptz not null default now(),
  foreign key (space_id, user_id) references public.user_media_spaces(id, user_id) on delete cascade,
  unique(space_id, media_key)
);
create index if not exists idx_media_space_items_order
  on public.user_media_space_items(user_id, space_id, sort_order);
alter table public.user_media_space_items enable row level security;
drop policy if exists "Users manage own media space items" on public.user_media_space_items;
create policy "Users manage own media space items" on public.user_media_space_items
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.user_media_metadata_provenance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  media_key text not null check (length(trim(media_key)) between 1 and 500),
  field_name text not null check (length(trim(field_name)) between 1 and 120),
  source_type text not null check (length(trim(source_type)) between 1 and 80),
  source_reference text,
  confidence numeric(4,3) check (confidence is null or confidence between 0 and 1),
  observed_value jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_media_provenance_owner_media
  on public.user_media_metadata_provenance(user_id, media_key, field_name, created_at desc);
alter table public.user_media_metadata_provenance enable row level security;
drop policy if exists "Users manage own metadata provenance" on public.user_media_metadata_provenance;
create policy "Users manage own metadata provenance" on public.user_media_metadata_provenance
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.user_franchise_viewing_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  franchise_key text not null check (length(trim(franchise_key)) between 1 and 300),
  title text not null check (length(trim(title)) between 1 and 160),
  order_kind text not null check (order_kind in ('release','chronological','recommended','completionist','custom')),
  entries jsonb not null default '[]'::jsonb check (jsonb_typeof(entries) = 'array'),
  spoiler_warning text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, franchise_key, title)
);
create index if not exists idx_franchise_orders_user
  on public.user_franchise_viewing_orders(user_id, franchise_key);
alter table public.user_franchise_viewing_orders enable row level security;
drop policy if exists "Users manage own franchise orders" on public.user_franchise_viewing_orders;
create policy "Users manage own franchise orders" on public.user_franchise_viewing_orders
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Backend-written health results: no authenticated client policies by design.
create table if not exists public.user_storage_health_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_source_key text not null check (length(trim(storage_source_key)) between 1 and 200),
  check_type text not null check (check_type in ('capacity','integrity','backup','connectivity','disk_health')),
  status text not null check (status in ('healthy','warning','failed','unknown')),
  details jsonb not null default '{}'::jsonb,
  checked_at timestamptz not null default now()
);
create index if not exists idx_storage_health_owner_time
  on public.user_storage_health_checks(user_id, checked_at desc);
alter table public.user_storage_health_checks enable row level security;

-- User may open and read their own recovery request. Status changes are backend-owned.
create table if not exists public.user_recovery_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  request_type text not null check (request_type in ('playback','import','metadata','account','other')),
  summary text not null check (length(trim(summary)) between 1 and 500),
  details jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_recovery_requests_owner_status
  on public.user_recovery_requests(user_id, status, created_at desc);
alter table public.user_recovery_requests enable row level security;
drop policy if exists "Users read own recovery requests" on public.user_recovery_requests;
create policy "Users read own recovery requests" on public.user_recovery_requests
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users create own recovery requests" on public.user_recovery_requests;
create policy "Users create own recovery requests" on public.user_recovery_requests
  for insert to authenticated with check (user_id = auth.uid());

-- Integration registry is controlled by trusted operators; no client policies.
create table if not exists public.platform_integration_registry (
  id uuid primary key default gen_random_uuid(),
  integration_key text not null unique check (length(trim(integration_key)) between 1 and 100),
  display_name text not null check (length(trim(display_name)) between 1 and 160),
  status text not null default 'disabled' check (status in ('disabled','testing','enabled','deprecated')),
  required_scopes text[] not null default '{}',
  rate_limit_per_minute integer not null default 60 check (rate_limit_per_minute between 1 and 100000),
  configuration jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.platform_integration_registry enable row level security;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: expanded_platform_phase2.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: platform_servers_and_tv_pairing.sql
------------------------------------------------------------------------------
-- Cross-server infrastructure and TV device pairing for MyOwnStreamingService.
-- This migration intentionally does not alter the legacy `servers` table, whose current
-- design is one home server per account. The new platform_servers layer supports a
-- warehouse with many claimable servers.

create extension if not exists pgcrypto;

create table if not exists platform_warehouses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  status text not null default 'online',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists platform_servers (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references platform_warehouses(id) on delete cascade,
  name text not null,
  status text not null default 'available',
  storage_total_bytes bigint not null default 0,
  storage_used_bytes bigint not null default 0,
  ram_gb integer not null default 0,
  cpu_cores integer not null default 0,
  ssh_enabled boolean not null default false,
  endpoint text,
  claimed_account_id uuid references accounts(id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_platform_servers_available
  on platform_servers(status, claimed_account_id);
create index if not exists idx_platform_servers_warehouse
  on platform_servers(warehouse_id);

create table if not exists platform_server_assignments (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  server_id uuid not null references platform_servers(id) on delete cascade,
  display_name text not null,
  role text not null default 'owner',
  assigned_at timestamptz not null default now(),
  released_at timestamptz
);

create unique index if not exists uq_platform_server_active_account
  on platform_server_assignments(account_id)
  where released_at is null;
create unique index if not exists uq_platform_server_active_server
  on platform_server_assignments(server_id)
  where released_at is null;

create table if not exists tv_pairings (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  tv_device_id text not null,
  tv_device_name text not null,
  pairing_code_hash text not null,
  status text not null default 'pending',
  phone_device_id text,
  phone_profile_id text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  paired_at timestamptz
);

create index if not exists idx_tv_pairings_code on tv_pairings(pairing_code_hash);
create index if not exists idx_tv_pairings_account on tv_pairings(account_id, status);

-- Development/demo inventory: two warehouses with 25 servers each. Replace these
-- inventory rows with real hardware records in production.
do $$
declare
  north_id uuid := '00000000-0000-0000-0000-000000000101';
  south_id uuid := '00000000-0000-0000-0000-000000000102';
begin
  insert into platform_warehouses(id, name, location, status)
    values
      (north_id, 'North Warehouse', 'Primary region', 'online'),
      (south_id, 'South Warehouse', 'Secondary region', 'online')
  on conflict (id) do nothing;

  if not exists (select 1 from platform_servers limit 1) then
    insert into platform_servers(
      warehouse_id, name, status, storage_total_bytes, storage_used_bytes,
      ram_gb, cpu_cores, ssh_enabled, endpoint
    )
    select
      case when n <= 25 then north_id else south_id end,
      'Server ' || lpad(case when n <= 25 then n::text else (n - 25)::text end, 2, '0'),
      'available',
      case when mod(n, 2) = 0 then 40 else 30 end * 1024::bigint * 1024 * 1024 * 1024 * 1024,
      (case when mod(n, 2) = 0 then 7 else 5 end + mod(n, 5)) * 1024::bigint * 1024 * 1024 * 1024 * 1024 / 10,
      case when mod(n, 2) = 0 then 128 else 96 end,
      case when mod(n, 2) = 0 then 32 else 24 end,
      true,
      'server-' || n || '.local'
    from generate_series(1, 50) as series(n);
  end if;
end $$;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: platform_servers_and_tv_pairing.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: tv_channels.sql
------------------------------------------------------------------------------
-- Account-owned TV channel + content intelligence persistence.
-- Channels are created by the account. The scheduler may regenerate schedules
-- only from the contents assigned to each account-owned channel. No themed
-- channel catalog is generated by the platform.
--
-- pgcrypto is enabled by the platform_and_games.sql migration.

create table if not exists public.tv_channel_definitions (
  id uuid text primary key,
  account_id uuid,
  name text not null,
  description text not null default '',
  filters jsonb not null default '[]'::jsonb,
  content_types jsonb not null default '["Movies", "Shows"]'::jsonb,
  seasonal boolean not null default false,
  priority integer not null default 0,
  programming_rules jsonb not null default '[]'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tv_content_intelligence (
  media_id text primary key,
  account_id uuid,
  genres jsonb not null default '[]'::jsonb,
  tags jsonb not null default '[]'::jsonb,
  studios jsonb not null default '[]'::jsonb,
  companies jsonb not null default '[]'::jsonb,
  franchises jsonb not null default '[]'::jsonb,
  holidays jsonb not null default '[]'::jsonb,
  audiences jsonb not null default '[]'::jsonb,
  themes jsonb not null default '[]'::jsonb,
  is_episode boolean not null default false,
  is_movie boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.tv_program_schedules (
  id uuid primary key default gen_random_uuid(),
  account_id uuid,
  profile_id uuid,
  channel_id text not null,
  generated_at timestamptz not null default now(),
  season text,
  lineup jsonb not null default '[]'::jsonb,
  constraint tv_program_schedules_account_profile_channel_unique
    unique (account_id, profile_id, channel_id)
);

create index if not exists idx_tv_channel_definitions_account
  on public.tv_channel_definitions(account_id);

create index if not exists idx_tv_content_intelligence_account
  on public.tv_content_intelligence(account_id);

create index if not exists idx_tv_program_schedules_profile
  on public.tv_program_schedules(profile_id);
------------------------------------------------------------------------------
-- END ORIGINAL FILE: tv_channels.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: external_provider_migration.sql
------------------------------------------------------------------------------
create table if not exists public.external_provider_links (
  id uuid primary key default gen_random_uuid(),
  media_id text not null,
  provider text not null,
  provider_media_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique(media_id, provider)
);
create index if not exists idx_external_provider_links_lookup on public.external_provider_links(provider, provider_media_id);
------------------------------------------------------------------------------
-- END ORIGINAL FILE: external_provider_migration.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: library_release_migration.sql
------------------------------------------------------------------------------
-- Account-wide scheduled library publication. The physical file remains on the home NAS.
create table if not exists public.library_additions (
  id text primary key,
  account_id text not null,
  server_media_id text not null,
  title text not null,
  media_type text not null,
  scheduled_for timestamptz not null,
  scheduled_timezone text not null default 'UTC',
  status text not null default 'scheduled' check (status in ('scheduled','published','cancelled','failed')),
  created_at timestamptz not null default now(),
  published_at timestamptz,
  cancelled_at timestamptz
);
create index if not exists idx_library_additions_account_schedule on public.library_additions(account_id, scheduled_for);
create index if not exists idx_library_additions_status_schedule on public.library_additions(status, scheduled_for);
comment on table public.library_additions is 'Controls account-library publication timing; physical media remains on the account NAS and is shared by account members.';
------------------------------------------------------------------------------
-- END ORIGINAL FILE: library_release_migration.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: ratings_migration.sql
------------------------------------------------------------------------------
-- FILE: `Backend/database/ratings_migration.sql`.
-- Purpose: Adds durable storage for external rating snapshots and profile ratings.
-- No passwords, API keys, or media files are stored here.
----------------------------------------------------------

-- External/provider ratings and personal profile ratings remain separate.
-- Provider scores are cached snapshots and are never combined with profile
-- ratings or public reviews.

create table if not exists public.media_external_ratings (
id uuid primary key default gen_random_uuid(),
media_id text not null,
provider text not null,
rating_kind text not null,
value numeric not null,
scale numeric not null,
vote_count integer,
source_url text,
updated_at timestamptz not null default now(),

unique(media_id, provider, rating_kind)
);

create table if not exists public.profile_media_ratings (
id uuid primary key default gen_random_uuid(),
account_id text not null,
profile_id text not null,
media_id text not null,

-- Personal ratings are limited to 0.5 through 5.0 in 0.5-star steps.
stars numeric not null
check (
stars >= 0.5
and stars <= 5
and stars * 2 = trunc(stars * 2)
),

updated_at timestamptz not null default now(),

unique(account_id, profile_id, media_id)
);

create index if not exists idx_media_external_ratings_media
on public.media_external_ratings(media_id);

create index if not exists idx_profile_media_ratings_profile
on public.profile_media_ratings(profile_id, media_id);

create index if not exists idx_media_external_ratings_provider
on public.media_external_ratings(provider, rating_kind);

comment on table public.media_external_ratings is
'Cached provider rating snapshots; provider scores remain separate and are not combined.';

comment on table public.profile_media_ratings is
'Private profile ratings from 0.5 to 5 stars in 0.5-star increments; separate from public reviews and external ratings.';

comment on column public.media_external_ratings.value is
'Rating value reported by the provider.';

comment on column public.media_external_ratings.scale is
'Maximum rating value used by the provider, such as 5 or 10.';

comment on column public.profile_media_ratings.stars is
'Personal profile rating from 0.5 to 5.0 stars in 0.5-star increments.';
------------------------------------------------------------------------------
-- END ORIGINAL FILE: ratings_migration.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: discovery_catalog.sql
------------------------------------------------------------------------------
-- External discovery metadata is deliberately separate from NAS-owned files.
-- Apply with the Supabase SQL editor or your normal migration runner.
create table if not exists public.external_media_catalog (
  id text primary key,
  media_type text not null check (media_type in ('movie','series','season','episode','song','album','artist','music_video')),
  title text not null,
  original_title text,
  description text,
  release_year integer,
  artwork_url text,
  external_ids jsonb not null default '{}'::jsonb,
  genres text[] not null default '{}',
  people jsonb not null default '[]'::jsonb,
  metadata_source text,
  metadata_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists external_media_catalog_title_idx on public.external_media_catalog using gin (to_tsvector('simple', title));
create index if not exists external_media_catalog_type_idx on public.external_media_catalog (media_type, title);

create table if not exists public.external_media_offers (
  id bigint generated by default as identity primary key,
  catalog_id text not null references public.external_media_catalog(id) on delete cascade,
  retailer text not null,
  offer_type text not null check (offer_type in ('purchase','rental','subscription','physical_new','physical_used','search')),
  region_code text not null default 'US',
  format text,
  url text not null,
  price numeric(12,2),
  currency text,
  availability_status text not null default 'unknown' check (availability_status in ('available','unavailable','unknown')),
  verified_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (catalog_id, retailer, offer_type, region_code, format, url)
);
create index if not exists external_media_offers_lookup_idx on public.external_media_offers (catalog_id, region_code, offer_type);

create table if not exists public.music_artist_metadata (
  catalog_id text primary key references public.external_media_catalog(id) on delete cascade,
  display_name text not null,
  biography text,
  image_url text,
  genres text[] not null default '{}',
  external_ids jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.music_album_metadata (
  catalog_id text primary key references public.external_media_catalog(id) on delete cascade,
  artist_catalog_id text references public.music_artist_metadata(catalog_id) on delete set null,
  release_date date,
  album_type text not null default 'album' check (album_type in ('album','re-recorded','ep','single','compilation','live','soundtrack')),
  edition_name text,
  track_listing jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.music_artist_relations (
  artist_catalog_id text not null references public.music_artist_metadata(catalog_id) on delete cascade,
  related_artist_catalog_id text not null references public.music_artist_metadata(catalog_id) on delete cascade,
  relation_type text not null default 'fans_also_like' check (relation_type in ('fans_also_like','collaborator','same_genre','label_mate')),
  score numeric(8,5),
  source text,
  updated_at timestamptz not null default now(),
  primary key (artist_catalog_id, related_artist_catalog_id, relation_type),
  check (artist_catalog_id <> related_artist_catalog_id)
);

create table if not exists public.music_chart_entries (
  id bigint generated by default as identity primary key,
  track_catalog_id text not null references public.external_media_catalog(id) on delete cascade,
  chart_name text not null,
  region_code text not null default 'global',
  rank integer,
  chart_date date not null,
  source text not null,
  unique (track_catalog_id, chart_name, region_code, chart_date, source)
);
create index if not exists music_chart_entries_rank_idx on public.music_chart_entries (chart_name, region_code, chart_date desc, rank);

alter table public.external_media_catalog enable row level security;
alter table public.external_media_offers enable row level security;
alter table public.music_artist_metadata enable row level security;
alter table public.music_album_metadata enable row level security;
alter table public.music_artist_relations enable row level security;
alter table public.music_chart_entries enable row level security;

drop policy if exists "External catalog metadata is readable by authenticated users" on public.external_media_catalog;
create policy "External catalog metadata is readable by authenticated users" on public.external_media_catalog for select to authenticated using (true);
drop policy if exists "External offers are readable by authenticated users" on public.external_media_offers;
create policy "External offers are readable by authenticated users" on public.external_media_offers for select to authenticated using (true);
drop policy if exists "Artist metadata is readable by authenticated users" on public.music_artist_metadata;
create policy "Artist metadata is readable by authenticated users" on public.music_artist_metadata for select to authenticated using (true);
drop policy if exists "Album metadata is readable by authenticated users" on public.music_album_metadata;
create policy "Album metadata is readable by authenticated users" on public.music_album_metadata for select to authenticated using (true);
drop policy if exists "Artist relations are readable by authenticated users" on public.music_artist_relations;
create policy "Artist relations are readable by authenticated users" on public.music_artist_relations for select to authenticated using (true);
drop policy if exists "Music chart entries are readable by authenticated users" on public.music_chart_entries;
create policy "Music chart entries are readable by authenticated users" on public.music_chart_entries for select to authenticated using (true);
-- Intentionally no client INSERT/UPDATE/DELETE policies. Populate these tables
-- only through a trusted backend/Edge Function using service-role credentials.
------------------------------------------------------------------------------
-- END ORIGINAL FILE: discovery_catalog.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: entertainment_studio_records.sql
------------------------------------------------------------------------------
-- Entertainment Studio local-first records with authenticated cloud sync.
-- Apply to staging first. All rows are owned by the Supabase auth user; the
-- client never supplies user_id. Profile-specific data carries profileId in
-- record_data and clients query that scope. Household watchlists intentionally
-- share a record type among profiles of the same authenticated account.

create extension if not exists pgcrypto;

create table if not exists public.user_entertainment_studio_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  record_type text not null check (record_type in (
    'calendar', 'journal', 'scenes', 'editions', 'watchlist',
    'subtitles', 'theories', 'presets'
  )),
  record_data jsonb not null check (jsonb_typeof(record_data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (octet_length(record_data::text) <= 16000)
);

create index if not exists idx_entertainment_studio_user_kind_updated
  on public.user_entertainment_studio_records(user_id, record_type, updated_at desc);
create index if not exists idx_entertainment_studio_data_profile
  on public.user_entertainment_studio_records using gin (record_data jsonb_path_ops);

alter table public.user_entertainment_studio_records enable row level security;
drop policy if exists entertainment_studio_owner_all on public.user_entertainment_studio_records;
create policy entertainment_studio_owner_all
  on public.user_entertainment_studio_records
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.set_entertainment_studio_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists trg_entertainment_studio_updated_at on public.user_entertainment_studio_records;
create trigger trg_entertainment_studio_updated_at
before update on public.user_entertainment_studio_records
for each row execute function public.set_entertainment_studio_updated_at();

comment on table public.user_entertainment_studio_records is
  'Private Entertainment Studio records. Row-level security restricts records to their authenticated owner. Household watchlists can be shared only among profiles using that same authenticated account; friend-group sharing requires an explicit membership/ACL design.';
------------------------------------------------------------------------------
-- END ORIGINAL FILE: entertainment_studio_records.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: streaming_experience_telemetry.sql
------------------------------------------------------------------------------
-- Streaming Experience: QoE telemetry, discovery feedback, and per-profile settings.
--
-- IMPORTANT: app account/profile ids are application identifiers, not assumed
-- to be auth.uid() UUIDs. RLS is enabled with no client policies on purpose.
-- Only a trusted backend/Edge Function using the Supabase service role should
-- read/write these records after validating the authenticated account/profile.
-- Never put the service-role key in Flutter.

create table if not exists public.streaming_playback_qoe_events (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  media_id text not null,
  session_id text not null,
  event_type text not null check (event_type in (
    'play_requested', 'player_ready', 'buffer_start', 'buffer_end',
    'seek', 'paused', 'resumed', 'playback_error', 'completed'
  )),
  occurred_at timestamptz not null default now(),
  value_ms integer check (value_ms is null or value_ms >= 0),
  device_class text check (device_class is null or device_class in ('mobile', 'desktop', 'tv', 'web', 'unknown')),
  metadata jsonb not null default '{}'::jsonb,
  ingested_at timestamptz not null default now()
);

create index if not exists streaming_qoe_profile_time_idx
  on public.streaming_playback_qoe_events (account_id, profile_id, occurred_at desc);
create index if not exists streaming_qoe_session_idx
  on public.streaming_playback_qoe_events (session_id, occurred_at);
create index if not exists streaming_qoe_type_time_idx
  on public.streaming_playback_qoe_events (event_type, occurred_at desc);

create table if not exists public.streaming_discovery_feedback (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  media_id text not null,
  action text not null check (action in (
    'like', 'dislike', 'not_interested', 'play', 'complete',
    'search_open', 'add_to_collection', 'share', 'skip'
  )),
  source text not null default 'unknown',
  occurred_at timestamptz not null default now(),
  context jsonb not null default '{}'::jsonb
);

create index if not exists streaming_feedback_profile_time_idx
  on public.streaming_discovery_feedback (account_id, profile_id, occurred_at desc);
create index if not exists streaming_feedback_media_action_idx
  on public.streaming_discovery_feedback (profile_id, media_id, action);

create table if not exists public.streaming_profile_preferences (
  account_id text not null,
  profile_id text not null,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id)
);

alter table public.streaming_playback_qoe_events enable row level security;
alter table public.streaming_discovery_feedback enable row level security;
alter table public.streaming_profile_preferences enable row level security;

revoke all on public.streaming_playback_qoe_events from anon, authenticated;
revoke all on public.streaming_discovery_feedback from anon, authenticated;
revoke all on public.streaming_profile_preferences from anon, authenticated;
grant all on public.streaming_playback_qoe_events to service_role;
grant all on public.streaming_discovery_feedback to service_role;
grant all on public.streaming_profile_preferences to service_role;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: streaming_experience_telemetry.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: production_readiness_and_privacy.sql
------------------------------------------------------------------------------
-- Production readiness foundation: privacy preferences, sanitized action audit,
-- idempotent offline-sync receipts, health snapshots, and backup run history.
--
-- SAFETY: application account/profile identifiers are opaque text IDs; they are
-- not assumed to equal auth.uid(). These records are backend-managed only.
-- Validate each request against the authenticated account/profile in the Dart
-- backend before using the service-role credential. Never ship service-role
-- credentials to Flutter. No client policies are intentionally created here.

create table if not exists public.profile_privacy_preferences (
  account_id text not null,
  profile_id text not null,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id),
  constraint profile_privacy_preferences_json_object check (jsonb_typeof(preferences) = 'object')
);

create table if not exists public.hey_media_action_audit (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  action_key text not null check (action_key in (
    'search_library', 'start_playback', 'create_playlist', 'share_media',
    'send_message', 'place_order', 'purchase', 'delete_media',
    'change_security', 'change_privacy', 'unknown'
  )),
  target_id text,
  outcome text not null check (outcome in ('allowed', 'denied', 'awaiting_confirmation', 'failed')),
  confirmation_required boolean not null default false,
  occurred_at timestamptz not null default now()
  -- Never store full AI prompts, message bodies, auth tokens or payment details.
);
create index if not exists hey_media_action_audit_account_time_idx
  on public.hey_media_action_audit (account_id, occurred_at desc);

create table if not exists public.offline_sync_receipts (
  account_id text not null,
  profile_id text not null,
  action_id text not null,
  action_type text not null check (action_type in ('playback_progress')),
  resource_id text not null,
  result text not null check (result in ('accepted', 'rejected', 'duplicate')),
  received_at timestamptz not null default now(),
  primary key (account_id, action_id)
);

create table if not exists public.production_service_health_snapshots (
  id uuid primary key default gen_random_uuid(),
  service_key text not null,
  status text not null check (status in ('healthy', 'degraded', 'unavailable', 'unknown')),
  details jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default now()
);
create index if not exists production_service_health_time_idx
  on public.production_service_health_snapshots (observed_at desc, service_key);

create table if not exists public.production_backup_runs (
  id uuid primary key default gen_random_uuid(),
  backup_id text not null unique,
  outcome text not null check (outcome in ('started', 'succeeded', 'failed', 'restore_tested')),
  encrypted boolean not null default false,
  checksum_sha256 text,
  details jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists production_backup_runs_time_idx
  on public.production_backup_runs (started_at desc);

alter table public.profile_privacy_preferences enable row level security;
alter table public.hey_media_action_audit enable row level security;
alter table public.offline_sync_receipts enable row level security;
alter table public.production_service_health_snapshots enable row level security;
alter table public.production_backup_runs enable row level security;

revoke all on public.profile_privacy_preferences from anon, authenticated;
revoke all on public.hey_media_action_audit from anon, authenticated;
revoke all on public.offline_sync_receipts from anon, authenticated;
revoke all on public.production_service_health_snapshots from anon, authenticated;
revoke all on public.production_backup_runs from anon, authenticated;

grant all on public.profile_privacy_preferences to service_role;
grant all on public.hey_media_action_audit to service_role;
grant all on public.offline_sync_receipts to service_role;
grant all on public.production_service_health_snapshots to service_role;
grant all on public.production_backup_runs to service_role;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: production_readiness_and_privacy.sql
------------------------------------------------------------------------------
