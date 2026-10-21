-- Customer support and ticket management. Apply through the normal Supabase migration process.
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  account_id text not null,
  subject varchar(160) not null,
  category text not null check (category in ('account','billing','playback','devices','music','social','shop','food_delivery','privacy','other')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  description text not null check (char_length(description) between 1 and 12000),
  status text not null default 'open' check (status in ('open','in_progress','waiting_on_customer','resolved','closed')),
  replies jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists support_tickets_account_updated_idx on public.support_tickets (account_id, updated_at desc);
create index if not exists support_tickets_status_updated_idx on public.support_tickets (status, updated_at desc);
alter table public.support_tickets enable row level security;
-- No client policies by design: all access goes through the authenticated backend,
-- which uses its server-only service-role key and enforces account/staff scope.
