-- Private at-home theater session indexes. Requires media_experience.sql first.
create index if not exists owned_experience_theater_recent_idx
  on public.owned_experience_records (account_id, profile_id, updated_at desc)
  where record_type = 'theater_session';

comment on index public.owned_experience_theater_recent_idx is
  'Speeds up private home-theater session history. Sessions never represent paid admission or ticket sales.';
