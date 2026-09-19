-- FILE: lib/supabase/migrations/20260918_shop_shipping.sql
-- Purpose: Adds seller shipping-carrier configuration and buyer delivery
-- address data for marketplace checkout.
--
-- Production note: the Flutter development checkout currently uses a
-- deterministic estimator. Live carrier APIs should calculate the final rate
-- from verified package weight/dimensions, seller origin, destination,
-- service level, and the carrier account selected by the seller.

alter table public.shop_stores
  add column if not exists shipping_carriers text[] not null
    default array['usps','ups'],
  add column if not exists shipping_origin jsonb not null
    default '{"country":"","stateProvince":"","city":"","postalCode":"","address":""}'::jsonb;

alter table public.shop_orders
  add column if not exists shipping_address jsonb,
  add column if not exists shipping_carriers text[] not null default '{}';

comment on column public.shop_stores.shipping_carriers is
  'Carrier identifiers the seller permits for checkout; production quotes should come from connected carrier APIs.';

comment on column public.shop_stores.shipping_origin is
  'Seller shipping origin used to request delivery quotes.';

comment on column public.shop_orders.shipping_address is
  'Buyer delivery address required before marketplace purchase; protect this data with production RLS/access controls.';
