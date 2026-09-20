-- Streaming Service persistent database
-- IMPORTANT: Supabase stores account/application metadata only.
-- Actual movie, TV, music and disc files remain on each account's home server.

create extension if not exists pgcrypto;
create extension if not exists pg_cron;

-- ============================================================
-- ENUMS
-- ============================================================
do $$ begin
  create type public.media_type as enum ('movie','tv_show','episode','music','album','disc','other');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.server_status as enum ('pending','online','offline','maintenance','disabled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.media_availability as enum ('available','missing','offline','scanning','disabled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.reaction_type as enum ('like','dislike','love','amazing','funny','scary','emotional','mind_blown');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.recommendation_vote as enum ('yes','no');
exception when duplicate_object then null; end $$;

-- ============================================================
-- COMMON UPDATED_AT
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- ACCOUNTS / PROFILES / SERVERS
-- ============================================================
create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  username text not null unique,
  display_name text,
  avatar_url text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  name text not null,
  avatar_url text,
  is_owner boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(account_id, name)
);

create table if not exists public.servers (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  name text not null,
  status public.server_status not null default 'pending',
  server_type text not null default 'home',
  public_endpoint text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(account_id)
);

create table if not exists public.server_storage (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null unique references public.servers(id) on delete cascade,
  total_bytes bigint not null default 0,
  used_bytes bigint not null default 0,
  available_bytes bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- ============================================================
-- MEDIA IDENTITY / SERVER INDEX
-- Actual media files are NEVER stored here.
-- ============================================================
create table if not exists public.media_catalog (
  id uuid primary key default gen_random_uuid(),
  canonical_key text not null unique,
  title text not null,
  media_type public.media_type not null,
  year integer,
  description text,
  poster_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.server_media (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  server_media_id text not null,
  availability public.media_availability not null default 'available',
  relative_media_key text,
  metadata_version text,
  last_seen_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(server_id, server_media_id)
);

-- relative_media_key is server-private. Never return it from client-facing APIs.
create table if not exists public.media_versions (
  id uuid primary key default gen_random_uuid(),
  server_media_id uuid not null references public.server_media(id) on delete cascade,
  version_key text not null,
  edition text,
  cut text,
  release_year integer,
  runtime_seconds integer,
  video_fingerprint text,
  audio_summary jsonb not null default '[]'::jsonb,
  subtitle_summary jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(server_media_id, version_key)
);

-- ============================================================
-- PROFILE LIBRARY / WATCH STATE
-- ============================================================
create table if not exists public.profile_library (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  server_media_id uuid not null references public.server_media(id) on delete cascade,
  added_at timestamptz not null default now(),
  unique(profile_id, server_media_id)
);

create table if not exists public.watch_progress (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  server_media_id uuid not null references public.server_media(id) on delete cascade,
  version_id uuid references public.media_versions(id) on delete set null,
  position_seconds double precision not null default 0,
  duration_seconds double precision not null default 0,
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  unique(profile_id, server_media_id)
);

create table if not exists public.watch_history (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  server_media_id uuid not null references public.server_media(id) on delete cascade,
  version_id uuid references public.media_versions(id) on delete set null,
  watched_at timestamptz not null default now(),
  completed boolean not null default false
);

create table if not exists public.profile_media_reactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  reaction public.reaction_type not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id, media_catalog_id)
);

-- ============================================================
-- WISHLIST / COLLECTIONS
-- ============================================================
create table if not exists public.wishlists (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null unique references public.accounts(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.wishlist_items (
  id uuid primary key default gen_random_uuid(),
  wishlist_id uuid not null references public.wishlists(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(wishlist_id, media_catalog_id)
);

create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.collection_items (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  position integer not null default 0,
  unique(collection_id, media_catalog_id)
);

-- ============================================================
-- RECOMMENDATIONS / VOTING
-- ============================================================
create table if not exists public.recommendations (
  id uuid primary key default gen_random_uuid(),
  created_by_profile_id uuid not null references public.profiles(id) on delete cascade,
  target_account_id uuid not null references public.accounts(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  status text not null default 'open',
  yes_votes integer not null default 0,
  no_votes integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recommendation_votes (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null references public.recommendations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  vote public.recommendation_vote not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(recommendation_id, profile_id)
);

-- ============================================================
-- REVIEWS: private ownership, public anonymous username
-- ============================================================
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  rating smallint check (rating between 1 and 5),
  review_text text not null,
  public_username text not null,
  visibility text not null default 'global',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.review_likes (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(review_id, profile_id)
);

-- ============================================================
-- GROUP WATCH / CROSS-SERVER EXACT VERSION MATCHING
-- ============================================================
create table if not exists public.group_watch_sessions (
  id uuid primary key default gen_random_uuid(),
  created_by_profile_id uuid not null references public.profiles(id) on delete cascade,
  media_catalog_id uuid not null references public.media_catalog(id) on delete cascade,
  required_version_key text not null,
  status text not null default 'waiting',
  current_position_seconds double precision not null default 0,
  is_playing boolean not null default false,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz
);

create table if not exists public.group_watch_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.group_watch_sessions(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  server_id uuid not null references public.servers(id) on delete cascade,
  server_media_id uuid not null references public.server_media(id) on delete cascade,
  version_id uuid not null references public.media_versions(id) on delete restrict,
  audio_preference text,
  subtitle_preference text,
  joined_at timestamptz not null default now(),
  unique(session_id, profile_id)
);

create table if not exists public.group_watch_events (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.group_watch_sessions(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  position_seconds double precision,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- CHAT
-- ============================================================
create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  group_watch_session_id uuid references public.group_watch_sessions(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_participants (
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(room_id, profile_id)
);

create table if not exists public.chat_messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- DEVICES / SECURITY
-- ============================================================
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  device_name text not null,
  device_type text,
  fingerprint_hash text,
  trusted boolean not null default false,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.device_sessions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  device_id uuid references public.devices(id) on delete cascade,
  session_token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.login_attempts (
  id bigint generated always as identity primary key,
  account_id uuid references public.accounts(id) on delete set null,
  identifier_hash text not null,
  ip_hash text,
  user_agent_hash text,
  success boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.security_events (
  id bigint generated always as identity primary key,
  account_id uuid references public.accounts(id) on delete set null,
  profile_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- SUBSCRIPTIONS / PAYMENTS
-- ============================================================
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null unique references public.accounts(id) on delete cascade,
  provider text,
  provider_subscription_id text,
  plan text not null,
  status text not null default 'inactive',
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  provider text,
  provider_payment_id text,
  amount numeric(12,2),
  currency text,
  status text not null,
  created_at timestamptz not null default now()
);

-- PaymentSession persistence fields.
--
-- These fields allow the backend PaymentSession model to survive a
-- backend restart and reconstruct pending/processing/completed payment
-- sessions from Supabase.
alter table public.payments
  add column if not exists plan text;

alter table public.payments
  add column if not exists checkout_token text;

alter table public.payments
  add column if not exists expires_at timestamptz;

alter table public.payments
  add column if not exists completed_at timestamptz;

alter table public.payments
  add column if not exists processor_transaction_id text;

alter table public.payments
  add column if not exists failure_reason text;

-- provider_payment_id is the backend PaymentSession ID for the current
-- backend payment provider implementation. It must remain unique so
-- persistence can safely update an existing payment instead of creating
-- duplicate rows after a backend restart or retry.
create unique index if not exists payments_provider_payment_id_unique
  on public.payments(provider_payment_id)
  where provider_payment_id is not null;

-- Efficiently load an account's payment history in chronological order.
create index if not exists payments_account_created_at_idx
  on public.payments(account_id, created_at desc);

-- ============================================================
-- PROFILE UI / FEATURES
-- ============================================================
create table if not exists public.profile_ui_settings (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  theme text not null default 'dark',
  accent_color text not null default '#F44336',
  navigation_position text not null default 'Bottom',
  navigation_order jsonb not null default '[]'::jsonb,
  home_layout text not null default 'default',
  card_style text not null default 'poster',
  density text not null default 'comfortable',
  font_scale numeric(4,2) not null default 1.0,
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_home_widgets (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  widget_type text not null,
  position integer not null default 0,
  visible boolean not null default true,
  configuration jsonb not null default '{}'::jsonb,
  unique(profile_id, widget_type)
);

create table if not exists public.profile_feature_settings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default true,
  configuration jsonb not null default '{}'::jsonb,
  unique(profile_id, feature_key)
);

-- ============================================================
-- SPORTS
-- ============================================================
create table if not exists public.sports_teams (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_team_id text not null,
  name text not null,
  league text,
  metadata jsonb not null default '{}'::jsonb,
  unique(provider, provider_team_id)
);

create table if not exists public.sports_games (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_game_id text not null,
  league text,
  home_team_id uuid references public.sports_teams(id) on delete set null,
  away_team_id uuid references public.sports_teams(id) on delete set null,
  starts_at timestamptz,
  status text,
  score_home integer,
  score_away integer,
  metadata jsonb not null default '{}'::jsonb,
  unique(provider, provider_game_id)
);

create table if not exists public.sports_broadcasts (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.sports_games(id) on delete cascade,
  provider text not null,
  stream_url text,
  authorized boolean not null default false,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.profile_followed_teams (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  team_id uuid not null references public.sports_teams(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(profile_id, team_id)
);

-- ============================================================
-- REMOTE WORKERS / BACKUPS / ACTIVITY / ACHIEVEMENTS
-- ============================================================
create table if not exists public.remote_workers (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  server_id uuid not null references public.servers(id) on delete cascade,
  worker_name text not null,
  status text not null default 'offline',
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.remote_jobs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  server_id uuid not null references public.servers(id) on delete cascade,
  worker_id uuid references public.remote_workers(id) on delete set null,
  job_type text not null,
  status text not null default 'queued',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.activity_events (
  id bigint generated always as identity primary key,
  account_id uuid references public.accounts(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text not null
);

create table if not exists public.profile_achievements (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id uuid not null references public.achievements(id) on delete cascade,
  progress integer not null default 0,
  unlocked_at timestamptz,
  primary key(profile_id, achievement_id)
);

create table if not exists public.backup_jobs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  server_id uuid not null references public.servers(id) on delete cascade,
  backup_type text not null,
  status text not null default 'queued',
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  account_id uuid references public.accounts(id) on delete set null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text,
  row_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- LEGAL / GOVERNANCE
-- ============================================================
create table if not exists public.legal_policies (
  id uuid primary key default gen_random_uuid(),
  policy_type text not null,
  version text not null,
  content text not null,
  published_at timestamptz not null default now(),
  unique(policy_type, version)
);

create table if not exists public.legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  policy_id uuid not null references public.legal_policies(id) on delete cascade,
  accepted_at timestamptz not null default now(),
  unique(account_id, policy_id)
);

create table if not exists public.copyright_reports (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references public.accounts(id) on delete set null,
  media_catalog_id uuid references public.media_catalog(id) on delete set null,
  reason text not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- ============================================================
-- TRIGGERS
-- ============================================================
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'accounts','profiles','servers','server_media','media_catalog','media_versions',
    'watch_progress','profile_media_reactions','collections','recommendations',
    'recommendation_votes','reviews','subscriptions','profile_ui_settings','profile_feature_settings'
  ] LOOP
    EXECUTE format('drop trigger if exists trg_%s_updated_at on public.%I', t, t);
    EXECUTE format('create trigger trg_%s_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  END LOOP;
END $$;

-- Automatically create application rows when Supabase Auth creates a user.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_username text;
begin
  v_username := coalesce(nullif(new.raw_user_meta_data->>'username',''), 'user_' || substr(replace(new.id::text,'-',''),1,8));
  insert into public.accounts(auth_user_id, username, display_name)
  values(new.id, v_username, coalesce(new.raw_user_meta_data->>'display_name', v_username))
  on conflict (auth_user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Create default owner profile/server/wishlist after account creation.
create or replace function public.bootstrap_account_rows()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(account_id, name, is_owner)
  values(new.id, coalesce(new.display_name, new.username), true)
  on conflict do nothing;
  insert into public.servers(account_id, name)
  values(new.id, 'Home Server')
  on conflict(account_id) do nothing;
  insert into public.wishlists(account_id)
  values(new.id)
  on conflict(account_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_account_bootstrap on public.accounts;
create trigger trg_account_bootstrap
after insert on public.accounts
for each row execute function public.bootstrap_account_rows();

-- Keep recommendation vote counters correct.
create or replace function public.recalculate_recommendation_votes()
returns trigger language plpgsql as $$
begin
  update public.recommendations r
  set yes_votes = (select count(*) from public.recommendation_votes v where v.recommendation_id=r.id and v.vote='yes'),
      no_votes  = (select count(*) from public.recommendation_votes v where v.recommendation_id=r.id and v.vote='no'),
      updated_at = now()
  where r.id = coalesce(new.recommendation_id, old.recommendation_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_recommendation_vote_counts on public.recommendation_votes;
create trigger trg_recommendation_vote_counts
after insert or update or delete on public.recommendation_votes
for each row execute function public.recalculate_recommendation_votes();

-- Record review rating changes for aggregate reporting through a materialized view/query.
create or replace function public.log_review_activity()
returns trigger language plpgsql as $$
begin
  insert into public.activity_events(account_id, profile_id, event_type, metadata)
  values(new.account_id, new.profile_id, 'review_created', jsonb_build_object('review_id', new.id, 'media_catalog_id', new.media_catalog_id));
  return new;
end;
$$;

drop trigger if exists trg_review_activity on public.reviews;
create trigger trg_review_activity
after insert on public.reviews
for each row execute function public.log_review_activity();

-- ============================================================
-- PROCEDURES / RPC
-- ============================================================

-- Returns the authenticated user's account id.
create or replace function public.my_account_id()
returns uuid language sql stable security invoker as $$
  select id from public.accounts where auth_user_id = auth.uid() limit 1;
$$;

-- Create a profile owned by the current account.
create or replace function public.create_profile(p_name text, p_avatar_url text default null)
returns public.profiles language plpgsql security invoker as $$
declare v public.profiles;
begin
  insert into public.profiles(account_id, name, avatar_url)
  values(public.my_account_id(), trim(p_name), p_avatar_url)
  returning * into v;
  return v;
end;
$$;

-- Register/heartbeat the account's home server.
create or replace function public.register_home_server(p_name text, p_endpoint text default null)
returns public.servers language plpgsql security invoker as $$
declare v public.servers;
begin
  insert into public.servers(account_id, name, public_endpoint, status, last_seen_at)
  values(public.my_account_id(), trim(p_name), p_endpoint, 'online', now())
  on conflict(account_id) do update set name=excluded.name, public_endpoint=excluded.public_endpoint, status='online', last_seen_at=now()
  returning * into v;
  return v;
end;
$$;

create or replace function public.server_heartbeat(p_server_id uuid)
returns boolean language plpgsql security invoker as $$
begin
  update public.servers
  set status='online', last_seen_at=now(), updated_at=now()
  where id=p_server_id and account_id=public.my_account_id();
  return found;
end;
$$;

-- Server scanner calls this with metadata only. It does not upload media files.
create or replace function public.upsert_server_media(
  p_server_id uuid,
  p_media_catalog_id uuid,
  p_server_media_id text,
  p_availability public.media_availability default 'available',
  p_metadata jsonb default '{}'::jsonb,
  p_last_seen_at timestamptz default now()
)
returns uuid language plpgsql security invoker as $$
declare v_id uuid;
begin
  if not exists(select 1 from public.servers where id=p_server_id and account_id=public.my_account_id()) then
    raise exception 'Server does not belong to current account';
  end if;
  insert into public.server_media(server_id, media_catalog_id, server_media_id, availability, metadata, last_seen_at)
  values(p_server_id,p_media_catalog_id,p_server_media_id,p_availability,p_metadata,p_last_seen_at)
  on conflict(server_id,server_media_id) do update
    set media_catalog_id=excluded.media_catalog_id, availability=excluded.availability,
        metadata=excluded.metadata, last_seen_at=excluded.last_seen_at, updated_at=now()
  returning id into v_id;
  return v_id;
end;
$$;

-- Exact-version Group Watch compatibility check.
create or replace function public.check_group_watch_compatibility(
  p_media_catalog_id uuid,
  p_version_key text,
  p_profile_ids uuid[]
)
returns table(compatible boolean, reason text, profile_id uuid, server_id uuid, server_media_id uuid, version_id uuid)
language plpgsql security invoker as $$
declare v_profile uuid; v_count integer := 0; v_ok integer := 0;
begin
  if coalesce(array_length(p_profile_ids,1),0)=0 then
    return query select false, 'No participants supplied'::text, null::uuid,null::uuid,null::uuid,null::uuid;
    return;
  end if;
  foreach v_profile in array p_profile_ids loop
    v_count := v_count + 1;
    return query
      select exists(
        select 1
        from public.profiles p
        join public.accounts a on a.id=p.account_id
        join public.servers s on s.account_id=a.id
        join public.server_media sm on sm.server_id=s.id and sm.media_catalog_id=p_media_catalog_id and sm.availability='available'
        join public.media_versions mv on mv.server_media_id=sm.id and mv.version_key=p_version_key
        where p.id=v_profile
      ),
      case when exists(
        select 1 from public.profiles p join public.accounts a on a.id=p.account_id join public.servers s on s.account_id=a.id
        join public.server_media sm on sm.server_id=s.id and sm.media_catalog_id=p_media_catalog_id and sm.availability='available'
        join public.media_versions mv on mv.server_media_id=sm.id and mv.version_key=p_version_key
        where p.id=v_profile
      ) then 'Exact version available' else 'Exact version is not available on this participant server' end,
      v_profile,
      (select s.id from public.profiles p join public.accounts a on a.id=p.account_id join public.servers s on s.account_id=a.id where p.id=v_profile limit 1),
      (select sm.id from public.profiles p join public.accounts a on a.id=p.account_id join public.servers s on s.account_id=a.id join public.server_media sm on sm.server_id=s.id and sm.media_catalog_id=p_media_catalog_id and sm.availability='available' join public.media_versions mv on mv.server_media_id=sm.id and mv.version_key=p_version_key where p.id=v_profile limit 1),
      (select mv.id from public.profiles p join public.accounts a on a.id=p.account_id join public.servers s on s.account_id=a.id join public.server_media sm on sm.server_id=s.id and sm.media_catalog_id=p_media_catalog_id and sm.availability='available' join public.media_versions mv on mv.server_media_id=sm.id and mv.version_key=p_version_key where p.id=v_profile limit 1);
  end loop;
end;
$$;

-- Atomically create a Group Watch session only if every participant has the same exact version.
create or replace function public.create_group_watch_session(
  p_media_catalog_id uuid,
  p_version_key text,
  p_profile_ids uuid[]
)
returns uuid language plpgsql security invoker as $$
declare v_session uuid; v_profile uuid; v_creator_profile uuid; v_server uuid; v_media uuid; v_version uuid;
begin
  if exists(select 1 from public.check_group_watch_compatibility(p_media_catalog_id,p_version_key,p_profile_ids) c where c.compatible=false) then
    raise exception 'Group Watch requires the exact same media version on every participant server';
  end if;
  select p.id into v_creator_profile from public.profiles p where p.account_id=public.my_account_id() order by p.is_owner desc, p.created_at limit 1;
  if v_creator_profile is null then raise exception 'Current account has no profile'; end if;
  insert into public.group_watch_sessions(created_by_profile_id,media_catalog_id,required_version_key)
  values(v_creator_profile,p_media_catalog_id,p_version_key)
  returning id into v_session;
  foreach v_profile in array p_profile_ids loop
    select c.server_id,c.server_media_id,c.version_id into v_server,v_media,v_version
    from public.check_group_watch_compatibility(p_media_catalog_id,p_version_key,array[v_profile]) c where c.compatible=true limit 1;
    insert into public.group_watch_participants(session_id,account_id,profile_id,server_id,server_media_id,version_id)
    select v_session,p.account_id,v_profile,v_server,v_media,v_version from public.profiles p where p.id=v_profile;
  end loop;
  return v_session;
end;
$$;

-- Remove a server's stale metadata without touching physical server files.
create or replace function public.mark_stale_server_media(p_server_id uuid, p_before timestamptz)
returns integer language plpgsql security invoker as $$
declare v_count integer;
begin
  update public.server_media set availability='missing', updated_at=now()
  where server_id=p_server_id and last_seen_at < p_before and availability='available';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ============================================================
-- INDEXES
-- ============================================================
create index if not exists idx_profiles_account on public.profiles(account_id);
create index if not exists idx_servers_account on public.servers(account_id);
create index if not exists idx_server_media_server on public.server_media(server_id);
create index if not exists idx_server_media_catalog on public.server_media(media_catalog_id);
create index if not exists idx_media_versions_server_media on public.media_versions(server_media_id);
create index if not exists idx_watch_history_profile_time on public.watch_history(profile_id, watched_at desc);
create index if not exists idx_reviews_media on public.reviews(media_catalog_id, created_at desc);
create index if not exists idx_group_watch_participants_session on public.group_watch_participants(session_id);
create index if not exists idx_activity_account_time on public.activity_events(account_id, created_at desc);
comment on table public.payments is
  'Persistent payment-session records for account subscriptions. Payment records contain transaction metadata and checkout state; actual payment processing is performed by the configured backend payment provider.';

comment on column public.payments.provider_payment_id is
  'Backend/provider payment-session identifier. Unique when present so payment persistence is idempotent.';

comment on column public.payments.checkout_token is
  'Temporary checkout authorization token used by the backend checkout flow.';

comment on column public.payments.processor_transaction_id is
  'Transaction identifier returned by the external payment processor after payment completion.';

comment on column public.payments.failure_reason is
  'Backend/payment-provider failure information associated with an unsuccessful payment attempt.';
-- ============================================================
-- RLS
-- ============================================================
alter table public.accounts enable row level security;
alter table public.profiles enable row level security;
alter table public.servers enable row level security;
alter table public.server_storage enable row level security;
alter table public.media_catalog enable row level security;
alter table public.server_media enable row level security;
alter table public.media_versions enable row level security;
alter table public.profile_library enable row level security;
alter table public.watch_progress enable row level security;
alter table public.watch_history enable row level security;
alter table public.profile_media_reactions enable row level security;
alter table public.wishlists enable row level security;
alter table public.wishlist_items enable row level security;
alter table public.collections enable row level security;
alter table public.collection_items enable row level security;
alter table public.recommendations enable row level security;
alter table public.recommendation_votes enable row level security;
alter table public.reviews enable row level security;
alter table public.review_likes enable row level security;
alter table public.group_watch_sessions enable row level security;
alter table public.group_watch_participants enable row level security;
alter table public.group_watch_events enable row level security;
alter table public.chat_rooms enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;
alter table public.devices enable row level security;
alter table public.device_sessions enable row level security;
alter table public.security_events enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.profile_ui_settings enable row level security;
alter table public.profile_home_widgets enable row level security;
alter table public.profile_feature_settings enable row level security;
alter table public.profile_followed_teams enable row level security;
alter table public.remote_workers enable row level security;
alter table public.remote_jobs enable row level security;
alter table public.activity_events enable row level security;
alter table public.profile_achievements enable row level security;
alter table public.backup_jobs enable row level security;
alter table public.audit_log enable row level security;
alter table public.legal_acceptances enable row level security;
alter table public.copyright_reports enable row level security;

-- Public/reference tables.
alter table public.sports_teams enable row level security;
alter table public.sports_games enable row level security;
alter table public.sports_broadcasts enable row level security;
alter table public.achievements enable row level security;
alter table public.legal_policies enable row level security;

do $$
declare r record;
begin
  -- Remove policies generated by previous versions of this migration.
  for r in select schemaname, tablename, policyname from pg_policies where schemaname='public' loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Account-scoped helper expression is used repeatedly.
create policy accounts_self on public.accounts for select using (auth.uid() = auth_user_id);
create policy accounts_update on public.accounts for update using (auth.uid() = auth_user_id) with check (auth.uid() = auth_user_id);
create policy profiles_account on public.profiles for all using (account_id = public.my_account_id()) with check (account_id = public.my_account_id());
create policy servers_account on public.servers for all using (account_id = public.my_account_id()) with check (account_id = public.my_account_id());
create policy storage_account on public.server_storage for all using (exists(select 1 from public.servers s where s.id=server_id and s.account_id=public.my_account_id())) with check (exists(select 1 from public.servers s where s.id=server_id and s.account_id=public.my_account_id()));
create policy server_media_account on public.server_media for all using (exists(select 1 from public.servers s where s.id=server_id and s.account_id=public.my_account_id())) with check (exists(select 1 from public.servers s where s.id=server_id and s.account_id=public.my_account_id()));
create policy media_versions_account on public.media_versions for all using (exists(select 1 from public.server_media sm join public.servers s on s.id=sm.server_id where sm.id=server_media_id and s.account_id=public.my_account_id())) with check (exists(select 1 from public.server_media sm join public.servers s on s.id=sm.server_id where sm.id=server_media_id and s.account_id=public.my_account_id()));
create policy catalog_read on public.media_catalog for select using (true);
create policy catalog_modify on public.media_catalog for all using (exists(select 1 from public.server_media sm join public.servers s on s.id=sm.server_id where sm.media_catalog_id=media_catalog.id and s.account_id=public.my_account_id())) with check (true);

create policy profile_library_own on public.profile_library for all using (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id())) with check (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id()));
create policy watch_progress_own on public.watch_progress for all using (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id())) with check (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id()));
create policy watch_history_own on public.watch_history for all using (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id())) with check (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id()));
create policy reactions_own on public.profile_media_reactions for all using (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id())) with check (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id()));
create policy wishlist_account on public.wishlists for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy wishlist_items_account on public.wishlist_items for all using (exists(select 1 from public.wishlists w where w.id=wishlist_id and w.account_id=public.my_account_id())) with check (exists(select 1 from public.wishlists w where w.id=wishlist_id and w.account_id=public.my_account_id()));
create policy collections_account on public.collections for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy collection_items_account on public.collection_items for all using (exists(select 1 from public.collections c where c.id=collection_id and c.account_id=public.my_account_id())) with check (exists(select 1 from public.collections c where c.id=collection_id and c.account_id=public.my_account_id()));

create policy recommendations_read on public.recommendations for select using (target_account_id=public.my_account_id() or exists(select 1 from public.profiles p where p.id=created_by_profile_id and p.account_id=public.my_account_id()));
create policy recommendations_write on public.recommendations for insert with check (exists(select 1 from public.profiles p where p.id=created_by_profile_id and p.account_id=public.my_account_id()));
create policy recommendation_votes_own on public.recommendation_votes for all using (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id())) with check (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id()));

create policy reviews_public_read on public.reviews for select using (visibility='global' or account_id=public.my_account_id());
create policy reviews_own_write on public.reviews for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy review_likes_own on public.review_likes for all using (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id())) with check (exists(select 1 from public.profiles p where p.id=profile_id and p.account_id=public.my_account_id()));

create policy group_sessions_read on public.group_watch_sessions for select using (created_by_profile_id in (select id from public.profiles where account_id=public.my_account_id()) or id in (select session_id from public.group_watch_participants where account_id=public.my_account_id()));
create policy group_sessions_create on public.group_watch_sessions for insert with check (created_by_profile_id in (select id from public.profiles where account_id=public.my_account_id()));
create policy group_participants_access on public.group_watch_participants for all using (account_id=public.my_account_id() or session_id in (select id from public.group_watch_sessions where created_by_profile_id in (select id from public.profiles where account_id=public.my_account_id()))) with check (account_id=public.my_account_id());
create policy group_events_access on public.group_watch_events for all using (session_id in (select id from public.group_watch_sessions where created_by_profile_id in (select id from public.profiles where account_id=public.my_account_id()) or id in (select session_id from public.group_watch_participants where account_id=public.my_account_id()))) with check (session_id in (select id from public.group_watch_sessions where created_by_profile_id in (select id from public.profiles where account_id=public.my_account_id()) or id in (select session_id from public.group_watch_participants where account_id=public.my_account_id())));

create policy devices_account on public.devices for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy sessions_account on public.device_sessions for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy security_events_account on public.security_events for select using (account_id=public.my_account_id());
create policy subscriptions_account on public.subscriptions for select using (account_id=public.my_account_id());
create policy payments_account on public.payments for select using (account_id=public.my_account_id());
create policy ui_settings_own on public.profile_ui_settings for all using (profile_id in (select id from public.profiles where account_id=public.my_account_id())) with check (profile_id in (select id from public.profiles where account_id=public.my_account_id()));
create policy home_widgets_own on public.profile_home_widgets for all using (profile_id in (select id from public.profiles where account_id=public.my_account_id())) with check (profile_id in (select id from public.profiles where account_id=public.my_account_id()));
create policy feature_settings_own on public.profile_feature_settings for all using (profile_id in (select id from public.profiles where account_id=public.my_account_id())) with check (profile_id in (select id from public.profiles where account_id=public.my_account_id()));
create policy followed_teams_own on public.profile_followed_teams for all using (profile_id in (select id from public.profiles where account_id=public.my_account_id())) with check (profile_id in (select id from public.profiles where account_id=public.my_account_id()));
create policy workers_account on public.remote_workers for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy jobs_account on public.remote_jobs for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy activity_account on public.activity_events for select using (account_id=public.my_account_id());
create policy achievements_read on public.achievements for select using (true);
create policy profile_achievements_own on public.profile_achievements for all using (profile_id in (select id from public.profiles where account_id=public.my_account_id())) with check (profile_id in (select id from public.profiles where account_id=public.my_account_id()));
create policy backups_account on public.backup_jobs for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy audit_account on public.audit_log for select using (account_id=public.my_account_id());
create policy legal_public on public.legal_policies for select using (true);
create policy legal_acceptance_account on public.legal_acceptances for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy copyright_account on public.copyright_reports for all using (account_id=public.my_account_id()) with check (account_id=public.my_account_id());
create policy sports_teams_public on public.sports_teams for select using (true);
create policy sports_games_public on public.sports_games for select using (true);
create policy sports_broadcasts_public on public.sports_broadcasts for select using (authorized=true);

-- ============================================================
-- REALTIME
-- ============================================================
do $$ begin
  alter publication supabase_realtime add table public.group_watch_events;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.chat_messages;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- ============================================================
-- SCHEDULED JOBS
-- ============================================================
do $$ begin
  perform cron.schedule('mark-offline-servers', '*/5 * * * *', $$update public.servers set status='offline', updated_at=now() where status='online' and last_seen_at < now() - interval '10 minutes'$$);
exception when others then null; end $$;

do $$ begin
  perform cron.schedule('expire-device-sessions', '*/15 * * * *', $$delete from public.device_sessions where expires_at < now() or revoked_at is not null$$);
exception when others then null; end $$;

do $$ begin
  perform cron.schedule('mark-stale-server-media', '15 * * * *', $$update public.server_media set availability='missing', updated_at=now() where availability='available' and last_seen_at < now() - interval '24 hours'$$);
exception when others then null; end $$;

-- ============================================================
-- COMMENTS / GUARANTEES
-- ============================================================
comment on table public.server_media is 'Metadata/index of media physically stored on an account home server. No media files are stored in Supabase.';
comment on column public.server_media.relative_media_key is 'Server-private lookup key/path. Never expose directly to untrusted clients.';
comment on table public.group_watch_participants is 'Cross-account participants. Playback is allowed only when every participant server has the exact same version_key.';
comment on table public.reviews is 'Public reviews expose public_username only; account/profile IDs remain private under RLS.';


-- Application security fields: only hashes/challenge metadata are stored; plaintext passwords/MFA codes are never persisted.
alter table if exists public.account_private_credentials add column if not exists mfa_enabled boolean not null default false;
alter table if exists public.account_private_credentials add column if not exists mfa_challenge_hash text;
alter table if exists public.account_private_credentials add column if not exists mfa_challenge_expires_at timestamptz;
