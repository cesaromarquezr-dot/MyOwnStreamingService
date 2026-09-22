-- Flutter -> backend -> Supabase synchronization layer.
--
-- IMPORTANT:
-- This table stores application/account metadata only.
-- Physical movie, TV, music, disc, and other media files remain on each
-- account's home server and are NEVER uploaded to Supabase.
--
-- Synchronization flow:
--
--   Flutter AppController
--          |
--          | POST /api/v1/supabase/sync/account
--          v
--   Authenticated Dart backend
--          |
--          | sanitized metadata
--          v
--   SupabaseStore
--          |
--          v
--   account_sync_snapshots
--
-- The backend is responsible for authenticating the request and sanitizing
-- the snapshot before writing it to Supabase.
--
-- Flutter clients do not receive direct write access to this table.

create table if not exists public.account_sync_snapshots (
  external_account_id text primary key,

  -- Basic account metadata.
  username text not null,
  email text not null,
  status text not null default 'active',

  -- Storage metadata only.
  -- These values describe the account's home-server storage state.
  -- They do not represent files stored in Supabase.

  storage_limit_bytes bigint not null default 0,
  storage_used_bytes bigint not null default 0,

  -- Storage expansion request state.
  storage_request_pending boolean not null default false,
  storage_requested_terabytes integer not null default 0,
  storage_request_fee_usd numeric(12,2) not null default 0,
  storage_request_status text not null default 'none',
  storage_request_at timestamptz,

  -- Sanitized application metadata.
  profiles jsonb not null default '[]'::jsonb,
  shared_media_ids jsonb not null default '[]'::jsonb,
  wishlist_media_ids jsonb not null default '[]'::jsonb,
  wishlist_recommendation_ids jsonb not null default '[]'::jsonb,
  notifications jsonb not null default '[]'::jsonb,

  -- Client/application state that is safe to persist remotely.
  --
  -- Authentication credentials, session tokens, service-role keys,
  -- private filesystem paths, and other secrets must never be included.
  client_snapshot jsonb not null default '{}'::jsonb,

  -- Last successful synchronization time.
  synced_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
--
-- No client policy is intentionally provided.
--
-- The authenticated Dart backend writes this table using the Supabase
-- service-role connection after authenticating the Flutter user's own
-- backend session.
--
-- The service-role key must NEVER be included in Flutter.

alter table public.account_sync_snapshots
  enable row level security;

-- Intentionally no INSERT, UPDATE, DELETE, or SELECT policy is created.
--
-- This prevents normal Supabase client roles from accessing the synchronized
-- account snapshot directly.

-- ---------------------------------------------------------------------------
-- Documentation
-- ---------------------------------------------------------------------------

comment on table public.account_sync_snapshots is
  'Sanitized Flutter account metadata mirror. Physical media files never live in Supabase.';

comment on column public.account_sync_snapshots.external_account_id is
  'Stable account identifier from the authenticated application backend.';

comment on column public.account_sync_snapshots.storage_limit_bytes is
  'Account home-server storage limit metadata; no physical media is stored here.';

comment on column public.account_sync_snapshots.storage_used_bytes is
  'Account home-server storage usage metadata; no physical media is stored here.';

comment on column public.account_sync_snapshots.profiles is
  'Sanitized account profile metadata synchronized from the application backend.';

comment on column public.account_sync_snapshots.shared_media_ids is
  'Identifiers for shared media metadata; physical media files remain on home servers.';

comment on column public.account_sync_snapshots.wishlist_media_ids is
  'Media identifiers from the account wishlist.';

comment on column public.account_sync_snapshots.wishlist_recommendation_ids is
  'Recommendation identifiers associated with the account wishlist.';

comment on column public.account_sync_snapshots.notifications is
  'Sanitized application notification metadata.';

comment on column public.account_sync_snapshots.client_snapshot is
  'Sanitized client/application state. Must never contain credentials, session tokens, service-role keys, or private filesystem paths.';

comment on column public.account_sync_snapshots.synced_at is
  'Timestamp of the most recent successful backend synchronization.';