-- Collection-specific lookup indexes. Requires media_experience.sql first.
create index if not exists owned_experience_collections_updated_idx
  on public.owned_experience_records (account_id, profile_id, updated_at desc)
  where record_type = 'collection';

create index if not exists owned_experience_collections_title_idx
  on public.owned_experience_records (account_id, profile_id, lower(data->>'title'))
  where record_type = 'collection';

comment on index public.owned_experience_collections_updated_idx is
  'Speeds up listing a profile’s saved physical editions, box sets, TV-special groups, and playlists.';
