-- OPTIONAL, DESTRUCTIVE CLEANUP: removes legacy Hey Media AI data.
-- Back up the database before running this file. This permanently deletes
-- saved assistant memories, proactive suggestions, and action audit rows.
-- This file is intentionally NOT run by the app or by consolidated migrations.

drop table if exists public.hey_media_action_audit;
drop table if exists public.user_hey_media_suggestions;
drop table if exists public.hey_media_memory_entries;
