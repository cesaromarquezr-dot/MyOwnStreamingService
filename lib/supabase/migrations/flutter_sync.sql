-- Flutter -> backend -> Supabase synchronization layer.
-- IMPORTANT: This stores application/account metadata only. Physical media
-- files remain on each account's home server and are never uploaded here.

create table if not exists public.account_sync_snapshots (
  external_account_id text primary key,
  username text not null,
  email text not null,
  status text not null default 'active',
  storage_limit_bytes bigint not null default 0,
  storage_used_bytes bigint not null default 0,
  storage_request_pending boolean not null default false,
  storage_requested_terabytes integer not null default 0,
  storage_request_fee_usd numeric(12,2) not null default 0,
  storage_request_status text not null default 'none',
  storage_request_at timestamptz,
  profiles jsonb not null default '[]'::jsonb,
  shared_media_ids jsonb not null default '[]'::jsonb,
  wishlist_media_ids jsonb not null default '[]'::jsonb,
  wishlist_recommendation_ids jsonb not null default '[]'::jsonb,
  notifications jsonb not null default '[]'::jsonb,
  client_snapshot jsonb not null default '{}'::jsonb,
  synced_at timestamptz not null default now()
);

alter table public.account_sync_snapshots enable row level security;

-- No client policy is intentionally provided. The service-role backend writes
-- this table after authenticating the Flutter user's backend session.

comment on table public.account_sync_snapshots is
  'Sanitized Flutter account metadata mirror. Physical media files never live in Supabase.';
