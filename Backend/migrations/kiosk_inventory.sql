-- Private owned-library kiosk indexes. Requires media_experience.sql first.
create index if not exists owned_experience_kiosk_recent_idx
  on public.owned_experience_records (account_id, profile_id, updated_at desc)
  where record_type in ('kiosk_session', 'kiosk_favorite', 'kiosk_preferences');

comment on index public.owned_experience_kiosk_recent_idx is
  'Speeds up owner-only browsing preferences and kiosk playback sessions for already-owned media; no rental, return, checkout, or payment inventory.';
