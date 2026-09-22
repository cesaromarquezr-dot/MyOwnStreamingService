Flutter client

The Flutter client is the UI and client-side application layer for the streaming-service platform. The application is intentionally organized into feature-focused Dart files so media, music, discovery, reviews, storage, commerce, home-server administration, security, and platform features can evolve independently without turning the client into a single monolithic source file.

Project structure

Core application

main.dart — application entry point, startup flow, routing, account/session initialization, and top-level UI composition.

app_core.dart — shared application state, media models, collections, profiles, account state, preferences, and core client behavior.

backend_api.dart — client-side API layer used to communicate with the backend services.

localization.dart — localization and language-selection support.

responsive.dart — responsive layout helpers and adaptive UI behavior.

Media and discovery

details.dart — media detail experiences for movies and series.

movies.dart — movie browsing and movie-focused experiences.

series.dart — series and episode experiences.

media_catalog.dart — media catalog and library presentation.

library_hubs.dart — library organization and hub experiences.

recently_watched.dart — recently watched media.

smart_search.dart — search and discovery interfaces.

discovery_experience.dart — discovery-oriented feature experiences.

feature_center.dart — central navigation for discovery, recommendations, collections, wrapped experiences, music, commerce, artwork, and other platform features.

collection_details.dart — collection browsing and collection-specific details.

trailer.dart — trailer presentation and playback integration.

xray.dart — contextual media information and X-Ray experiences.

media_ai.dart — AI-assisted media functionality.

media_experience.dart — broader media playback and viewing experiences.

media_universe.dart — relationships and connected media-universe experiences.

film.dart — film-focused feature experiences.

hollywood.dart — film-industry and Hollywood-oriented experiences.

Music

music.dart — music browsing and playback-oriented experiences.

music_favorites.dart — music favorites and related personal library features.

music_achievements.dart — music achievement experiences.

Social and group features

reviews.dart — ratings, reviews, and review-related UI.

rating_system.dart — rating interfaces and rating behavior.

group_chat.dart — group messaging experiences.

group_watch.dart — synchronized group-watch experiences.

profiles.dart — account profiles and profile switching/management.

profile_artwork.dart — profile artwork customization.

profile_content_safety.dart — profile-level content safety controls.

Home server, storage, and self-hosting

home_server.dart — home-server management and connection experiences.

home_widgets.dart — home-server/home-dashboard widgets.

storage_dashboard.dart — storage monitoring and management.

self_hosting_settings.dart — self-hosting configuration.

remote_access.dart — remote-access configuration and status.

arm_importer.dart — Automated Resource/Media import integration.

worldwide_location.dart — worldwide address and location support used by account, commerce, and other location-aware features.

Commerce

shop.dart — marketplace, products, stores, seller tools, wishlist, bag, checkout, orders, and contextual shopping associations.

payment.dart — payment and payment-session experiences.

Security and account management

account_settings.dart — account configuration.

security_settings.dart — security, authentication, verification, sessions, and related account protection controls.

signup.dart — account registration.

connected_sports.dart — connected sports/account integrations.

device_features.dart — device-specific functionality and capabilities.

Sports and platform expansion

sports.dart — sports browsing and sports-related experiences.

next_gen_features.dart — next-generation platform functionality.

platform_expansion.dart — expanded platform capabilities and integrations.

ultimate_features.dart — advanced/ultimate feature experiences.

ultimate_platform.dart — broader platform-level experiences.

roadmap_features.dart — planned and experimental feature experiences.

Backend integration

The Flutter client communicates with a companion backend under Backend/. The backend is organized into routes, services, models, middleware, database access, ARM/import functionality, payments, recommendations, reviews, search, storage, remote access, sports, shop, and platform services.

Important backend areas include:

Backend/server.dart — backend application entry point.

Backend/routes/ — HTTP/API route definitions.

Backend/services/ — domain and business services.

Backend/models/ — backend data models shared by API features.

Backend/middleware/ — authentication and request middleware.

Backend/database/ — database access and persistence.

Backend/arm/ — ARM import, metadata, verification, and title-resolution functionality.

The Flutter client should use backend_api.dart rather than duplicating backend request logic inside individual feature screens.

Supabase

Supabase support is provided through the client/backend integration and is optional at startup. Configuration is supplied through the application's Supabase configuration rather than being hard-coded into individual feature files.

Documentation conventions

Every Dart source file should retain a file-level documentation header describing its purpose. Major classes and public methods should have inline documentation where their behavior or API contract is not self-evident.

When modifying a feature:

Preserve the file-level documentation header.

Keep feature-specific UI and behavior in the appropriate feature file.

Reuse models and application state from app_core.dart instead of creating parallel representations.

Use backend_api.dart for backend communication.

Keep public classes and methods documented.

Preserve existing behavior unless a change is explicitly required.

Run flutter analyze after changes and resolve API/model mismatches against the current source definitions rather than guessing at method signatures or model fields.

Development workflow

From the project root:

flutter pub get
flutter analyze
flutter run

flutter analyze is the primary static check before considering a source change complete. Analyzer errors should be resolved against the actual declarations in app_core.dart, backend_api.dart, and the relevant model/API files.