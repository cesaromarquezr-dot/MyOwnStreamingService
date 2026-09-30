-- Cross-feature application state used by local-first UI features.
-- The table contains non-financial application metadata only.

create table if not exists public.app_records (
  id text primary key,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_external_id text not null default '',
  record_type text not null check (char_length(record_type) between 1 and 120),
  record_key text not null check (char_length(record_key) between 1 and 240),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, profile_external_id, record_type, record_key)
);

create index if not exists app_records_account_type_idx
  on public.app_records(account_id, record_type, updated_at desc);

create index if not exists app_records_profile_type_idx
  on public.app_records(account_id, profile_external_id, record_type, updated_at desc);

alter table public.app_records enable row level security;

-- Backend routes use the service role and enforce account/profile ownership.
