-- FILE: `Backend/database/ratings_migration.sql`.
-- Purpose: Adds durable storage for external rating snapshots and profile ratings.
-- No passwords, API keys, or media files are stored here.

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
  stars numeric not null check (stars >= 0.5 and stars <= 5 and mod((stars * 10)::integer, 5) = 0),
  updated_at timestamptz not null default now(),
  unique(account_id, profile_id, media_id)
);

create index if not exists idx_media_external_ratings_media on public.media_external_ratings(media_id);
create index if not exists idx_profile_media_ratings_profile on public.profile_media_ratings(profile_id, media_id);

comment on table public.media_external_ratings is 'Cached provider rating snapshots; provider scores remain separate and are not combined.';
comment on table public.profile_media_ratings is 'Private profile ratings from 0.5 to 5 stars; separate from public reviews and external ratings.';
