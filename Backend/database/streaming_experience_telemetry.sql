-- Streaming Experience: QoE telemetry, discovery feedback, and per-profile settings.
--
-- IMPORTANT: app account/profile ids are application identifiers, not assumed
-- to be auth.uid() UUIDs. RLS is enabled with no client policies on purpose.
-- Only a trusted backend/Edge Function using the Supabase service role should
-- read/write these records after validating the authenticated account/profile.
-- Never put the service-role key in Flutter.

create table if not exists public.streaming_playback_qoe_events (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  media_id text not null,
  session_id text not null,
  event_type text not null check (event_type in (
    'play_requested', 'player_ready', 'buffer_start', 'buffer_end',
    'seek', 'paused', 'resumed', 'playback_error', 'completed'
  )),
  occurred_at timestamptz not null default now(),
  value_ms integer check (value_ms is null or value_ms >= 0),
  device_class text check (device_class is null or device_class in ('mobile', 'desktop', 'tv', 'web', 'unknown')),
  metadata jsonb not null default '{}'::jsonb,
  ingested_at timestamptz not null default now()
);

create index if not exists streaming_qoe_profile_time_idx
  on public.streaming_playback_qoe_events (account_id, profile_id, occurred_at desc);
create index if not exists streaming_qoe_session_idx
  on public.streaming_playback_qoe_events (session_id, occurred_at);
create index if not exists streaming_qoe_type_time_idx
  on public.streaming_playback_qoe_events (event_type, occurred_at desc);

create table if not exists public.streaming_discovery_feedback (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  profile_id text not null,
  media_id text not null,
  action text not null check (action in (
    'like', 'dislike', 'not_interested', 'play', 'complete',
    'search_open', 'add_to_collection', 'share', 'skip'
  )),
  source text not null default 'unknown',
  occurred_at timestamptz not null default now(),
  context jsonb not null default '{}'::jsonb
);

create index if not exists streaming_feedback_profile_time_idx
  on public.streaming_discovery_feedback (account_id, profile_id, occurred_at desc);
create index if not exists streaming_feedback_media_action_idx
  on public.streaming_discovery_feedback (profile_id, media_id, action);

create table if not exists public.streaming_profile_preferences (
  account_id text not null,
  profile_id text not null,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id)
);

alter table public.streaming_playback_qoe_events enable row level security;
alter table public.streaming_discovery_feedback enable row level security;
alter table public.streaming_profile_preferences enable row level security;

revoke all on public.streaming_playback_qoe_events from anon, authenticated;
revoke all on public.streaming_discovery_feedback from anon, authenticated;
revoke all on public.streaming_profile_preferences from anon, authenticated;
grant all on public.streaming_playback_qoe_events to service_role;
grant all on public.streaming_discovery_feedback to service_role;
grant all on public.streaming_profile_preferences to service_role;
