-- Cross-server infrastructure, TV device pairing, game ratings, and daily-game foundations.
-- This migration intentionally does not alter the legacy `servers` table, whose current
-- design is one home server per account. The new platform_servers layer supports a
-- warehouse with many claimable servers.

create extension if not exists pgcrypto;

create table if not exists platform_warehouses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  status text not null default 'online',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists platform_servers (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references platform_warehouses(id) on delete cascade,
  name text not null,
  status text not null default 'available',
  storage_total_bytes bigint not null default 0,
  storage_used_bytes bigint not null default 0,
  ram_gb integer not null default 0,
  cpu_cores integer not null default 0,
  ssh_enabled boolean not null default false,
  endpoint text,
  claimed_account_id uuid references accounts(id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_platform_servers_available
  on platform_servers(status, claimed_account_id);
create index if not exists idx_platform_servers_warehouse
  on platform_servers(warehouse_id);

create table if not exists platform_server_assignments (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  server_id uuid not null references platform_servers(id) on delete cascade,
  display_name text not null,
  role text not null default 'owner',
  assigned_at timestamptz not null default now(),
  released_at timestamptz
);

create unique index if not exists uq_platform_server_active_account
  on platform_server_assignments(account_id)
  where released_at is null;
create unique index if not exists uq_platform_server_active_server
  on platform_server_assignments(server_id)
  where released_at is null;

create table if not exists tv_pairings (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  tv_device_id text not null,
  tv_device_name text not null,
  pairing_code_hash text not null,
  status text not null default 'pending',
  phone_device_id text,
  phone_profile_id text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  paired_at timestamptz
);

create index if not exists idx_tv_pairings_code on tv_pairings(pairing_code_hash);
create index if not exists idx_tv_pairings_account on tv_pairings(account_id, status);

create table if not exists game_ratings (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id text not null,
  game_id text not null,
  mode text not null default 'ranked',
  rating numeric not null default 500,
  games_played integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  draws integer not null default 0,
  xp integer not null default 0,
  current_streak integer not null default 0,
  best_streak integer not null default 0,
  updated_at timestamptz not null default now(),
  unique(account_id, profile_id, game_id, mode)
);

create table if not exists game_matches (
  id uuid primary key default gen_random_uuid(),
  game_id text not null,
  mode text not null,
  status text not null default 'created',
  winner_profile_id text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists game_match_players (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references game_matches(id) on delete cascade,
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id text not null,
  rating_before numeric not null default 500,
  rating_after numeric,
  result text,
  placement integer,
  unique(match_id, profile_id)
);

create table if not exists game_daily_challenges (
  id uuid primary key default gen_random_uuid(),
  game_id text not null,
  challenge_date date not null,
  difficulty text,
  puzzle_seed text not null,
  created_at timestamptz not null default now(),
  unique(game_id, challenge_date)
);

-- Development/demo inventory: two warehouses with 25 servers each. Replace these
-- inventory rows with real hardware records in production.
do $$
declare
  north_id uuid := '00000000-0000-0000-0000-000000000101';
  south_id uuid := '00000000-0000-0000-0000-000000000102';
begin
  insert into platform_warehouses(id, name, location, status)
    values
      (north_id, 'North Warehouse', 'Primary region', 'online'),
      (south_id, 'South Warehouse', 'Secondary region', 'online')
  on conflict (id) do nothing;

  if not exists (select 1 from platform_servers limit 1) then
    insert into platform_servers(
      warehouse_id, name, status, storage_total_bytes, storage_used_bytes,
      ram_gb, cpu_cores, ssh_enabled, endpoint
    )
    select
      case when n <= 25 then north_id else south_id end,
      'Server ' || lpad(case when n <= 25 then n::text else (n - 25)::text end, 2, '0'),
      'available',
      case when mod(n, 2) = 0 then 40 else 30 end * 1024::bigint * 1024 * 1024 * 1024 * 1024,
      (case when mod(n, 2) = 0 then 7 else 5 end + mod(n, 5)) * 1024::bigint * 1024 * 1024 * 1024 * 1024 / 10,
      case when mod(n, 2) = 0 then 128 else 96 end,
      case when mod(n, 2) = 0 then 32 else 24 end,
      true,
      'server-' || n || '.local'
    from generate_series(1, 50) as series(n);
  end if;
end $$;
