-- FILE: lib/supabase/migrations/20260918_shop_marketplace.sql
-- Purpose: Adds the marketplace/store, product, cart, wishlist, order, and
-- payment-method foundation for Shop.
--
-- Security:
-- - Raw card number and CVV are NEVER stored here.
-- - payment_provider_token is an opaque token returned by the PCI-compliant
--   payment provider after tokenization.
-- - Only provider brand/last4/expiration summary may be retained for display.
-- - Actual card charging must happen through the provider from the backend.

create table if not exists public.shop_stores (
  id uuid primary key default gen_random_uuid(),
  owner_account_id uuid not null references public.accounts(id) on delete cascade,
  name text not null,
  description text not null default '',
  logo_url text,
  banner_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.shop_stores(id) on delete cascade,
  name text not null,
  description text not null default '',
  product_type text not null default 'Merchandise',
  category text not null default 'Other',
  price numeric(12,2) not null check (price >= 0),
  currency text not null default 'USD',
  inventory_quantity integer not null default 0 check (inventory_quantity >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.shop_products(id) on delete cascade,
  image_url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.shop_product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.shop_products(id) on delete cascade,
  name text not null,
  sku text,
  price_override numeric(12,2) check (price_override >= 0),
  inventory_quantity integer not null default 0 check (inventory_quantity >= 0),
  option_values jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One product can point to many entertainment entities.
-- association_type examples: movie, show, franchise, song, artist, album,
-- playlist, collection.
create table if not exists public.shop_product_media (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.shop_products(id) on delete cascade,
  association_type text not null,
  media_id text not null,
  media_name text not null,
  created_at timestamptz not null default now(),
  unique(product_id, association_type, media_id)
);

create table if not exists public.shop_store_featured_products (
  store_id uuid not null references public.shop_stores(id) on delete cascade,
  product_id uuid not null references public.shop_products(id) on delete cascade,
  sort_order integer not null default 0,
  primary key(store_id, product_id)
);

create table if not exists public.shop_wishlists (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(account_id)
);

create table if not exists public.shop_wishlist_items (
  wishlist_id uuid not null references public.shop_wishlists(id) on delete cascade,
  product_id uuid not null references public.shop_products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(wishlist_id, product_id)
);

create table if not exists public.shop_carts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  status text not null default 'active' check (status in ('active','checked_out','abandoned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.shop_carts(id) on delete cascade,
  product_id uuid not null references public.shop_products(id) on delete cascade,
  variant_id uuid references public.shop_product_variants(id) on delete set null,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now(),
  unique(cart_id, product_id, variant_id)
);

-- A single marketplace checkout can contain products from multiple stores.
create table if not exists public.shop_orders (
  id uuid primary key default gen_random_uuid(),
  buyer_account_id uuid not null references public.accounts(id) on delete restrict,
  status text not null default 'paid' check (status in ('pending','paid','processing','shipped','completed','cancelled','refunded')),
  currency text not null default 'USD',
  subtotal numeric(12,2) not null check (subtotal >= 0),
  shipping_total numeric(12,2) not null default 0 check (shipping_total >= 0),
  tax_total numeric(12,2) not null default 0 check (tax_total >= 0),
  total numeric(12,2) not null check (total >= 0),
  payment_transaction_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.shop_orders(id) on delete cascade,
  store_id uuid not null references public.shop_stores(id) on delete restrict,
  product_id uuid not null references public.shop_products(id) on delete restrict,
  variant_id uuid references public.shop_product_variants(id) on delete set null,
  product_name_snapshot text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  created_at timestamptz not null default now()
);

-- This table stores only provider tokens and display-safe summaries.
create table if not exists public.shop_payment_methods (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  provider text not null,
  payment_provider_token text not null,
  brand text,
  last4 text check (last4 is null or length(last4) = 4),
  exp_month integer check (exp_month between 1 and 12),
  exp_year integer,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_shop_stores_owner on public.shop_stores(owner_account_id);
create index if not exists idx_shop_products_store on public.shop_products(store_id);
create index if not exists idx_shop_product_media_lookup on public.shop_product_media(association_type, media_id);
create index if not exists idx_shop_order_items_store on public.shop_order_items(store_id);
create index if not exists idx_shop_orders_buyer on public.shop_orders(buyer_account_id);
create index if not exists idx_shop_payment_methods_account on public.shop_payment_methods(account_id);

-- Enable RLS. Backend service-role operations can administer marketplace data;
-- client-side access must be narrowed further when the production auth mapping
-- is finalized.
alter table public.shop_stores enable row level security;
alter table public.shop_products enable row level security;
alter table public.shop_product_images enable row level security;
alter table public.shop_product_variants enable row level security;
alter table public.shop_product_media enable row level security;
alter table public.shop_store_featured_products enable row level security;
alter table public.shop_wishlists enable row level security;
alter table public.shop_wishlist_items enable row level security;
alter table public.shop_carts enable row level security;
alter table public.shop_cart_items enable row level security;
alter table public.shop_orders enable row level security;
alter table public.shop_order_items enable row level security;
alter table public.shop_payment_methods enable row level security;

comment on table public.shop_payment_methods is
  'Only PCI-compliant provider tokens and display-safe card summaries are stored; never store PAN/CVV.';
