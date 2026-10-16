-- Restaurant profiles, opening-hour summaries, contact methods, customer reviews,
-- and themed watch-party menus for MyOwnStreamingService Food & Delivery.
-- Run after food_delivery.sql and food_messaging.sql.

alter table public.food_restaurants
  add column if not exists opening_hours text not null default 'Hours not provided',
  add column if not exists business_hours jsonb not null default '{}'::jsonb,
  add column if not exists contact_methods text[] not null default array['call']::text[],
  add column if not exists contact_email text,
  add column if not exists whatsapp_number text,
  add column if not exists imessage_address text,
  add column if not exists sms_number text,
  add column if not exists website text,
  add column if not exists is_24_7 boolean not null default false;

alter table public.food_restaurants
  drop constraint if exists food_restaurants_rating_range_check;
alter table public.food_restaurants
  add constraint food_restaurants_rating_range_check check (rating between 0 and 5);

alter table public.food_menu_items
  add column if not exists theme_keys text[] not null default '{}';
create index if not exists idx_food_menu_items_theme_keys
  on public.food_menu_items using gin(theme_keys);

create table if not exists public.food_restaurant_reviews (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.food_restaurants(id) on delete cascade,
  account_external_id text not null,
  reviewer_display_name text not null default 'Customer',
  rating smallint not null check (rating between 1 and 5),
  title text not null default '' check (char_length(title) <= 120),
  body text not null default '' check (char_length(body) <= 2000),
  verified_order boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (restaurant_id, account_external_id)
);
create index if not exists idx_food_restaurant_reviews_recent
  on public.food_restaurant_reviews(restaurant_id, created_at desc);
create index if not exists idx_food_restaurant_reviews_rating
  on public.food_restaurant_reviews(restaurant_id, rating);

create or replace function public.refresh_food_restaurant_review_summary()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_restaurant_id uuid;
begin
  if tg_op = 'DELETE' then
    target_restaurant_id := old.restaurant_id;
  else
    target_restaurant_id := new.restaurant_id;
  end if;

  update public.food_restaurants r
  set rating = coalesce((
        select round(avg(rv.rating)::numeric, 2)
        from public.food_restaurant_reviews rv
        where rv.restaurant_id = target_restaurant_id
      ), 0),
      review_count = (
        select count(*)::integer
        from public.food_restaurant_reviews rv
        where rv.restaurant_id = target_restaurant_id
      ),
      updated_at = now()
  where r.id = target_restaurant_id;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_food_restaurant_reviews_summary on public.food_restaurant_reviews;
create trigger trg_food_restaurant_reviews_summary
after insert or update or delete on public.food_restaurant_reviews
for each row execute function public.refresh_food_restaurant_review_summary();

create table if not exists public.food_menu_themes (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.food_restaurants(id) on delete cascade,
  theme_key text not null check (theme_key ~ '^[a-z0-9_-]{2,64}$'),
  name text not null check (char_length(name) between 2 and 120),
  description text not null default '' check (char_length(description) <= 1200),
  inspiration text not null default '',
  disclosure text not null default 'Fan-inspired menu concept; not an official or affiliated offering unless expressly licensed.',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (restaurant_id, theme_key)
);
create index if not exists idx_food_menu_themes_restaurant
  on public.food_menu_themes(restaurant_id, active, created_at desc);

create table if not exists public.food_menu_theme_items (
  theme_id uuid not null references public.food_menu_themes(id) on delete cascade,
  menu_item_id uuid not null references public.food_menu_items(id) on delete cascade,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (theme_id, menu_item_id)
);
create index if not exists idx_food_menu_theme_items_order
  on public.food_menu_theme_items(theme_id, display_order);

-- These tables are accessed only through the authenticated API using the server's
-- service-role connection; never expose the service-role key to Flutter.
alter table public.food_restaurant_reviews enable row level security;
alter table public.food_menu_themes enable row level security;
alter table public.food_menu_theme_items enable row level security;
revoke all on public.food_restaurant_reviews from anon, authenticated;
revoke all on public.food_menu_themes from anon, authenticated;
revoke all on public.food_menu_theme_items from anon, authenticated;
grant all on public.food_restaurant_reviews to service_role;
grant all on public.food_menu_themes to service_role;
grant all on public.food_menu_theme_items to service_role;
