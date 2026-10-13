-- Remove the retired live-sports data model from existing installations.
-- Safe to run repeatedly. Other media, profiles, playlists and account data stay intact.
drop table if exists public.profile_followed_teams cascade;
drop table if exists public.sports_broadcasts cascade;
drop table if exists public.sports_games cascade;
drop table if exists public.sports_teams cascade;

do $$
begin
  if to_regclass('public.media_events') is not null then
    alter table public.media_events drop constraint if exists media_events_event_type_check;
    alter table public.media_events
      add constraint media_events_event_type_check
      check (event_type in ('season','holiday','cultural','special','custom'));
  end if;
end $$;
