-- Canonical architecture extensions — 2026-09-28
-- These extend existing canonical capabilities; they do not create parallel
-- movie/music/TV likes, collection, or seller systems.
--
-- Media files remain on home servers. Supabase stores application metadata.
-- ============================================================================
-- MEDIA EDITIONS / VERSIONS / RELATIONSHIP GRAPH
-- ============================================================================

create table if not exists public.media_editions (
  id uuid primary key default gen_random_uuid(),
  media_catalog_id uuid not null
    references public.media_catalog(id)
    on delete cascade,
  edition_key text not null,
  name text not null,
  edition_type text,
  cut text,
  release_year integer,
  runtime_seconds integer,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (media_catalog_id, edition_key)
);

alter table public.media_versions
  add column if not exists media_edition_id uuid
    references public.media_editions(id)
    on delete set null;

create index if not exists idx_media_editions_catalog
  on public.media_editions(media_catalog_id);

create index if not exists idx_media_versions_edition
  on public.media_versions(media_edition_id);

create table if not exists public.media_relationships (
  id uuid primary key default gen_random_uuid(),
  from_media_catalog_id uuid not null
    references public.media_catalog(id)
    on delete cascade,
  relationship_type text not null,
  to_media_catalog_id uuid not null
    references public.media_catalog(id)
    on delete cascade,
  confidence numeric(5,4) not null default 1.0
    check (confidence >= 0 and confidence <= 1),
  source text not null default 'catalog',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (from_media_catalog_id, relationship_type, to_media_catalog_id),
  check (from_media_catalog_id <> to_media_catalog_id)
);

create index if not exists idx_media_relationships_from
  on public.media_relationships(from_media_catalog_id);
create index if not exists idx_media_relationships_to
  on public.media_relationships(to_media_catalog_id);

create table if not exists public.media_timeline_events (
  id uuid primary key default gen_random_uuid(),
  media_catalog_id uuid not null
    references public.media_catalog(id)
    on delete cascade,
  media_edition_id uuid
    references public.media_editions(id)
    on delete set null,
  event_type text not null,
  event_date date,
  title text not null,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_media_timeline_events_date
  on public.media_timeline_events(event_date);
create index if not exists idx_media_timeline_events_media
  on public.media_timeline_events(media_catalog_id);

-- ============================================================================
-- UNIVERSAL MEDIA CATEGORIES / LIKED-MEDIA FILTERING
-- ============================================================================

create table if not exists public.media_categories (
  id uuid primary key default gen_random_uuid(),
  category_key text not null unique,
  display_name text not null,
  media_types public.media_type[] not null default '{}',
  sort_order integer not null default 0,
  is_system boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.media_category_assignments (
  media_catalog_id uuid not null
    references public.media_catalog(id)
    on delete cascade,
  category_id uuid not null
    references public.media_categories(id)
    on delete cascade,
  source text not null default 'catalog',
  confidence numeric(5,4) not null default 1.0
    check (confidence >= 0 and confidence <= 1),
  created_at timestamptz not null default now(),
  primary key (media_catalog_id, category_id)
);

create index if not exists idx_media_category_assignments_category
  on public.media_category_assignments(category_id);

-- Canonical examples requested for the category-filter UI. More categories
-- can be added through the same table; categories are not separate systems.
insert into public.media_categories (category_key, display_name, sort_order)
values
  ('all', 'All', 0),
  ('country', 'Country', 10),
  ('rap', 'Rap', 20),
  ('pop', 'Pop', 30),
  ('reggaeton', 'Reggaeton', 40),
  ('corridos_tumbados', 'Corridos Tumbados', 50),
  ('party_dance', 'Party / Dance', 60),
  ('nostalgic', 'Nostalgic', 70),
  ('action', 'Action', 80),
  ('comedy', 'Comedy', 90),
  ('sci_fi', 'Sci-Fi', 100),
  ('mockumentary', 'Mockumentary', 110)
on conflict (category_key) do nothing;

-- ============================================================================
-- FILTER-TO-PLAYLIST / COLLECTION SNAPSHOTS
-- ============================================================================

alter table public.collections
  add column if not exists collection_type text not null default 'manual';

alter table public.collections
  add column if not exists source_category_id uuid
    references public.media_categories(id)
    on delete set null;

alter table public.collections
  add column if not exists source_filter jsonb;

comment on column public.collections.collection_type is
  'manual, smart, or filtered_snapshot; all remain the canonical Collections capability.';

comment on column public.collections.source_filter is
  'Optional serialized filter used to explain how a filtered collection was created.';

-- ============================================================================
-- SELLER PAYOUT DESTINATIONS
-- ============================================================================

create table if not exists public.seller_payout_destinations (
  id uuid primary key default gen_random_uuid(),
  seller_account_id uuid not null
    references public.accounts(id)
    on delete cascade,
  provider_key text not null,
  method_type text not null,
  display_name text not null,
  provider_account_reference text,
  masked_identifier text,
  enabled boolean not null default true,
  verified boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_seller_payout_destinations_seller
  on public.seller_payout_destinations(seller_account_id);

create unique index if not exists uq_seller_payout_destinations_provider_ref
  on public.seller_payout_destinations(seller_account_id, provider_key, provider_account_reference)
  where provider_account_reference is not null;

comment on table public.seller_payout_destinations is
  'Seller payout destinations. Store provider references and masked values only; never raw bank/card credentials.';

comment on column public.seller_payout_destinations.provider_account_reference is
  'Opaque provider-side account identifier/token. Never store raw financial credentials.';

-- ============================================================================
-- OPTIONAL SMART FILTER RULES
-- ============================================================================

create table if not exists public.profile_media_filters (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null
    references public.profiles(id)
    on delete cascade,
  media_type public.media_type,
  category_id uuid
    references public.media_categories(id)
    on delete cascade,
  name text not null,
  auto_update boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profile_media_filters_profile
  on public.profile_media_filters(profile_id);

-- ============================================================================
-- RLS
-- ============================================================================

alter table public.media_editions enable row level security;
alter table public.media_relationships enable row level security;
alter table public.media_timeline_events enable row level security;
alter table public.media_categories enable row level security;
alter table public.media_category_assignments enable row level security;
alter table public.seller_payout_destinations enable row level security;
alter table public.profile_media_filters enable row level security;

-- Public/catalog metadata can be read by authenticated clients. Mutations
-- remain backend/admin responsibilities unless a stricter policy is added.
drop policy if exists media_editions_authenticated_read on public.media_editions;
create policy media_editions_authenticated_read on public.media_editions
  for select to authenticated using (true);

drop policy if exists media_relationships_authenticated_read on public.media_relationships;
create policy media_relationships_authenticated_read on public.media_relationships
  for select to authenticated using (true);

drop policy if exists media_timeline_events_authenticated_read on public.media_timeline_events;
create policy media_timeline_events_authenticated_read on public.media_timeline_events
  for select to authenticated using (true);

drop policy if exists media_categories_authenticated_read on public.media_categories;
create policy media_categories_authenticated_read on public.media_categories
  for select to authenticated using (true);

drop policy if exists media_category_assignments_authenticated_read on public.media_category_assignments;
create policy media_category_assignments_authenticated_read on public.media_category_assignments
  for select to authenticated using (true);

drop policy if exists seller_payout_destinations_owner on public.seller_payout_destinations;
create policy seller_payout_destinations_owner on public.seller_payout_destinations
  for all to authenticated
  using (seller_account_id in (
    select account_id from public.account_members
    where account_id = seller_payout_destinations.seller_account_id
      and status = 'active'
      and role in ('owner', 'admin')
  ))
  with check (seller_account_id in (
    select account_id from public.account_members
    where account_id = seller_payout_destinations.seller_account_id
      and status = 'active'
      and role in ('owner', 'admin')
  ));

drop policy if exists profile_media_filters_owner on public.profile_media_filters;
create policy profile_media_filters_owner on public.profile_media_filters
  for all to authenticated
  using (profile_id in (
    select p.id from public.profiles p
    join public.accounts a on a.id = p.account_id
    where a.auth_user_id = auth.uid()
  ))
  with check (profile_id in (
    select p.id from public.profiles p
    join public.accounts a on a.id = p.account_id
    where a.auth_user_id = auth.uid()
  ));
