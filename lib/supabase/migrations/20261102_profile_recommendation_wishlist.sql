alter table public.profiles
  add column if not exists wishlist_recommendation_ids jsonb not null default '[]'::jsonb;

comment on column public.profiles.wishlist_recommendation_ids is
  'Recommendation IDs saved to this profile wishlist after household votes.';
