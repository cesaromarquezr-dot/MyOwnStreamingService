-- MyOwnStreamingService: platform server selection schema
-- Apply this script in the Supabase SQL Editor after the base accounts schema
-- (including public.accounts) has been installed.
-- Safe to run more than once.

begin;

create extension if not exists pgcrypto;

create table if not exists public.platform_warehouses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  status text not null default 'online',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_servers (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references public.platform_warehouses(id) on delete cascade,
  name text not null,
  status text not null default 'available',
  storage_total_bytes bigint not null default 0,
  storage_used_bytes bigint not null default 0,
  ram_gb integer not null default 0,
  cpu_cores integer not null default 0,
  ssh_enabled boolean not null default false,
  endpoint text,
  claimed_account_id uuid references public.accounts(id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_server_assignments (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  server_id uuid not null references public.platform_servers(id) on delete cascade,
  display_name text not null,
  role text not null default 'owner',
  assigned_at timestamptz not null default now(),
  released_at timestamptz
);

create index if not exists idx_platform_servers_available
  on public.platform_servers(status, claimed_account_id);
create index if not exists idx_platform_servers_warehouse
  on public.platform_servers(warehouse_id);
create unique index if not exists uq_platform_server_active_account
  on public.platform_server_assignments(account_id)
  where released_at is null;
create unique index if not exists uq_platform_server_active_server
  on public.platform_server_assignments(server_id)
  where released_at is null;

insert into public.platform_warehouses(id, name, location, status)
values
  ('00000000-0000-0000-0000-000000000101', 'North Warehouse', 'Primary region', 'online'),
  ('00000000-0000-0000-0000-000000000102', 'South Warehouse', 'Secondary region', 'online')
on conflict (id) do nothing;

-- Seed the demo inventory only when the server catalog is empty. Replace these
-- demo rows with real infrastructure records before production use.
do $$
begin
  if not exists (select 1 from public.platform_servers limit 1) then
    insert into public.platform_servers(
      warehouse_id, name, status, storage_total_bytes, storage_used_bytes,
      ram_gb, cpu_cores, ssh_enabled, endpoint
    )
    select
      case when n <= 25
        then '00000000-0000-0000-0000-000000000101'::uuid
        else '00000000-0000-0000-0000-000000000102'::uuid
      end,
      'Server ' || lpad(case when n <= 25 then n::text else (n - 25)::text end, 2, '0'),
      'available',
      case when mod(n, 2) = 0 then 40 else 30 end * 1024::bigint * 1024 * 1024 * 1024 * 1024,
      (case when mod(n, 2) = 0 then 7 else 5 end + mod(n, 5))
        * 1024::bigint * 1024 * 1024 * 1024 * 1024 / 10,
      case when mod(n, 2) = 0 then 128 else 96 end,
      case when mod(n, 2) = 0 then 32 else 24 end,
      true,
      'server-' || n || '.local'
    from generate_series(1, 50) as series(n);
  end if;
end $$;

commit;
