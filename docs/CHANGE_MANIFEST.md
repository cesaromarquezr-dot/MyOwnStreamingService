# MyOwnStreamingService — change manifest

> This file lists all project file changes in the consolidated release snapshot. It compares `/mnt/data/MyOwnStreamingService_merged` against the available baseline archive extracted at `/mnt/data/work_mos/MyOwnStreamingService`. It cannot account for edits in a separate, unuploaded local working copy.

## Summary

- **Created:** 9 files
- **Modified:** 63 files
- **Deleted:** 9 files

The modified list includes the broad static-label localization migration (805 app-authored literal labels converted to `UniversalText`), media-metadata display localization updates, food delivery restaurant profile/review/theme integration, server/API/database and no-games cleanup, test/documentation updates, and project documentation.

## Created files

| File |
| `Backend/database/consolidated_commerce.sql` |
| `Backend/database/consolidated_platform.sql` |
| `docs/CHANGE_MANIFEST.md` |
| `docs/FEATURE_CONSOLIDATION_STATUS.md` |
| `docs/LOCALIZATION_SETUP.md` |
| `lib/media_text_localizer.dart` |
| `lib/supabase/migrations/food_restaurant_profiles_reviews_themes.sql` |
| `supabase/functions/translate-text/index.ts` |
| `test/food_restaurant_features_test.dart` |

## Modified files

| File |
| `Backend/arm/arm_models.dart` |
| `Backend/database/README.md` |
| `Backend/database/consolidated_commerce.sql` |
| `Backend/routes/food_delivery_routes.dart` |
| `Backend/server.dart` |
| `Backend/services/food_delivery_service.dart` |
| `Backend/supabase_store.dart` |
| `README.md` |
| `docs/END_TO_END_SERVER_DEVICE_TV.md` |
| `lib/activity_timeline.dart` |
| `lib/actor_connections.dart` |
| `lib/backend_api.dart` |
| `lib/details.dart` |
| `lib/details_recommendations.dart` |
| `lib/device_features.dart` |
| `lib/feature_center.dart` |
| `lib/film.dart` |
| `lib/food_delivery.dart` |
| `lib/hey_media.dart` |
| `lib/home_server.dart` |
| `lib/library_hubs.dart` |
| `lib/library_release.dart` |
| `lib/live_shopping.dart` |
| `lib/localization.dart` |
| `lib/main.dart` |
| `lib/media_action_rules.dart` |
| `lib/media_continuity.dart` |
| `lib/media_experience.dart` |
| `lib/media_universe.dart` |
| `lib/movies.dart` |
| `lib/music.dart` |
| `lib/my_tv.dart` |
| `lib/navigation_hubs.dart` |
| `lib/payment.dart` |
| `lib/people_timeline.dart` |
| `lib/player.dart` |
| `lib/profile_administration.dart` |
| `lib/profile_artwork.dart` |
| `lib/profile_content_safety.dart` |
| `lib/profiles.dart` |
| `lib/reviews.dart` |
| `lib/roadmap_features.dart` |
| `lib/seasonal_collections.dart` |
| `lib/security_settings.dart` |
| `lib/self_hosting_settings.dart` |
| `lib/series.dart` |
| `lib/server_selection.dart` |
| `lib/shop.dart` |
| `lib/shop_customization.dart` |
| `lib/smart_search.dart` |
| `lib/social_center.dart` |
| `lib/social_home.dart` |
| `lib/social_reels.dart` |
| `lib/social_sharing.dart` |
| `lib/social_story_experience.dart` |
| `lib/social_theme_gallery.dart` |
| `lib/social_video_editor.dart` |
| `lib/supabase/migrations/people_career_timeline.sql` |
| `lib/tv_controller.dart` |
| `lib/tv_host.dart` |
| `lib/ultimate_features.dart` |
| `lib/worldwide_location.dart` |
| `lib/xray.dart` |

## Deleted files

| File |
| `Backend/database/platform_and_games.sql` |
| `Backend/routes/game_routes.dart` |
| `Backend/services/game_service.dart` |
| `CHANGELOG_FOOD_AND_GAMES.md` |
| `FOOD_DELIVERY_AND_GAMES_EXPANSION.md` |
| `GAME_CATALOG_AND_SUDOKU_UPDATE.md` |
| `games_top.txt` |
| `lib/core/models/game_catalog.dart` |
| `lib/games.dart` |

## Important scope notes

- Gaming modules and game-specific backend/schema files are intentionally deleted; no game feature should be reintroduced.
- Restaurant reviews use customer ratings from 1 to 5; average rating/count are maintained by the database trigger.
- Themed menus are fan-inspired suggestions. Restaurants must enter their actual dishes, pricing, ingredients and allergen data; the project does not represent fan menus as officially affiliated with any franchise.
- The disc-import layer keeps episode order based on resolved season/episode identity, not disc or import order. Actual title/track extraction remains dependent on the configured ripper and physical media.
- Static app-authored labels use `UniversalText`; some interpolated/dynamic messages, form decorations, and server-provided messages still require explicit localization review. The optional translation Edge Function/provider must be deployed for uncatalogued text fallback.
- Flutter/Dart CLI tools were not available in the packaging environment. Static checks passed, but this is not a successful `flutter analyze`, `flutter test`, platform build, or live Supabase migration execution.
