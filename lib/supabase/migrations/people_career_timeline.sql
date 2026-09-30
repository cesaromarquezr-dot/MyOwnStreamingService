-- One canonical person may have credits across film, television, music,
-- producing, writing, directing, hosting, theater, games, and future types.
create table if not exists public.media_people (
  id text primary key,
  name text not null,
  sort_name text,
  biography text,
  birth_year integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.media_person_credits (
  id text primary key,
  person_id text not null references public.media_people(id) on delete cascade,
  media_id text not null references public.media_works(id) on delete cascade,
  category text not null,
  role text not null default '',
  character_name text,
  credit_group text,
  start_year integer,
  end_year integer,
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (person_id, media_id, category, role, character_name)
);

create index if not exists media_person_credits_timeline_idx
  on public.media_person_credits(person_id, start_year, category);
create index if not exists media_person_credits_work_idx
  on public.media_person_credits(media_id, category);

alter table public.media_people enable row level security;
alter table public.media_person_credits enable row level security;

comment on table public.media_people is
  'Canonical entertainment people; acting, music, and creative roles share one person identity.';
comment on table public.media_person_credits is
  'Typed person-to-work credits for career timelines. Re-recordings remain separate works and can link through the media graph.';
