create table if not exists public.shop_live_events (
  id uuid primary key default gen_random_uuid(),
  seller_account_id uuid not null references public.accounts(id) on delete cascade,
  seller_external_id text not null,
  store_id text not null,
  store_name text not null,
  title text not null,
  description text not null default '',
  status text not null default 'scheduled'
    check (status in ('scheduled', 'live', 'ended')),
  scheduled_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  stream_url text,
  replay_url text,
  product_ids text[] not null default '{}',
  pinned_product_id text,
  questions jsonb not null default '[]'::jsonb,
  poll jsonb,
  randomized_rewards_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (pinned_product_id is null or pinned_product_id = any(product_ids))
);

create index if not exists idx_shop_live_events_status_schedule
  on public.shop_live_events(status, scheduled_at);
create index if not exists idx_shop_live_events_seller
  on public.shop_live_events(seller_account_id, updated_at desc);

alter table public.shop_live_events enable row level security;

drop policy if exists shop_live_events_public_read on public.shop_live_events;
create policy shop_live_events_public_read on public.shop_live_events
  for select to authenticated using (true);

drop policy if exists shop_live_events_seller_write on public.shop_live_events;
create policy shop_live_events_seller_write on public.shop_live_events
  for all to authenticated
  using (seller_account_id in (
    select account_id from public.account_members
    where account_id = shop_live_events.seller_account_id
      and status = 'active'
      and role in ('owner', 'admin')
  ))
  with check (seller_account_id in (
    select account_id from public.account_members
    where account_id = shop_live_events.seller_account_id
      and status = 'active'
      and role in ('owner', 'admin')
  ));

comment on table public.shop_live_events is
  'Seller livestream schedules, stream/replay references, featured products, and moderated interaction state. Stream delivery itself is provided by a configured streaming provider.';
