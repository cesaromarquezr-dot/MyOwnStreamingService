-- Account-wide scheduled library publication. The physical file remains on the home NAS.
create table if not exists public.library_additions (
  id text primary key,
  account_id text not null,
  server_media_id text not null,
  title text not null,
  media_type text not null,
  scheduled_for timestamptz not null,
  scheduled_timezone text not null default 'UTC',
  status text not null default 'scheduled' check (status in ('scheduled','published','cancelled','failed')),
  created_at timestamptz not null default now(),
  published_at timestamptz,
  cancelled_at timestamptz
);
create index if not exists idx_library_additions_account_schedule on public.library_additions(account_id, scheduled_for);
create index if not exists idx_library_additions_status_schedule on public.library_additions(status, scheduled_for);
comment on table public.library_additions is 'Controls account-library publication timing; physical media remains on the account NAS and is shared by account members.';
