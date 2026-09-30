-- Canonical franchise/saga graph + TV intro metadata.
-- Global catalog metadata only; media bytes remain on home servers.

create table if not exists public.media_franchises (
  id text primary key,
  name text not null,
  franchise_type text not null default 'franchise',
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.media_franchise_members (
  franchise_id text not null references public.media_franchises(id) on delete cascade,
  media_id text not null references public.media_works(id) on delete cascade,
  membership_type text not null default 'member',
  release_order integer,
  story_order integer,
  branch_key text,
  primary key (franchise_id, media_id)
);

create table if not exists public.media_graph_edges (
  id uuid primary key default gen_random_uuid(),
  from_media_id text not null references public.media_works(id) on delete cascade,
  to_media_id text not null references public.media_works(id) on delete cascade,
  relationship_type text not null,
  continuity_effect text not null default 'none',
  confidence numeric not null default 1 check (confidence >= 0 and confidence <= 1),
  source text not null default 'catalog',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(from_media_id, to_media_id, relationship_type)
);

create table if not exists public.tv_intros (
  id uuid primary key default gen_random_uuid(),
  series_media_id text not null references public.media_works(id) on delete cascade,
  media_version_id text,
  start_ms bigint not null check (start_ms >= 0),
  end_ms bigint not null check (end_ms > start_ms),
  season_label text,
  episode_label text,
  detection_method text not null default 'home_server_index',
  confidence numeric not null default 1 check (confidence >= 0 and confidence <= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists media_franchise_members_franchise_idx
  on public.media_franchise_members(franchise_id, release_order, story_order);

create index if not exists media_graph_edges_from_idx
  on public.media_graph_edges(from_media_id, relationship_type);

create index if not exists media_graph_edges_to_idx
  on public.media_graph_edges(to_media_id, relationship_type);

create index if not exists tv_intros_series_idx
  on public.tv_intros(series_media_id, season_label, episode_label);
