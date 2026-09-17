-- FILE: `lib/supabase/migrations/media_universe_foundation.sql`.
-- Purpose: Durable schema foundation for the unified media graph.
-- Security: account/profile ownership is intentionally separated from global catalog data.

create table if not exists media_works (
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

create table if not exists media_relationships (
  id uuid primary key default gen_random_uuid(),
  from_media_id text not null references media_works(id) on delete cascade,
  relationship_type text not null,
  to_media_id text not null references media_works(id) on delete cascade,
  confidence numeric not null default 1,
  source text not null default 'catalog',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(from_media_id, relationship_type, to_media_id)
);

create table if not exists media_artwork (
  id uuid primary key default gen_random_uuid(),
  media_id text references media_works(id) on delete cascade,
  source_type text not null,
  source_path text,
  url text,
  artwork_type text not null,
  title text,
  profile_eligible boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists profile_devices (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  name text not null,
  device_type text not null,
  last_seen_at timestamptz not null default now(),
  online boolean not null default true
);

create table if not exists playback_sessions (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  device_id uuid references profile_devices(id) on delete set null,
  media_id text references media_works(id) on delete set null,
  state text not null default 'idle',
  position_seconds numeric not null default 0,
  started_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now()
);

create index if not exists idx_media_relationship_from on media_relationships(from_media_id);
create index if not exists idx_media_relationship_to on media_relationships(to_media_id);
create index if not exists idx_media_artwork_media on media_artwork(media_id);
create index if not exists idx_profile_devices_profile on profile_devices(profile_id);
create index if not exists idx_playback_sessions_profile on playback_sessions(profile_id);
create index if not exists idx_playback_sessions_media on playback_sessions(media_id);
