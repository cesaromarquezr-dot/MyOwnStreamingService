-- Social V2: messaging, stories, post reactions/comments, and private media notes.
-- Media binaries remain on the account home server. These tables store only
-- social metadata and references.

create table if not exists public.social_conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'direct'
    check (kind in ('direct','group')),
  title text not null default '',
  created_by_account_id uuid references public.accounts(id) on delete set null,
  created_by_profile_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.social_conversation_members (
  conversation_id uuid not null references public.social_conversations(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  role text not null default 'member'
    check (role in ('owner','moderator','member')),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, account_id, profile_id)
);

create index if not exists social_conversation_members_account_idx
  on public.social_conversation_members(account_id, profile_id);

create table if not exists public.social_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.social_conversations(id) on delete cascade,
  sender_account_id uuid not null references public.accounts(id) on delete cascade,
  sender_profile_id text not null,
  body text not null check (char_length(body) between 1 and 4000),
  media_reference jsonb,
  reply_to_message_id uuid references public.social_messages(id) on delete set null,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create index if not exists social_messages_conversation_time_idx
  on public.social_messages(conversation_id, created_at desc);

create table if not exists public.social_message_reactions (
  message_id uuid not null references public.social_messages(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  reaction text not null check (char_length(reaction) between 1 and 32),
  created_at timestamptz not null default now(),
  primary key (message_id, account_id, profile_id)
);

create table if not exists public.social_stories (
  id uuid primary key default gen_random_uuid(),
  author_account_id uuid not null references public.accounts(id) on delete cascade,
  author_profile_id text not null,
  body text not null check (char_length(body) between 1 and 1000),
  media_reference jsonb,
  visibility text not null default 'friends'
    check (visibility in ('friends','community')),
  community_id uuid references public.social_communities(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists social_stories_expiry_idx
  on public.social_stories(expires_at, created_at desc);

create table if not exists public.social_post_reactions (
  post_id uuid not null references public.social_posts(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  reaction text not null check (char_length(reaction) between 1 and 32),
  created_at timestamptz not null default now(),
  primary key (post_id, account_id, profile_id)
);

create table if not exists public.social_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  author_account_id uuid not null references public.accounts(id) on delete cascade,
  author_profile_id text not null,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists social_post_comments_post_time_idx
  on public.social_post_comments(post_id, created_at);

-- A post can be published to multiple communities. The legacy
-- social_posts.community_id column remains for compatibility.
create table if not exists public.social_post_communities (
  post_id uuid not null references public.social_posts(id) on delete cascade,
  community_id uuid not null references public.social_communities(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, community_id)
);

create index if not exists social_post_communities_community_idx
  on public.social_post_communities(community_id, created_at desc);

-- Private profile notes anchored to a canonical media version.
create table if not exists public.social_media_notes (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  media_id text not null,
  media_version_id text not null,
  position_milliseconds bigint not null default 0 check (position_milliseconds >= 0),
  text text not null check (char_length(text) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists social_media_notes_profile_media_idx
  on public.social_media_notes(account_id, profile_id, media_id, media_version_id, position_milliseconds);

alter table public.social_conversations enable row level security;
alter table public.social_conversation_members enable row level security;
alter table public.social_messages enable row level security;
alter table public.social_message_reactions enable row level security;
alter table public.social_stories enable row level security;
alter table public.social_post_reactions enable row level security;
alter table public.social_post_comments enable row level security;
alter table public.social_post_communities enable row level security;
alter table public.social_media_notes enable row level security;

-- Application access is through authenticated backend routes using the
-- server-side Supabase role. Backend routes enforce profile ownership,
-- friendship, conversation membership, and community membership.
