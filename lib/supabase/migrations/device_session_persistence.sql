-- FILE: lib/supabase/migrations/20260919_device_session_persistence.sql
-- Purpose: Makes remembered-device records safe to reuse when the backend
-- restarts and prevents duplicate device rows for the same account/device.
-- Raw session tokens are never stored in Supabase; device_sessions stores
-- only a SHA-256 token hash.

create unique index if not exists idx_devices_account_fingerprint
  on public.devices(account_id, fingerprint_hash)
  where fingerprint_hash is not null;

create index if not exists idx_device_sessions_account
  on public.device_sessions(account_id);

create index if not exists idx_device_sessions_expires
  on public.device_sessions(expires_at);
