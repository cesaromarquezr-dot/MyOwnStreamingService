-- Connected Innovation foundations (Phase 1-4 shared persistence).
-- Additive migration: does not rewrite or replace the historical migrations.
-- Apply only after reviewing against the target Supabase schema.

create table if not exists public.media_access_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null check (item_type in ('movie','episode','series','song','album','playlist','collection','product','store','restaurant','post','community')),
  item_id text not null,
  access_state text not null check (access_state in ('owned','subscribed','purchased','rented','shared','available','restricted','unavailable')),
  source text not null default 'system',
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, item_type, item_id, source)
);

create table if not exists public.saved_universe_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null,
  item_id text not null,
  collection_id text,
  visibility text not null default 'private' check (visibility in ('private','friends','shared')),
  created_at timestamptz not null default now(),
  unique (user_id, item_type, item_id, collection_id)
);

create table if not exists public.unified_activity_events (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  entity_type text,
  entity_id text,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists media_access_records_user_item_idx on public.media_access_records(user_id, item_type, item_id);
create index if not exists saved_universe_items_user_created_idx on public.saved_universe_items(user_id, created_at desc);
create index if not exists unified_activity_events_recipient_created_idx on public.unified_activity_events(recipient_user_id, created_at desc);
create index if not exists unified_activity_events_unread_idx on public.unified_activity_events(recipient_user_id, created_at desc) where read_at is null;

alter table public.media_access_records enable row level security;
alter table public.saved_universe_items enable row level security;
alter table public.unified_activity_events enable row level security;

drop policy if exists "users read own media access" on public.media_access_records;
create policy "users read own media access" on public.media_access_records for select using (auth.uid() = user_id);
-- No client-side write policy for entitlements: trusted server/service role only.

drop policy if exists "users manage own saved items" on public.saved_universe_items;
create policy "users manage own saved items" on public.saved_universe_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "users read own activity" on public.unified_activity_events;
create policy "users read own activity" on public.unified_activity_events for select using (auth.uid() = recipient_user_id);
drop policy if exists "users update own activity read state" on public.unified_activity_events;
create policy "users update own activity read state" on public.unified_activity_events for update using (auth.uid() = recipient_user_id) with check (auth.uid() = recipient_user_id);

comment on table public.media_access_records is 'Per-user entitlement and access state. Server must verify provider rights before allowing playback, downloads, sharing, or purchases.';
comment on table public.saved_universe_items is 'Cross-domain saved items for personal and shared collections.';
comment on table public.unified_activity_events is 'Unified social, watch-party, discovery and commerce activity inbox.';
