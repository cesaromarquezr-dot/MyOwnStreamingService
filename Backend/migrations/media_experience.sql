-- Private owned-media experiences. Run this migration before the feature indexes.
-- No payment, rental, checkout, admission, or return records are stored here.
create table if not exists public.owned_experience_records (
  id bigserial primary key,
  account_id text not null,
  profile_id text not null default '',
  record_type text not null check (record_type in (
    'collection', 'theater_session', 'kiosk_session', 'kiosk_favorite',
    'kiosk_preferences', 'media_progress'
  )),
  record_id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint owned_experience_records_scope_key
    unique (account_id, profile_id, record_type, record_id)
);

create index if not exists owned_experience_records_profile_type_updated_idx
  on public.owned_experience_records (account_id, profile_id, record_type, updated_at desc);

create index if not exists owned_experience_records_data_gin_idx
  on public.owned_experience_records using gin (data);

comment on table public.owned_experience_records is
  'Server-side account/profile scoped metadata for private owned-media collections, kiosk preferences/sessions, theater sessions, and playback progress.';

-- Access is through the authenticated Dart backend using the Supabase service role.
-- Do not add anon/authenticated policies; the backend enforces account scoping.
alter table public.owned_experience_records enable row level security;
