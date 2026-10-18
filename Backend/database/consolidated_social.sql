-- CONSOLIDATED SQL BUNDLE: consolidated_social.sql
-- Combines the following original Backend/database scripts in the listed order.
-- Review dependencies and apply to staging before production. This file is not an automatic migration runner.


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_v2_migration.sql
------------------------------------------------------------------------------
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
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_v2_migration.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_identity_migration.sql
------------------------------------------------------------------------------
-- Social identity / username hardening.
-- Usernames identify people for discovery and friend requests.
-- The existing account username remains the public account/person handle while
-- case-insensitive uniqueness is enforced by the database.

alter table if exists public.accounts
  add column if not exists social_discoverable boolean not null default true;

create unique index if not exists idx_accounts_username_lower
  on public.accounts(lower(trim(username)));

create index if not exists idx_accounts_social_discovery
  on public.accounts(social_discoverable)
  where social_discoverable = true;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_identity_migration.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_profiles_follows_catalog_innovation.sql
------------------------------------------------------------------------------
-- MyOwnStreamingService innovation layer: social profiles/follows, richer
-- community discovery, canonical catalog identities, event feeds, and media
-- versions. All mutation access is through authenticated backend routes.

-- 1) Per-profile visibility rules. Missing settings intentionally resolve to
-- "friends" in the backend; these rows store explicit user overrides.
create table if not exists public.social_profile_privacy (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  profile_visibility text not null default 'friends'
    check (profile_visibility in ('public','friends','private')),
  posts_visibility text not null default 'friends'
    check (posts_visibility in ('public','friends','private')),
  friends_visibility text not null default 'friends'
    check (friends_visibility in ('public','friends','private')),
  following_visibility text not null default 'friends'
    check (following_visibility in ('public','friends','private')),
  communities_visibility text not null default 'friends'
    check (communities_visibility in ('public','friends','private')),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id)
);

-- Following is distinct from friendship. target_key points to a public
-- shop_entities.entity_key when target_type='store'; the denormalized label is
-- retained only to keep old follows readable if a public listing is removed.
create table if not exists public.social_follows (
  follower_account_id uuid not null references public.accounts(id) on delete cascade,
  follower_profile_id text not null,
  target_type text not null check (target_type in ('store','creator','account')),
  target_key text not null check (length(trim(target_key)) > 0),
  target_name text not null check (length(trim(target_name)) > 0),
  target_avatar_url text,
  target_subtitle text,
  created_at timestamptz not null default now(),
  primary key (follower_account_id, follower_profile_id, target_type, target_key)
);
create index if not exists social_follows_profile_time_idx
  on public.social_follows (follower_account_id, follower_profile_id, created_at desc);
create index if not exists social_follows_target_idx
  on public.social_follows (target_type, target_key);

-- Community cards can show exact live member and post counts without forcing
-- the client to infer them from the currently loaded feed window.
create index if not exists social_community_memberships_count_idx
  on public.social_community_memberships (community_id);
create index if not exists social_posts_community_count_idx
  on public.social_posts (community_id, created_at desc)
  where community_id is not null;

-- Keep friends-only as the default, but allow profile owners to make a post
-- public. This enables genuinely public creator/community pages while keeping
-- existing posts unchanged and friends-only.
alter table public.social_posts
  drop constraint if exists social_posts_visibility_check;
alter table public.social_posts
  add constraint social_posts_visibility_check
  check (visibility in ('public','friends','community'));
create index if not exists social_posts_public_time_idx
  on public.social_posts (created_at desc) where visibility = 'public';

-- 2) Provider IDs and editions attach to one precise catalog work. A title is
-- never a primary key; e.g. a film named "Scream" and a TV series named
-- "Scream" stay separate catalog rows with separate provider identities.
create table if not exists public.external_media_identifiers (
  id bigint generated by default as identity primary key,
  catalog_id text not null references public.external_media_catalog(id) on delete cascade,
  source text not null,
  identifier_type text not null default 'provider_id',
  identifier text not null,
  created_at timestamptz not null default now(),
  unique (source, identifier_type, identifier)
);
create index if not exists external_media_identifiers_catalog_idx
  on public.external_media_identifiers (catalog_id);

create table if not exists public.external_media_editions (
  id text primary key,
  catalog_id text not null references public.external_media_catalog(id) on delete cascade,
  edition_name text not null,
  edition_type text not null default 'standard'
    check (edition_type in ('standard','director_cut','extended','restored','remastered','commentary','special_edition','other')),
  release_year integer,
  runtime_seconds integer check (runtime_seconds is null or runtime_seconds > 0),
  languages text[] not null default '{}',
  subtitle_languages text[] not null default '{}',
  audio_tracks jsonb not null default '[]'::jsonb,
  chapters jsonb not null default '[]'::jsonb,
  extras jsonb not null default '[]'::jsonb,
  external_ids jsonb not null default '{}'::jsonb,
  metadata_source text,
  metadata_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (catalog_id, edition_name, edition_type, release_year)
);
create index if not exists external_media_editions_catalog_idx
  on public.external_media_editions (catalog_id, release_year, edition_name);

-- Licensed multi-camera alternatives are catalog metadata; a UI cannot invent
-- camera feeds. Playback is offered only when an authorized feed URL exists.
create table if not exists public.external_media_alternate_feeds (
  id text primary key,
  catalog_id text not null references public.external_media_catalog(id) on delete cascade,
  edition_id text references public.external_media_editions(id) on delete cascade,
  feed_name text not null,
  feed_type text not null default 'camera'
    check (feed_type in ('camera','wide','close_up','commentary','audio_mix','alternate')),
  playback_reference jsonb not null default '{}'::jsonb,
  audio_mix_id text,
  language text,
  is_authorized boolean not null default false,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists external_media_alternate_feeds_catalog_idx
  on public.external_media_alternate_feeds (catalog_id, is_authorized);

-- 3) Watch-party extensions. Existing group-watch session and participant
-- tables remain the source of synchronized playback; these columns store
-- collaborative options and client presence without storing media binaries.
alter table if exists public.group_watch_sessions
  add column if not exists session_options jsonb not null default
    '{"voiceChat":false,"cameraChat":false,"reactions":true,"polls":true,"spoilerSafeRecap":true}'::jsonb,
  add column if not exists last_heartbeat_at timestamptz,
  add column if not exists current_scene_id text;

alter table if exists public.group_watch_participants
  add column if not exists permissions jsonb not null default
    '{"controlPlayback":false,"sendMessages":true,"shareCamera":false,"shareMicrophone":false}'::jsonb,
  add column if not exists connection_status text not null default 'connected'
    check (connection_status in ('connected','reconnecting','disconnected')),
  add column if not exists last_heartbeat_at timestamptz;

create table if not exists public.group_watch_reactions (
  id bigint generated by default as identity primary key,
  session_id uuid not null references public.group_watch_sessions(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  reaction_type text not null check (reaction_type in ('emoji','gif','poll_vote','message')),
  payload jsonb not null default '{}'::jsonb,
  position_seconds double precision,
  created_at timestamptz not null default now()
);
create index if not exists group_watch_reactions_session_time_idx
  on public.group_watch_reactions (session_id, created_at desc);

-- Enable RLS even though app writes are mediated by the trusted API/service
-- role. No client write policies are introduced by this migration.
alter table public.social_profile_privacy enable row level security;
alter table public.social_follows enable row level security;
alter table public.external_media_identifiers enable row level security;
alter table public.external_media_editions enable row level security;
alter table public.external_media_alternate_feeds enable row level security;
alter table public.group_watch_reactions enable row level security;

comment on table public.social_follows is
  'Profile-scoped following graph; independent from accepted friendships.';
comment on table public.external_media_identifiers is
  'Provider identifiers mapped to one canonical work; title matching alone must never merge works.';
comment on table public.external_media_editions is
  'Distinct authorized releases/editions of a canonical work, including languages, chapters, and extras.';
comment on table public.external_media_alternate_feeds is
  'Explicit authorized alternate playback feeds; never synthesize absent camera feeds.';
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_profiles_follows_catalog_innovation.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_media_attachments.sql
------------------------------------------------------------------------------
-- Social attachments are private objects; authorization is performed by
-- authenticated backend routes before signed URLs are issued.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'social-media',
  'social-media',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_media_attachments.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_story_features.sql
------------------------------------------------------------------------------

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
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_story_features.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_chat_features.sql
------------------------------------------------------------------------------
-- Rich direct/group chat support. Attachments remain in private Supabase
-- Storage and are only exposed through short-lived signed URLs.

alter table public.social_conversations
  add column if not exists send_policy text not null default 'all_members'
    check (send_policy in ('all_members', 'admins_only'));

alter table public.social_messages
  add column if not exists message_type text not null default 'text',
  add column if not exists view_once boolean not null default false;

update storage.buckets
set public = false,
    file_size_limit = 52428800,
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp',
      'video/mp4', 'video/webm', 'video/quicktime',
      'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/ogg', 'audio/webm'
    ]
where id = 'social-media';

create table if not exists public.social_message_views (
  message_id uuid not null references public.social_messages(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  viewed_at timestamptz not null default now(),
  primary key (message_id, account_id, profile_id)
);

create table if not exists public.social_chat_polls (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null unique references public.social_messages(id) on delete cascade,
  question text not null check (char_length(question) between 1 and 500),
  options jsonb not null check (jsonb_typeof(options) = 'array'),
  created_at timestamptz not null default now(),
  closes_at timestamptz
);

create table if not exists public.social_chat_poll_votes (
  poll_id uuid not null references public.social_chat_polls(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  option_index integer not null check (option_index >= 0),
  created_at timestamptz not null default now(),
  primary key (poll_id, account_id, profile_id)
);

alter table public.social_message_views enable row level security;
alter table public.social_chat_polls enable row level security;
alter table public.social_chat_poll_votes enable row level security;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_chat_features.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_chat_presence.sql
------------------------------------------------------------------------------
-- Per-member delivery watermarks and short-lived typing presence for chats.

alter table public.social_conversation_members
  add column if not exists last_delivered_at timestamptz,
  add column if not exists chat_background_color text,
  add column if not exists chat_background_image_path text;

alter table public.social_messages
  add column if not exists text_format jsonb not null default '{}'::jsonb;

create table if not exists public.social_profile_presence (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  availability text not null default 'active'
    check (availability in ('active', 'away', 'busy')),
  activity_type text,
  activity_text text,
  nickname text,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id),
  check (activity_type is null or activity_type in ('watching', 'listening', 'shopping', 'ordering_food', 'planning_marathon'))
);

create index if not exists social_profile_presence_last_seen_idx
  on public.social_profile_presence(last_seen_at);

create table if not exists public.social_conversation_typing (
  conversation_id uuid not null,
  account_id uuid not null,
  profile_id text not null,
  typing_until timestamptz not null,
  primary key (conversation_id, account_id, profile_id),
  foreign key (conversation_id, account_id, profile_id)
    references public.social_conversation_members
      (conversation_id, account_id, profile_id)
    on delete cascade
);

create index if not exists social_conversation_typing_expiry_idx
  on public.social_conversation_typing(conversation_id, typing_until);

alter table public.social_conversation_typing enable row level security;
alter table public.social_profile_presence enable row level security;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_chat_presence.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_presence_activity_types.sql
------------------------------------------------------------------------------
-- Expand account-profile presence labels beyond media playback.
-- Replace the existing activity_type check without disturbing availability checks.
DO $$
DECLARE
  existing_constraint text;
BEGIN
  FOR existing_constraint IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.social_profile_presence'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%activity_type%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.social_profile_presence DROP CONSTRAINT %I',
      existing_constraint
    );
  END LOOP;

  ALTER TABLE public.social_profile_presence
    ADD CONSTRAINT social_profile_presence_activity_type_allowed_check
    CHECK (
      activity_type IS NULL OR activity_type IN (
        'watching', 'listening', 'shopping', 'ordering_food', 'planning_marathon'
      )
    );
END $$;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_presence_activity_types.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_message_enhancements.sql
------------------------------------------------------------------------------
-- Message editing timestamps already exist in the base social schema; this
-- forward-compatible migration adds persistent pin state for conversation UI.
alter table if exists public.social_messages
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists is_pinned boolean not null default false;

create index if not exists social_messages_pinned_idx
  on public.social_messages(conversation_id, is_pinned, created_at desc)
  where is_pinned = true and deleted_at is null;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_message_enhancements.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_post_comment_media_reference.sql
------------------------------------------------------------------------------
-- Allows social post comments to include validated photo/video/story attachments.
-- Safe to run more than once; existing comments remain unchanged.
ALTER TABLE public.social_post_comments
  ADD COLUMN IF NOT EXISTS media_reference jsonb;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_post_comment_media_reference.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_conversation_invites.sql
------------------------------------------------------------------------------
-- Secure, expiring invite links for social group conversations.
-- Apply using the Supabase SQL editor before enabling group-chat share links.

create table if not exists public.social_conversation_invites (
  token text primary key,
  conversation_id uuid not null references public.social_conversations(id) on delete cascade,
  created_by_account_id uuid references public.accounts(id) on delete set null,
  created_by_profile_id text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  max_uses integer not null default 100 check (max_uses between 1 and 10000),
  used_count integer not null default 0 check (used_count >= 0),
  last_used_at timestamptz,
  revoked_at timestamptz
);

create index if not exists social_conversation_invites_conversation_idx
  on public.social_conversation_invites(conversation_id, created_at desc);

create index if not exists social_conversation_invites_expiry_idx
  on public.social_conversation_invites(expires_at)
  where revoked_at is null;

alter table public.social_conversation_invites enable row level security;
-- Access is performed by the authenticated backend with its server-side key.
-- Do not add an anon/authenticated table policy for this invite-token table.
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_conversation_invites.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_e2ee.sql
------------------------------------------------------------------------------
-- End-to-end encrypted text chat public-key directory.
-- Only public X25519 keys are stored. Never add private keys or message plaintext here.
create table if not exists public.social_profile_e2ee_keys (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  public_key text not null check (char_length(public_key) between 40 and 128),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id)
);

alter table public.social_profile_e2ee_keys enable row level security;
-- No client RLS policies by design; trusted backend service-role access only.
revoke all on public.social_profile_e2ee_keys from anon, authenticated;
grant select, insert, update, delete on public.social_profile_e2ee_keys to service_role;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_e2ee.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_message_controls_and_e2ee.sql
------------------------------------------------------------------------------
-- Social messaging compile/feature contract repair.
-- This migration is additive and safe to run more than once.
-- All access to these records is intended to go through the authenticated backend.

alter table public.social_messages
  add column if not exists is_pinned boolean not null default false,
  add column if not exists pinned_at timestamptz,
  add column if not exists pinned_by_account_id uuid
    references public.accounts(id) on delete set null;

create index if not exists social_messages_pinned_conversation_idx
  on public.social_messages(conversation_id, pinned_at desc)
  where is_pinned = true and deleted_at is null;

create table if not exists public.social_profile_e2ee_keys (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  device_id text not null default 'default',
  device_name text not null default '',
  key_id text not null default '',
  algorithm text not null default 'unspecified',
  key_fingerprint text not null default '',
  public_key text not null check (char_length(public_key) between 1 and 8192),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id, device_id)
);

create index if not exists social_profile_e2ee_keys_profile_idx
  on public.social_profile_e2ee_keys(profile_id, updated_at desc);

alter table public.social_profile_e2ee_keys enable row level security;
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_message_controls_and_e2ee.sql
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BEGIN ORIGINAL FILE: social_household_parental_controls.sql
------------------------------------------------------------------------------
-- Household chat, guardian review, profile-specific library rules, and social
-- customization metadata. Apply after streaming_service.sql, live_persistence.sql,
-- social_home.sql, and social_v2_migration.sql.

alter table public.profiles
  add column if not exists date_of_birth date,
  add column if not exists parental_controls_enabled boolean not null default false,
  add column if not exists block_explicit_music boolean not null default true,
  add column if not exists block_explicit_lyrics boolean not null default true;

alter table public.social_communities
  add column if not exists created_by_profile_id text,
  add column if not exists category text not null default 'general';

alter table public.social_conversations
  add column if not exists system_key text;

create unique index if not exists social_conversations_account_system_key_uq
  on public.social_conversations (created_by_account_id, system_key)
  where system_key is not null;

create table if not exists public.profile_guardians (
  child_profile_id uuid not null references public.profiles(id) on delete cascade,
  guardian_profile_id uuid not null references public.profiles(id) on delete cascade,
  relationship_label text not null default 'Guardian',
  created_at timestamptz not null default now(),
  primary key (child_profile_id, guardian_profile_id),
  check (child_profile_id <> guardian_profile_id)
);
create index if not exists profile_guardians_guardian_idx
  on public.profile_guardians (guardian_profile_id, child_profile_id);

create table if not exists public.profile_media_access_rules (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  decision text not null check (decision in ('allow', 'block', 'review')),
  changed_by_profile_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, media_catalog_id)
);

create table if not exists public.profile_content_preferences (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  content_level text not null default 'kids'
    check (content_level in ('little_kids','kids','older_kids','teen','mature','unrestricted','custom')),
  block_explicit_music boolean not null default true,
  block_explicit_lyrics boolean not null default true,
  block_mature_music_videos boolean not null default true,
  restrict_communities boolean not null default true,
  restrict_direct_messages boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_community_access (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  community_id uuid not null references public.social_communities(id) on delete cascade,
  decision text not null check (decision in ('allow', 'block', 'review')),
  changed_by_profile_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, community_id)
);

-- One system group chat per account; active profiles are automatically members.
create or replace function public.ensure_household_profile_conversation(p_account_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  active_profiles integer;
  conversation_uuid uuid;
  owner_profile_id text;
begin
  if p_account_id is null then return; end if;

  select count(*)::integer into active_profiles
    from public.profiles p
   where p.account_id = p_account_id
     and p.is_active = true
     and p.external_profile_id is not null;
  if active_profiles < 2 then return; end if;

  select p.external_profile_id into owner_profile_id
    from public.profiles p
   where p.account_id = p_account_id
     and p.is_active = true
     and p.external_profile_id is not null
   order by p.is_owner desc, p.created_at asc
   limit 1;

  insert into public.social_conversations (
    kind, title, created_by_account_id, created_by_profile_id, system_key
  ) values (
    'group', 'Home Server Profiles', p_account_id, owner_profile_id, 'household'
  )
  on conflict (created_by_account_id, system_key) where system_key is not null
  do nothing;

  select sc.id into conversation_uuid
    from public.social_conversations sc
   where sc.created_by_account_id = p_account_id
     and sc.system_key = 'household'
   limit 1;
  if conversation_uuid is null then return; end if;

  insert into public.social_conversation_members (conversation_id, account_id, profile_id, role)
  select conversation_uuid, p.account_id, p.external_profile_id,
         case when p.is_owner then 'owner' else 'member' end
    from public.profiles p
   where p.account_id = p_account_id
     and p.is_active = true
     and p.external_profile_id is not null
  on conflict (conversation_id, account_id, profile_id)
  do update set role = excluded.role;

  delete from public.social_conversation_members scm
   where scm.conversation_id = conversation_uuid
     and scm.account_id = p_account_id
     and not exists (
       select 1 from public.profiles p
        where p.account_id = p_account_id
          and p.is_active = true
          and p.external_profile_id = scm.profile_id
     );
end;
$function$;

create or replace function public.sync_household_profile_conversation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if tg_op = 'UPDATE' and old.account_id is distinct from new.account_id then
    perform public.ensure_household_profile_conversation(old.account_id);
  end if;
  perform public.ensure_household_profile_conversation(new.account_id);
  return new;
end;
$function$;

drop trigger if exists profiles_household_conversation_sync on public.profiles;
create trigger profiles_household_conversation_sync
  after insert or update of account_id, external_profile_id, is_active, is_owner
  on public.profiles
  for each row execute function public.sync_household_profile_conversation();

do $seed$
declare account_row record;
begin
  for account_row in
    select p.account_id from public.profiles p
     where p.is_active = true and p.external_profile_id is not null
     group by p.account_id having count(*) >= 2
  loop
    perform public.ensure_household_profile_conversation(account_row.account_id);
  end loop;
end;
$seed$;

-- Guardian review queue for inbound friend requests sent to child profiles.
alter table public.social_friendships
  add column if not exists requires_guardian_review boolean not null default false;

create table if not exists public.social_friendship_guardian_reviews (
  friendship_id uuid not null references public.social_friendships(id) on delete cascade,
  child_profile_id uuid not null references public.profiles(id) on delete cascade,
  guardian_profile_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'blocked')),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (friendship_id, guardian_profile_id)
);
create index if not exists social_friendship_guardian_reviews_queue_idx
  on public.social_friendship_guardian_reviews (guardian_profile_id, status, created_at desc);

create or replace function public.set_friend_request_guardian_review()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare child_profile public.profiles%rowtype;
begin
  select p.* into child_profile
    from public.profiles p
   where p.account_id = new.recipient_account_id
     and p.external_profile_id = new.recipient_profile_id
     and p.is_active = true
   limit 1;
  new.requires_guardian_review := false;
  if child_profile.id is not null
     and child_profile.date_of_birth is not null
     and child_profile.date_of_birth > (current_date - interval '18 years')::date
     and exists (select 1 from public.profile_guardians pg where pg.child_profile_id = child_profile.id) then
    new.requires_guardian_review := true;
  end if;
  return new;
end;
$function$;

drop trigger if exists social_friendships_guardian_review_flag on public.social_friendships;
create trigger social_friendships_guardian_review_flag
  before insert or update of recipient_account_id, recipient_profile_id
  on public.social_friendships
  for each row execute function public.set_friend_request_guardian_review();

create or replace function public.create_guardian_friendship_reviews()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare child_uuid uuid;
begin
  if new.requires_guardian_review is not true then return new; end if;
  select p.id into child_uuid from public.profiles p
   where p.account_id = new.recipient_account_id
     and p.external_profile_id = new.recipient_profile_id
     and p.is_active = true limit 1;
  if child_uuid is null then return new; end if;
  insert into public.social_friendship_guardian_reviews (
    friendship_id, child_profile_id, guardian_profile_id, status
  )
  select new.id, child_uuid, pg.guardian_profile_id, 'pending'
    from public.profile_guardians pg where pg.child_profile_id = child_uuid
  on conflict (friendship_id, guardian_profile_id) do nothing;
  return new;
end;
$function$;

drop trigger if exists social_friendships_guardian_review_create on public.social_friendships;
create trigger social_friendships_guardian_review_create
  after insert or update of requires_guardian_review
  on public.social_friendships
  for each row execute function public.create_guardian_friendship_reviews();

create or replace function public.apply_guardian_friendship_review()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare blocked_exists boolean; pending_exists boolean;
begin
  if new.status = old.status then return new; end if;
  if new.status in ('approved', 'blocked') then
    update public.social_friendship_guardian_reviews
       set reviewed_at = coalesce(reviewed_at, now())
     where friendship_id = new.friendship_id
       and guardian_profile_id = new.guardian_profile_id;
  end if;
  if new.status not in ('approved', 'blocked') then return new; end if;

  select exists (select 1 from public.social_friendship_guardian_reviews r
    where r.friendship_id = new.friendship_id and r.status = 'blocked') into blocked_exists;
  if blocked_exists then
    update public.social_friendships set status = 'declined', requires_guardian_review = false, updated_at = now()
     where id = new.friendship_id and status = 'pending';
    return new;
  end if;
  select exists (select 1 from public.social_friendship_guardian_reviews r
    where r.friendship_id = new.friendship_id and r.status = 'pending') into pending_exists;
  if not pending_exists then
    update public.social_friendships set requires_guardian_review = false, updated_at = now()
     where id = new.friendship_id and status = 'pending';
  end if;
  return new;
end;
$function$;

drop trigger if exists social_friendship_guardian_review_apply on public.social_friendship_guardian_reviews;
create trigger social_friendship_guardian_review_apply
  after update of status on public.social_friendship_guardian_reviews
  for each row execute function public.apply_guardian_friendship_review();

alter table public.profile_guardians enable row level security;
alter table public.profile_media_access_rules enable row level security;
alter table public.profile_content_preferences enable row level security;
alter table public.profile_community_access enable row level security;
alter table public.social_friendship_guardian_reviews enable row level security;

revoke all on function public.ensure_household_profile_conversation(uuid) from public, anon, authenticated;
revoke all on function public.sync_household_profile_conversation() from public, anon, authenticated;
revoke all on function public.set_friend_request_guardian_review() from public, anon, authenticated;
revoke all on function public.create_guardian_friendship_reviews() from public, anon, authenticated;
revoke all on function public.apply_guardian_friendship_review() from public, anon, authenticated;

comment on column public.profiles.date_of_birth is
  'Private birth date for guardian-managed age calculations. Never expose publicly.';
comment on column public.social_friendships.requires_guardian_review is
  'When true, hide the inbound request from the child until all guardians approve.';
------------------------------------------------------------------------------
-- END ORIGINAL FILE: social_household_parental_controls.sql
------------------------------------------------------------------------------
