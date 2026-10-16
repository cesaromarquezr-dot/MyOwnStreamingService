-- Production readiness foundation: privacy preferences, sanitized action audit,
-- idempotent offline-sync receipts, health snapshots, and backup run history.
--
-- SAFETY: application account/profile identifiers are opaque text IDs; they are
-- not assumed to equal auth.uid(). These records are backend-managed only.
-- Validate each request against the authenticated account/profile in the Dart
-- backend before using the service-role credential. Never ship service-role
-- credentials to Flutter. No client policies are intentionally created here.

create table if not exists public.profile_privacy_preferences (
  account_id text not null,
  profile_id text not null,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id),
  constraint profile_privacy_preferences_json_object check (jsonb_typeof(preferences) = 'object')
);

create table if not exists public.hey_media_action_audit (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  action_key text not null check (action_key in (
    'search_library', 'start_playback', 'create_playlist', 'share_media',
    'send_message', 'place_order', 'purchase', 'delete_media',
    'change_security', 'change_privacy', 'unknown'
  )),
  target_id text,
  outcome text not null check (outcome in ('allowed', 'denied', 'awaiting_confirmation', 'failed')),
  confirmation_required boolean not null default false,
  occurred_at timestamptz not null default now()
  -- Never store full AI prompts, message bodies, auth tokens or payment details.
);
create index if not exists hey_media_action_audit_account_time_idx
  on public.hey_media_action_audit (account_id, occurred_at desc);

create table if not exists public.offline_sync_receipts (
  account_id text not null,
  profile_id text not null,
  action_id text not null,
  action_type text not null check (action_type in ('playback_progress')),
  resource_id text not null,
  result text not null check (result in ('accepted', 'rejected', 'duplicate')),
  received_at timestamptz not null default now(),
  primary key (account_id, action_id)
);

create table if not exists public.production_service_health_snapshots (
  id uuid primary key default gen_random_uuid(),
  service_key text not null,
  status text not null check (status in ('healthy', 'degraded', 'unavailable', 'unknown')),
  details jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default now()
);
create index if not exists production_service_health_time_idx
  on public.production_service_health_snapshots (observed_at desc, service_key);

create table if not exists public.production_backup_runs (
  id uuid primary key default gen_random_uuid(),
  backup_id text not null unique,
  outcome text not null check (outcome in ('started', 'succeeded', 'failed', 'restore_tested')),
  encrypted boolean not null default false,
  checksum_sha256 text,
  details jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists production_backup_runs_time_idx
  on public.production_backup_runs (started_at desc);

alter table public.profile_privacy_preferences enable row level security;
alter table public.hey_media_action_audit enable row level security;
alter table public.offline_sync_receipts enable row level security;
alter table public.production_service_health_snapshots enable row level security;
alter table public.production_backup_runs enable row level security;

revoke all on public.profile_privacy_preferences from anon, authenticated;
revoke all on public.hey_media_action_audit from anon, authenticated;
revoke all on public.offline_sync_receipts from anon, authenticated;
revoke all on public.production_service_health_snapshots from anon, authenticated;
revoke all on public.production_backup_runs from anon, authenticated;

grant all on public.profile_privacy_preferences to service_role;
grant all on public.hey_media_action_audit to service_role;
grant all on public.offline_sync_receipts to service_role;
grant all on public.production_service_health_snapshots to service_role;
grant all on public.production_backup_runs to service_role;
