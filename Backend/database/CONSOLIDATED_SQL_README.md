# Consolidated backend SQL bundles

The Backend/database folder has been reduced by grouping feature setup scripts into three bundles:

- `consolidated_platform.sql` — core product/platform, TV/device, discovery, studio, telemetry, and privacy foundations.
- `consolidated_social.sql` — social identity, profiles, posts, stories, chat, presence, invites, and household controls.
- `consolidated_commerce.sql` — shop and food delivery schema.
- `remove_sports_feature.sql` remains separate because it drops tables with `CASCADE`; it is a deliberate cleanup migration, not a normal fresh-install step.

Each bundle preserves the full text of its component scripts and labels each original section. The component order is listed at the top of each section. The bundles are convenience scripts, not a substitute for checking the target database state. Test on staging, review dependency comments, and back up production first. Some original scripts explicitly depend on migrations not included in `Backend/database`; apply the project's ordered `lib/supabase/migrations/` as appropriate.

**Migration history is intentionally preserved:** files under `lib/supabase/migrations/` have not been merged, renamed, or deleted because deployment tools may track those exact filenames and execution order.
