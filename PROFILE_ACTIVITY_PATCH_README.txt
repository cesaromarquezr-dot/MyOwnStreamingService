MyOwnStreamingService account profile activity + account chats patch

Extract this archive over your existing MyOwnStreamingService project folder.
This patch contains only changed and newly created files.
Apply Backend/database/social_presence_activity_types.sql after the existing social chat/presence schema is installed, or run the matching lib/supabase/migrations/social_presence_activity_types.sql in your migration workflow.
Then restart/redeploy the backend as appropriate and run flutter analyze in the project root.

Flutter/Dart SDK analysis and tests were not run in the packaging environment. The SQL migration has not been applied to the live Supabase project.
