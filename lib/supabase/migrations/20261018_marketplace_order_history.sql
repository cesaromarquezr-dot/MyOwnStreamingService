-- Profile-scoped lookup for the shared marketplace order history.
-- API handlers always constrain reads by authenticated account and profile.
create index if not exists idx_food_orders_account_profile_created
  on public.food_orders(account_id, profile_id, created_at desc);

comment on index public.idx_food_orders_account_profile_created is
  'Supports account- and profile-scoped recent food-order listing for Marketplace history.';
