-- FILE: lib/supabase/migrations/20260918_shop_marketplace.sql
--
-- Purpose:
-- Adds the marketplace/store foundation for Shop, including:
-- - Stores
-- - Products
-- - Product images and variants
-- - Media associations
-- - Featured products
-- - Account wishlists
-- - Shopping carts
-- - Orders and order items
-- - Tokenized payment methods
--
-- Architecture:
-- Shop metadata is persisted in Supabase. Physical media files, including
-- entertainment files and product assets that are not intentionally hosted
-- through a public URL, remain outside this database.
--
-- Security:
-- - Raw card numbers (PAN) and CVV/security codes are NEVER stored here.
-- - payment_provider_token must be an opaque token issued by the PCI-compliant
--   payment provider after tokenization.
-- - Only display-safe payment summaries such as brand, last4, and expiration
--   may be retained.
-- - Actual payment authorization and charging must be performed by the
--   authenticated backend through the payment provider.
-- - Supabase service-role access is backend-only and must never be exposed
--   to the Flutter client.
--
-- RLS:
-- All Shop tables have RLS enabled. Production client policies should be
-- introduced only after the application's authenticated account/profile
-- mapping is finalized. Backend service-role operations may administer the
-- marketplace while bypassing RLS.

-- ============================================================================
-- Stores
-- ============================================================================

create table if not exists public.shop_stores (
  id uuid primary key default gen_random_uuid(),
  owner_account_id uuid not null
    references public.accounts(id)
    on delete cascade,
  name text not null,
  description text not null default '',
  logo_url text,
  banner_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- Products
-- ============================================================================

create table if not exists public.shop_products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null
    references public.shop_stores(id)
    on delete cascade,
  name text not null,
  description text not null default '',
  product_type text not null default 'Merchandise',
  category text not null default 'Other',
  price numeric(12, 2) not null check (price >= 0),
  currency text not null default 'USD',
  inventory_quantity integer not null default 0
    check (inventory_quantity >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- Product images
-- ============================================================================

create table if not exists public.shop_product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null
    references public.shop_products(id)
    on delete cascade,
  image_url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- Product variants
-- ============================================================================

create table if not exists public.shop_product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null
    references public.shop_products(id)
    on delete cascade,
  name text not null,
  sku text,
  price_override numeric(12, 2)
    check (price_override >= 0),
  inventory_quantity integer not null default 0
    check (inventory_quantity >= 0),
  option_values jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- Product/media relationships
-- ============================================================================

-- A product may be associated with multiple entertainment entities.
--
-- association_type examples:
-- - movie
-- - show
-- - franchise
-- - song
-- - artist
-- - album
-- - playlist
-- - collection
--
-- media_id is intentionally text because the associated media may originate
-- from the application's broader media-universe/external-ID system.

create table if not exists public.shop_product_media (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null
    references public.shop_products(id)
    on delete cascade,
  association_type text not null,
  media_id text not null,
  media_name text not null,
  created_at timestamptz not null default now(),
  unique (product_id, association_type, media_id)
);

-- ============================================================================
-- Featured products
-- ============================================================================

create table if not exists public.shop_store_featured_products (
  store_id uuid not null
    references public.shop_stores(id)
    on delete cascade,
  product_id uuid not null
    references public.shop_products(id)
    on delete cascade,
  sort_order integer not null default 0,
  primary key (store_id, product_id)
);

-- ============================================================================
-- Wishlists
-- ============================================================================

create table if not exists public.shop_wishlists (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null
    references public.accounts(id)
    on delete cascade,
  created_at timestamptz not null default now(),
  unique (account_id)
);

create table if not exists public.shop_wishlist_items (
  wishlist_id uuid not null
    references public.shop_wishlists(id)
    on delete cascade,
  product_id uuid not null
    references public.shop_products(id)
    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (wishlist_id, product_id)
);

-- ============================================================================
-- Shopping carts
-- ============================================================================

create table if not exists public.shop_carts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null
    references public.accounts(id)
    on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'checked_out', 'abandoned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null
    references public.shop_carts(id)
    on delete cascade,
  product_id uuid not null
    references public.shop_products(id)
    on delete cascade,
  variant_id uuid
    references public.shop_product_variants(id)
    on delete set null,
  quantity integer not null
    check (quantity > 0),
  created_at timestamptz not null default now(),
  unique (cart_id, product_id, variant_id)
);

-- ============================================================================
-- Orders
-- ============================================================================

-- A single marketplace checkout may contain products from multiple stores.

create table if not exists public.shop_orders (
  id uuid primary key default gen_random_uuid(),
  buyer_account_id uuid not null
    references public.accounts(id)
    on delete restrict,
  status text not null default 'paid'
    check (
      status in (
        'pending',
        'paid',
        'processing',
        'shipped',
        'completed',
        'cancelled',
        'refunded'
      )
    ),
  currency text not null default 'USD',
  subtotal numeric(12, 2) not null
    check (subtotal >= 0),
  shipping_total numeric(12, 2) not null default 0
    check (shipping_total >= 0),
  tax_total numeric(12, 2) not null default 0
    check (tax_total >= 0),
  total numeric(12, 2) not null
    check (total >= 0),
  payment_transaction_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null
    references public.shop_orders(id)
    on delete cascade,
  store_id uuid not null
    references public.shop_stores(id)
    on delete restrict,
  product_id uuid not null
    references public.shop_products(id)
    on delete restrict,
  variant_id uuid
    references public.shop_product_variants(id)
    on delete set null,
  product_name_snapshot text not null,
  quantity integer not null
    check (quantity > 0),
  unit_price numeric(12, 2) not null
    check (unit_price >= 0),
  created_at timestamptz not null default now()
);

-- ============================================================================
-- Payment methods
-- ============================================================================

-- This table stores only provider-issued tokens and display-safe summaries.
--
-- NEVER store:
-- - Full card number / PAN
-- - CVV / CVC / security code
-- - Magnetic-stripe data
-- - Other raw payment credentials
--
-- payment_provider_token must be an opaque provider token that is safe for
-- the backend to use according to the selected payment provider's tokenization
-- model.

create table if not exists public.shop_payment_methods (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null
    references public.accounts(id)
    on delete cascade,
  provider text not null,
  payment_provider_token text not null,
  brand text,
  last4 text
    check (last4 is null or length(last4) = 4),
  exp_month integer
    check (exp_month between 1 and 12),
  exp_year integer,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- Indexes
-- ============================================================================

create index if not exists idx_shop_stores_owner
  on public.shop_stores(owner_account_id);

create index if not exists idx_shop_stores_active
  on public.shop_stores(is_active);

create index if not exists idx_shop_products_store
  on public.shop_products(store_id);

create index if not exists idx_shop_products_active
  on public.shop_products(is_active);

create index if not exists idx_shop_products_featured
  on public.shop_products(is_featured)
  where is_featured = true;

create index if not exists idx_shop_product_images_product
  on public.shop_product_images(product_id, sort_order);

create index if not exists idx_shop_product_variants_product
  on public.shop_product_variants(product_id);

create index if not exists idx_shop_product_media_lookup
  on public.shop_product_media(association_type, media_id);

create index if not exists idx_shop_store_featured_products_store
  on public.shop_store_featured_products(store_id, sort_order);

create index if not exists idx_shop_wishlist_items_product
  on public.shop_wishlist_items(product_id);

create index if not exists idx_shop_carts_account
  on public.shop_carts(account_id);

create index if not exists idx_shop_carts_active
  on public.shop_carts(account_id, status)
  where status = 'active';

create index if not exists idx_shop_cart_items_cart
  on public.shop_cart_items(cart_id);

create index if not exists idx_shop_cart_items_product
  on public.shop_cart_items(product_id);

create index if not exists idx_shop_orders_buyer
  on public.shop_orders(buyer_account_id);

create index if not exists idx_shop_orders_status
  on public.shop_orders(status);

create index if not exists idx_shop_order_items_order
  on public.shop_order_items(order_id);

create index if not exists idx_shop_order_items_store
  on public.shop_order_items(store_id);

create index if not exists idx_shop_order_items_product
  on public.shop_order_items(product_id);

create index if not exists idx_shop_payment_methods_account
  on public.shop_payment_methods(account_id);

-- ============================================================================
-- Updated-at trigger
-- ============================================================================

create or replace function public.set_shop_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists shop_stores_set_updated_at
  on public.shop_stores;

create trigger shop_stores_set_updated_at
before update on public.shop_stores
for each row
execute function public.set_shop_updated_at();

drop trigger if exists shop_products_set_updated_at
  on public.shop_products;

create trigger shop_products_set_updated_at
before update on public.shop_products
for each row
execute function public.set_shop_updated_at();

drop trigger if exists shop_product_variants_set_updated_at
  on public.shop_product_variants;

create trigger shop_product_variants_set_updated_at
before update on public.shop_product_variants
for each row
execute function public.set_shop_updated_at();

drop trigger if exists shop_carts_set_updated_at
  on public.shop_carts;

create trigger shop_carts_set_updated_at
before update on public.shop_carts
for each row
execute function public.set_shop_updated_at();

drop trigger if exists shop_orders_set_updated_at
  on public.shop_orders;

create trigger shop_orders_set_updated_at
before update on public.shop_orders
for each row
execute function public.set_shop_updated_at();

drop trigger if exists shop_payment_methods_set_updated_at
  on public.shop_payment_methods;

create trigger shop_payment_methods_set_updated_at
before update on public.shop_payment_methods
for each row
execute function public.set_shop_updated_at();

-- ============================================================================
-- Row-level security
-- ============================================================================

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

-- No client-side policies are created in this foundation migration.
--
-- The application's authenticated Dart backend is responsible for protected
-- marketplace operations. Production client policies may be added later once
-- the account/authentication mapping is finalized.

-- ============================================================================
-- Documentation comments
-- ============================================================================

comment on table public.shop_stores is
  'Marketplace stores owned by application accounts.';

comment on table public.shop_products is
  'Marketplace products offered by Shop stores.';

comment on table public.shop_product_images is
  'Display images associated with Shop products.';

comment on table public.shop_product_variants is
  'Optional product variants with independent inventory and pricing overrides.';

comment on table public.shop_product_media is
  'Associates Shop products with entertainment/media entities using application media identifiers.';

comment on table public.shop_store_featured_products is
  'Explicit store-level featured product ordering.';

comment on table public.shop_wishlists is
  'One Shop wishlist per account.';

comment on table public.shop_wishlist_items is
  'Products saved to an account wishlist.';

comment on table public.shop_carts is
  'Account shopping carts and their checkout lifecycle state.';

comment on table public.shop_cart_items is
  'Products and optional variants currently associated with a shopping cart.';

comment on table public.shop_orders is
  'Marketplace checkout records. A single order may contain products from multiple stores.';

comment on table public.shop_order_items is
  'Immutable-enough order-line snapshot data used to preserve product pricing/name at checkout.';

comment on table public.shop_payment_methods is
  'Only PCI-compliant provider tokens and display-safe payment summaries are stored; raw PAN and CVV must never be stored.';

comment on column public.shop_payment_methods.payment_provider_token is
  'Opaque token issued by the PCI-compliant payment provider after tokenization. Never store raw card credentials here.';

comment on column public.shop_payment_methods.last4 is
  'Display-safe last four digits supplied by the payment provider. Never use this field to store a full card number.';

comment on column public.shop_payment_methods.brand is
  'Display-safe card brand supplied by the payment provider.';

comment on column public.shop_payment_methods.exp_month is
  'Display-safe expiration month supplied by the payment provider.';

comment on column public.shop_payment_methods.exp_year is
  'Display-safe expiration year supplied by the payment provider.';

comment on column public.shop_orders.payment_transaction_id is
  'Provider transaction/reference identifier. Raw payment credentials must never be stored here.';

-- ============================================================================
-- Function security
-- ============================================================================

comment on function public.set_shop_updated_at() is
  'Maintains updated_at timestamps for Shop tables with mutable records.';