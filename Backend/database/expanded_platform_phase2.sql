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
