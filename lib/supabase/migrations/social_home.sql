-- Profile-scoped social graph, friend feed, and community discovery.
-- Social records contain references and user-authored text only; media files
-- remain on home servers and are resolved through existing media identity.

alter table public.accounts
  add column if not exists social_discoverable boolean not null default true;

create table if not exists public.social_friendships (
  id uuid primary key default gen_random_uuid(),
  requester_account_id uuid not null references public.accounts(id) on delete cascade,
  requester_profile_id text not null,
  recipient_account_id uuid not null references public.accounts(id) on delete cascade,
  recipient_profile_id text not null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_account_id <> recipient_account_id or requester_profile_id <> recipient_profile_id)
);

create unique index if not exists social_friendships_pair_uq
  on public.social_friendships (
    least(requester_account_id::text || ':' || requester_profile_id,
          recipient_account_id::text || ':' || recipient_profile_id),
    greatest(requester_account_id::text || ':' || requester_profile_id,
             recipient_account_id::text || ':' || recipient_profile_id)
  ) where status in ('pending', 'accepted');
create index if not exists social_friendships_requester_idx
  on public.social_friendships(requester_account_id, requester_profile_id, status);
create index if not exists social_friendships_recipient_idx
  on public.social_friendships(recipient_account_id, recipient_profile_id, status);

create table if not exists public.social_communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text not null default '',
  visibility text not null default 'public' check (visibility in ('public', 'private')),
  created_by_account_id uuid references public.accounts(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.social_community_memberships (
  community_id uuid not null references public.social_communities(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  role text not null default 'member' check (role in ('owner', 'moderator', 'member')),
  joined_at timestamptz not null default now(),
  primary key (community_id, account_id, profile_id)
);

create table if not exists public.social_posts (
  id uuid primary key default gen_random_uuid(),
  author_account_id uuid not null references public.accounts(id) on delete cascade,
  author_profile_id text not null,
  author_profile_name text not null,
  body text not null check (char_length(body) between 1 and 4000),
  visibility text not null default 'friends' check (visibility in ('friends', 'community')),
  community_id uuid references public.social_communities(id) on delete cascade,
  media_reference jsonb,
  created_at timestamptz not null default now(),
  check ((visibility = 'community' and community_id is not null) or
         (visibility = 'friends' and community_id is null))
);

create index if not exists social_posts_author_time_idx
  on public.social_posts(author_account_id, author_profile_id, created_at desc);
create index if not exists social_posts_community_time_idx
  on public.social_posts(community_id, created_at desc)
  where community_id is not null;
create index if not exists social_community_memberships_profile_idx
  on public.social_community_memberships(account_id, profile_id);

alter table public.social_friendships enable row level security;
alter table public.social_communities enable row level security;
alter table public.social_community_memberships enable row level security;
alter table public.social_posts enable row level security;

-- The application accesses these tables only through authenticated backend
-- routes using the service role, which enforce profile, friendship, and
-- community membership checks before returning or mutating data.
