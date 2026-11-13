-- Allow the same-account activity labels used by the Kiosk, Theater and
-- Listening Lounge. This migration is safe to re-run.
do $$
declare
  existing_constraint text;
begin
  for existing_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.social_profile_presence'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%activity_type%'
  loop
    execute format(
      'alter table public.social_profile_presence drop constraint %I',
      existing_constraint
    );
  end loop;

  alter table public.social_profile_presence
    add constraint social_profile_presence_activity_type_experience_check
    check (
      activity_type is null or activity_type in (
        'watching', 'listening', 'browsing', 'shopping',
        'ordering_food', 'planning_marathon'
      )
    );
end $$;
