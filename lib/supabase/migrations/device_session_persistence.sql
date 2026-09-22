-- FILE: lib/supabase/migrations/20260919_device_session_persistence.sql
--
-- Purpose:
-- Makes remembered-device records safe to reuse when the backend restarts
-- and prevents duplicate device rows for the same account/device.
--
-- Security:
-- Raw session tokens are NEVER stored in Supabase.
-- device_sessions stores only a SHA-256 token hash.
--
-- Device identity:
-- A fingerprint identifies a remembered device within an account.
-- The partial unique index intentionally ignores NULL fingerprints so that
-- records without a fingerprint do not conflict with one another.

-- ---------------------------------------------------------------------------
-- Device uniqueness
-- ---------------------------------------------------------------------------
--
-- Prevent duplicate remembered-device records for the same account and
-- device fingerprint.
--
-- The partial index permits multiple rows where fingerprint_hash is NULL.

create unique index if not exists idx_devices_account_fingerprint
  on public.devices(account_id, fingerprint_hash)
  where fingerprint_hash is not null;

-- ---------------------------------------------------------------------------
-- Device-session lookup indexes
-- ---------------------------------------------------------------------------
--
-- Used when loading remembered sessions belonging to an account.

create index if not exists idx_device_sessions_account
  on public.device_sessions(account_id);

-- Used when finding or cleaning up expired remembered-device sessions.

create index if not exists idx_device_sessions_expires
  on public.device_sessions(expires_at);

-- ---------------------------------------------------------------------------
-- Security documentation
-- ---------------------------------------------------------------------------

comment on index idx_devices_account_fingerprint is
  'Ensures one non-null device fingerprint per account while allowing devices without a fingerprint.';

comment on column public.device_sessions.token_hash is
  'SHA-256 hash of the device session token. Raw session tokens must never be stored in Supabase.';