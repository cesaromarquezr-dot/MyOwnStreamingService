-- Keep a television production's seasons scoped to that production. A
-- continuation can therefore start at season 1 while linking to the original.
create table if not exists public.media_series_seasons (
  id text primary key,
  series_media_id text not null references public.media_works(id) on delete cascade,
  season_number integer not null check (season_number >= 0),
  title text,
  start_year integer,
  end_year integer,
  episode_count integer check (episode_count is null or episode_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (series_media_id, season_number)
);

create index if not exists media_series_seasons_order_idx
  on public.media_series_seasons(series_media_id, season_number);

-- Continuities are branches within a franchise, not alternate season ranges.
create table if not exists public.media_continuities (
  id text primary key,
  franchise_id text not null references public.media_franchises(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  unique (franchise_id, name)
);

create table if not exists public.media_continuity_members (
  continuity_id text not null references public.media_continuities(id) on delete cascade,
  media_id text not null references public.media_works(id) on delete cascade,
  member_role text not null default 'production',
  release_order integer,
  story_order integer,
  primary key (continuity_id, media_id)
);

create index if not exists media_continuity_members_order_idx
  on public.media_continuity_members(continuity_id, release_order, story_order);

alter table public.media_series_seasons enable row level security;
alter table public.media_continuities enable row level security;
alter table public.media_continuity_members enable row level security;

comment on table public.media_series_seasons is
  'Season numbering belongs to an individual series production; continuation productions restart their own numbering.';
comment on table public.media_continuities is
  'Named story continuity branches within a franchise, separate from series production identity.';
comment on table public.media_continuity_members is
  'Productions or works included in a continuity branch; franchise membership alone does not imply shared continuity.';
