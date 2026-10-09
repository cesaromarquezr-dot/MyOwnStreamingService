-- Native restaurant/food-delivery domain for MyOwnStreamingService.
-- No card numbers, CVVs, or other raw payment credentials are stored here.
-- Payment authorization is represented by a server-owned payment method ID.

create extension if not exists pgcrypto;

create table if not exists food_restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cuisine text not null,
  description text not null default '',
  phone text not null default '',
  address text not null default '',
  city text not null default '',
  state_region text not null default '',
  postal_code text not null default '',
  country_code char(2) not null default '',
  latitude double precision not null,
  longitude double precision not null,
  rating numeric(3,2) not null default 0,
  review_count integer not null default 0,
  delivery_fee_cents integer not null default 0 check (delivery_fee_cents >= 0),
  service_fee_cents integer not null default 199 check (service_fee_cents >= 0),
  tax_rate_basis_points integer not null default 0 check (tax_rate_basis_points between 0 and 30000),
  allows_delivery boolean not null default true,
  allows_pickup boolean not null default true,
  loyalty_points_per_currency integer not null default 1 check (loyalty_points_per_currency >= 0),
  currency_code char(3) not null default 'USD',
  minimum_order_cents integer not null default 0 check (minimum_order_cents >= 0),
  eta_min_minutes integer not null default 30,
  eta_max_minutes integer not null default 45,
  is_open boolean not null default true,
  hero_image_url text,
  tags text[] not null default '{}',
  source text not null default 'merchant',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_food_restaurants_geo
  on food_restaurants(latitude, longitude);
create index if not exists idx_food_restaurants_open
  on food_restaurants(is_open);

create table if not exists food_menu_items (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references food_restaurants(id) on delete cascade,
  category text not null default 'Menu',
  name text not null,
  description text not null default '',
  price_cents integer not null check (price_cents >= 0),
  image_url text,
  available boolean not null default true,
  tags text[] not null default '{}',
  modifier_groups jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_food_menu_restaurant
  on food_menu_items(restaurant_id, available);
create index if not exists idx_food_menu_name
  on food_menu_items using gin (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(description, '')));

create table if not exists food_orders (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id text not null,
  restaurant_id uuid not null references food_restaurants(id),
  status text not null default 'placed',
  payment_method_id text not null,
  payment_status text not null default 'pending',
  subtotal_cents integer not null default 0,
  delivery_fee_cents integer not null default 0,
  tax_cents integer not null default 0 check (tax_cents >= 0),
  service_fee_cents integer not null default 0 check (service_fee_cents >= 0),
  discount_cents integer not null default 0 check (discount_cents >= 0),
  coupon_code text,
  fulfillment_method text not null default 'delivery' check (fulfillment_method in ('delivery','pickup')),
  points_earned integer not null default 0 check (points_earned >= 0),
  total_cents integer not null default 0,
  currency_code char(3) not null default 'USD',
  delivery_address jsonb not null default '{}'::jsonb,
  delivery_notes text not null default '',
  viewing_context text,
  estimated_delivery_at timestamptz,
  placed_at timestamptz not null default now(),
  confirmed_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_food_orders_account
  on food_orders(account_id, created_at desc);
create index if not exists idx_food_orders_status
  on food_orders(status, updated_at desc);

create table if not exists food_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references food_orders(id) on delete cascade,
  menu_item_id uuid not null references food_menu_items(id),
  item_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  modifiers jsonb not null default '[]'::jsonb,
  line_total_cents integer not null check (line_total_cents >= 0)
);

create index if not exists idx_food_order_items_order
  on food_order_items(order_id);

create table if not exists food_order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references food_orders(id) on delete cascade,
  status text not null,
  message text not null default '',
  event_at timestamptz not null default now()
);

create index if not exists idx_food_order_events_order
  on food_order_events(order_id, event_at asc);

-- Optional PostGIS migration for production-scale radius searches.
-- Enable this separately when PostGIS is available in the Supabase project:
-- create extension if not exists postgis;
-- alter table food_restaurants add column if not exists location geography(point, 4326);
-- update food_restaurants set location = st_setsrid(st_makepoint(longitude, latitude), 4326) where location is null;
-- create index if not exists idx_food_restaurants_location on food_restaurants using gist(location);


-- Independent restaurant ownership: ownership is associated with the buyer account,
-- not with that account's streaming-server assignment. Different accounts can list
-- separate restaurants in the same city.
create table if not exists food_restaurant_owners (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references food_restaurants(id) on delete cascade,
  account_external_id text not null,
  role text not null default 'owner' check (role in ('owner','manager','staff')),
  created_at timestamptz not null default now(),
  unique (restaurant_id, account_external_id)
);
create index if not exists idx_food_restaurant_owners_account
  on food_restaurant_owners(account_external_id, created_at desc);

create table if not exists food_restaurant_coupons (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references food_restaurants(id) on delete cascade,
  coupon_code text not null,
  description text not null default '',
  discount_percent integer not null check (discount_percent between 1 and 100),
  minimum_subtotal_cents integer not null default 0 check (minimum_subtotal_cents >= 0),
  max_redemptions integer,
  redemption_count integer not null default 0,
  starts_at timestamptz,
  expires_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (restaurant_id, coupon_code)
);
create index if not exists idx_food_coupons_active
  on food_restaurant_coupons(restaurant_id, active, coupon_code);

create table if not exists food_loyalty_ledger (
  id uuid primary key default gen_random_uuid(),
  account_external_id text not null,
  restaurant_id uuid not null references food_restaurants(id) on delete cascade,
  order_id uuid references food_orders(id) on delete set null,
  points_delta integer not null,
  reason text not null default 'order_reward',
  created_at timestamptz not null default now()
);
create index if not exists idx_food_loyalty_account_restaurant
  on food_loyalty_ledger(account_external_id, restaurant_id, created_at desc);

-- Upgrade older installations without requiring the original tables to be recreated.
alter table food_restaurants add column if not exists description text not null default '';
alter table food_restaurants add column if not exists phone text not null default '';
alter table food_restaurants add column if not exists city text not null default '';
alter table food_restaurants add column if not exists state_region text not null default '';
alter table food_restaurants add column if not exists postal_code text not null default '';
alter table food_restaurants add column if not exists country_code char(2) not null default '';
alter table food_restaurants add column if not exists service_fee_cents integer not null default 199;
alter table food_restaurants add column if not exists tax_rate_basis_points integer not null default 0;
alter table food_restaurants add column if not exists allows_delivery boolean not null default true;
alter table food_restaurants add column if not exists allows_pickup boolean not null default true;
alter table food_restaurants add column if not exists loyalty_points_per_currency integer not null default 1;
alter table food_orders add column if not exists tax_cents integer not null default 0;
alter table food_orders add column if not exists service_fee_cents integer not null default 0;
alter table food_orders add column if not exists discount_cents integer not null default 0;
alter table food_orders add column if not exists coupon_code text;
alter table food_orders add column if not exists fulfillment_method text not null default 'delivery';
alter table food_orders add column if not exists points_earned integer not null default 0;


-- Public read access is appropriate for restaurant/menu photos; uploads are made
-- server-side through the authenticated merchant API using the service-role key.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'food-restaurant-images',
  'food-restaurant-images',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
