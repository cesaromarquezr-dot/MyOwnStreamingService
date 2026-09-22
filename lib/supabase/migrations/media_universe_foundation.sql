-- FILE: `lib/supabase/migrations/media_universe_foundation.sql`
--
-- Purpose:
-- Durable schema foundation for the unified media graph.
--
-- Security:
-- Global catalog/relationship data is intentionally separated from
-- account/profile-owned application state.
--
-- Physical media files remain on each account's home server and are never
-- stored in these tables.

-- ===========================================================================
-- Global media works
-- ===========================================================================
--
-- A media_work represents a canonical work in the unified media universe.
-- It is independent of any particular account, profile, or home server.

create table if not exists public.media_works (
  id text primary key,

  title text not null,

  media_type text not null,

  release_year integer,

  original_language text,

  genres jsonb not null default '[]'::jsonb,
  themes jsonb not null default '[]'::jsonb,
  tags jsonb not null default '[]'::jsonb,

  production_countries jsonb not null default '[]'::jsonb,
  setting_countries jsonb not null default '[]'::jsonb,
  cultural_association_countries jsonb not null default '[]'::jsonb,
  creator_origin_countries jsonb not null default '[]'::jsonb,
  source_origin_countries jsonb not null default '[]'::jsonb,

  has_lyrics boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- ===========================================================================
-- Media relationships
-- ===========================================================================
--
-- Represents relationships between canonical media works.
--
-- Examples:
--   sequel
--   prequel
--   remake
--   adaptation
--   spin_off
--   soundtrack
--   episode_of
--   part_of
--   related
--
-- The relationship type remains application-defined so the graph can evolve
-- without requiring a schema migration for every new relationship category.

create table if not exists public.media_relationships (
  id uuid primary key default gen_random_uuid(),

  from_media_id text not null
    references public.media_works(id)
    on delete cascade,

  relationship_type text not null,

  to_media_id text not null
    references public.media_works(id)
    on delete cascade,

  confidence numeric not null default 1,

  source text not null default 'catalog',

  metadata jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),

  unique(from_media_id, relationship_type, to_media_id)
);


-- ===========================================================================
-- Media artwork
-- ===========================================================================
--
-- Artwork belongs to the global media graph rather than an account's
-- physical media storage.
--
-- source_path may identify a backend/catalog source location.
-- It must not expose a private home-server filesystem path to normal clients.

create table if not exists public.media_artwork (
  id uuid primary key default gen_random_uuid(),

  media_id text
    references public.media_works(id)
    on delete cascade,

  source_type text not null,

  source_path text,

  url text,

  artwork_type text not null,

  title text,

  profile_eligible boolean not null default false,

  created_at timestamptz not null default now()
);


-- ===========================================================================
-- Profile devices
-- ===========================================================================
--
-- Device records are application metadata.
--
-- Physical media remains on the home server.
--
-- account_id/profile_id are application-level external identifiers so this
-- foundation can coexist with the existing UUID-based account/profile tables
-- and backend synchronization layer.

create table if not exists public.profile_devices (
  id uuid primary key default gen_random_uuid(),

  account_id text not null,

  profile_id text not null,

  name text not null,

  device_type text not null,

  last_seen_at timestamptz not null default now(),

  online boolean not null default true
);


-- ===========================================================================
-- Playback sessions
-- ===========================================================================
--
-- Tracks application playback state.
--
-- This table does NOT store media files or private server filesystem paths.
-- media_id refers to the canonical media graph only.

create table if not exists public.playback_sessions (
  id uuid primary key default gen_random_uuid(),

  account_id text not null,

  profile_id text not null,

  device_id uuid
    references public.profile_devices(id)
    on delete set null,

  media_id text
    references public.media_works(id)
    on delete set null,

  state text not null default 'idle',

  position_seconds numeric not null default 0,

  started_at timestamptz not null default now(),

  last_activity_at timestamptz not null default now()
);


-- ===========================================================================
-- Indexes
-- ===========================================================================

create index if not exists idx_media_relationship_from
  on public.media_relationships(from_media_id);

create index if not exists idx_media_relationship_to
  on public.media_relationships(to_media_id);

create index if not exists idx_media_artwork_media
  on public.media_artwork(media_id);

create index if not exists idx_profile_devices_account
  on public.profile_devices(account_id);

create index if not exists idx_profile_devices_profile
  on public.profile_devices(profile_id);

create index if not exists idx_profile_devices_last_seen
  on public.profile_devices(last_seen_at);

create index if not exists idx_playback_sessions_account
  on public.playback_sessions(account_id);

create index if not exists idx_playback_sessions_profile
  on public.playback_sessions(profile_id);

create index if not exists idx_playback_sessions_media
  on public.playback_sessions(media_id);

create index if not exists idx_playback_sessions_last_activity
  on public.playback_sessions(last_activity_at);


-- ===========================================================================
-- Updated-at trigger for media works
-- ===========================================================================

create or replace function public.set_media_work_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_media_work_updated_at
  on public.media_works;

create trigger trg_media_work_updated_at
before update
on public.media_works
for each row
execute function public.set_media_work_updated_at();


-- ===========================================================================
-- Row-level security
-- ===========================================================================
--
-- Global catalog data and playback/device data should not automatically
-- become publicly writable simply because the tables exist.
--
-- Backend service-role access bypasses RLS.
--
-- Explicit client policies should be added only where the application's
-- authenticated-session model requires direct Supabase access.

alter table public.media_works
  enable row level security;

alter table public.media_relationships
  enable row level security;

alter table public.media_artwork
  enable row level security;

alter table public.profile_devices
  enable row level security;

alter table public.playback_sessions
  enable row level security;


-- ===========================================================================
-- Documentation
-- ===========================================================================

comment on table public.media_works is
  'Canonical global media works. Contains metadata only; physical media files remain on home servers.';

comment on table public.media_relationships is
  'Relationships between canonical media works in the unified media graph.';

comment on table public.media_artwork is
  'Artwork metadata associated with canonical media works. Private home-server filesystem paths must not be exposed to normal clients.';

comment on table public.profile_devices is
  'Application device metadata associated with account/profile sessions.';

comment on table public.playback_sessions is
  'Application playback state. Does not store physical media files or private home-server filesystem paths.';

comment on column public.media_artwork.source_path is
  'Catalog/backend source path only. Must never expose a private home-server filesystem path to normal clients.';

comment on column public.playback_sessions.media_id is
  'Canonical media work identifier; physical media remains on the account home server.';