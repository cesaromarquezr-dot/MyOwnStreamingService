-- FILE: lib/supabase/migrations/20260918_shop_shipping.sql
--
-- Purpose:
-- Adds seller shipping-carrier configuration and buyer delivery-address
-- data for marketplace checkout.
--
-- Architecture:
-- Seller shipping configuration belongs to the Shop store.
-- Buyer delivery information belongs to the marketplace order so that the
-- order retains the destination associated with that checkout.
--
-- Production:
-- The Flutter development checkout may use a deterministic shipping
-- estimator. Production shipping rates must be calculated by the authenticated
-- backend through the appropriate carrier integration using verified:
-- - Package weight and dimensions
-- - Seller shipping origin
-- - Buyer destination
-- - Requested service level
-- - Seller/carrier account configuration
--
-- Security:
-- - shipping_address contains potentially sensitive buyer delivery data.
-- - Access must be restricted to the buyer and authorized marketplace/store
--   operations according to the application's production authorization model.
-- - Carrier credentials, API keys, OAuth secrets, and other provider
--   credentials must NEVER be stored in these columns.
-- - Carrier integrations and final rate calculations must be performed by
--   the authenticated backend, not by the Flutter client.
-- - Supabase service-role credentials must never be exposed to Flutter.

-- ============================================================================
-- Seller shipping configuration
-- ============================================================================

alter table public.shop_stores
  add column if not exists shipping_carriers text[] not null
    default array['usps', 'ups']::text[];

alter table public.shop_stores
  add column if not exists shipping_origin jsonb not null
    default '{
      "country": "",
      "stateProvince": "",
      "city": "",
      "postalCode": "",
      "address": ""
    }'::jsonb;

-- ============================================================================
-- Order shipping data
-- ============================================================================

alter table public.shop_orders
  add column if not exists shipping_address jsonb;

alter table public.shop_orders
  add column if not exists shipping_carriers text[] not null
    default '{}'::text[];

-- ============================================================================
-- Documentation comments
-- ============================================================================

comment on column public.shop_stores.shipping_carriers is
  'Carrier identifiers the seller permits for checkout. Production shipping quotes should come from connected carrier APIs.';

comment on column public.shop_stores.shipping_origin is
  'Seller shipping origin used by the backend when requesting delivery quotes.';

comment on column public.shop_orders.shipping_address is
  'Buyer delivery address captured for the marketplace order. Treat as sensitive data and restrict access through production RLS/backend authorization.';

comment on column public.shop_orders.shipping_carriers is
  'Carrier identifiers selected or permitted for the order checkout. Provider credentials are never stored here.';