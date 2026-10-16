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
