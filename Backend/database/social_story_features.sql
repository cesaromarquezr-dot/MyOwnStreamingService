
-- Rich Story analytics, reactions, polls, and interaction history.
create table if not exists public.social_story_views (
  story_id uuid not null references public.social_stories(id) on delete cascade,
  viewer_account_id uuid not null references public.accounts(id) on delete cascade,
  viewer_profile_id text not null,
  view_count integer not null default 0 check (view_count >= 0),
  first_viewed_at timestamptz not null default now(),
  last_viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_account_id, viewer_profile_id)
);

create index if not exists social_story_views_story_idx
  on public.social_story_views(story_id, last_viewed_at desc);

create table if not exists public.social_story_reactions (
  story_id uuid not null references public.social_stories(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  reaction text not null check (char_length(reaction) between 1 and 32),
  created_at timestamptz not null default now(),
  primary key (story_id, account_id, profile_id)
);

create index if not exists social_story_reactions_story_idx
  on public.social_story_reactions(story_id, created_at desc);

create table if not exists public.social_story_poll_votes (
  story_id uuid not null references public.social_stories(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  option_index integer not null check (option_index >= 0 and option_index <= 20),
  created_at timestamptz not null default now(),
  primary key (story_id, account_id, profile_id)
);

create index if not exists social_story_poll_votes_story_idx
  on public.social_story_poll_votes(story_id, option_index);

alter table public.social_story_views enable row level security;
alter table public.social_story_reactions enable row level security;
alter table public.social_story_poll_votes enable row level security;
