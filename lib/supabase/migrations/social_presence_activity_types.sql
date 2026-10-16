-- Expand account-profile presence labels beyond media playback.
-- Replace the existing activity_type check without disturbing availability checks.
DO $$
DECLARE
  existing_constraint text;
BEGIN
  FOR existing_constraint IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.social_profile_presence'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%activity_type%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.social_profile_presence DROP CONSTRAINT %I',
      existing_constraint
    );
  END LOOP;

  ALTER TABLE public.social_profile_presence
    ADD CONSTRAINT social_profile_presence_activity_type_allowed_check
    CHECK (
      activity_type IS NULL OR activity_type IN (
        'watching', 'listening', 'shopping', 'ordering_food', 'planning_marathon'
      )
    );
END $$;
