# ARM + Ratings implementation change log

## Modified

- `Backend/arm/arm_service.dart` — reads configured drive paths from the backend environment and continues inferring active physical drives from ARM jobs.
- `Backend/arm/arm_client.dart` — added backend-only ARM Basic authentication and stricter connection handling so HTTP 401/403 is not reported as a healthy ARM connection.
- `Backend/server.dart` — supplies ARM credentials from environment variables and registers rating routes/service.
- `Backend/database/database.dart` — adds the in-memory profile-rating store and restores profile ratings from Supabase when persistence is enabled.
- `Backend/supabase_store.dart` — persists/loads profile ratings and provider rating snapshots.
- `Backend/services/rating_service.dart` — provider adapter/caching logic, TMDB integration, MusicBrainz rating integration, configurable licensed IMDb/Rotten Tomatoes adapters, and profile ratings.
- `Backend/routes/rating_routes.dart` — authenticated rating retrieval and profile-rating endpoints.
- `Backend/routes/arm_routes.dart` — existing ARM API remains the authenticated boundary for drive/job monitoring.
- `lib/backend_api.dart` — rating API methods.
- `lib/app_core.dart` — MediaItem now carries separate external rating records and personal star rating state.
- `lib/music.dart` — MusicTrack now carries separate external rating records and personal star rating state.
- `lib/details.dart` — adds the Ratings section to media details and displays provider/personal ratings.
- `lib/main.dart` — Rip/Import now continuously polls ARM drive status and automatically attaches a local monitor when ARM reports a disc/job on a physical drive; all discovered drives are displayed.
- `Backend/README.md` — ARM/rating configuration documentation.
- `Backend/database/README.md` — rating persistence migration documentation.
- `IMPLEMENTATION_NOTES.md` — architecture notes.

## Created

- `Backend/models/rating.dart` — provider/kind/external/profile rating domain models.
- `Backend/services/rating_service.dart` — rating provider and cache service.
- `Backend/routes/rating_routes.dart` — rating API endpoints.
- `Backend/database/ratings_migration.sql` — durable rating tables/indexes.
- `lib/supabase/migrations/ratings_migration.sql` — Supabase migration copy.
- `lib/rating_system.dart` — Flutter ratings panel and personal star-rating dialog.
- `ARM_AND_RATINGS_CHANGELOG.md` — this implementation manifest.

## Notes

- No provider API keys are embedded in Flutter.
- IMDb and Rotten Tomatoes are optional because production/commercial access depends on their licensing/API arrangements.
- ARM does not receive a fabricated `start rip` command; disc insertion remains ARM's normal udev-triggered workflow.
