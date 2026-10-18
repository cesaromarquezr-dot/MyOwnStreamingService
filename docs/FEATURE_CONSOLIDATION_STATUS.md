# MyOwnStreamingService — consolidated feature status

This document tracks the additions consolidated into this project snapshot. The target is Flutter across mobile, desktop, and TV, with Supabase as the application database/auth layer and TrueNAS as the home-media storage layer. Gaming features are intentionally out of scope and have been removed from this snapshot.

## Core product areas

- **Movies, TV, and music:** retain the existing media catalog, playback, discovery, library and profile pages. Physical imports are treated as source media and preserve original metadata.
- **Disc ripping/imports:** ARM import/review models and services support media title classification, stream metadata verification, bonus/title records, canonical episode resolution, and sorted series episode presentation. A physical disc is not guaranteed to expose every title or track through every drive/ripper combination; validate with the actual supported hardware and ripping software.
- **Localization:** the root Flutter app listens for language changes; selected locale resources update immediately. `UniversalText` can use local phrase translations and a configured translation Edge Function fallback. Imported metadata translations are cached separately from original titles/descriptions. The Edge Function needs to be deployed and configured; a systematic sweep is still required to migrate every remaining literal `Text` and every dynamic backend message.
- **Social:** keep the existing social/profile/community/messaging components and shared account/profile navigation.
- **Market:** keep the existing shop/catalog and order-related feature entry points. Real production checkout still depends on a configured payment provider, webhooks, and market-specific tax/refund policy.
- **Hey Media AI:** use one user-facing assistant with scoped feature tools for media search, recommendations, metadata assistance and other authorized operations. High-impact actions (deleting/replacing files, purchases, orders, public posts) must require explicit confirmation. Separate AI models per screen are not required.
- **TrueNAS/Supabase:** store large source and converted media on TrueNAS; keep profiles, catalog/index data, import jobs and application state in Supabase/backend services. Clients must never receive the Supabase service-role key or unrestricted NAS credentials.

## Food & Delivery additions in this snapshot

### Restaurant profiles

A restaurant profile contains name, cuisine, address fields, phone, a human-readable opening-hours summary, a structured weekly schedule, a 24/7 flag, and supported contact methods/details for call, SMS, Messages/iMessage, WhatsApp, email and website. Owners can edit hours/contact settings. Hours are stored in 24-hour `HH:MM` form and displayed as examples such as `Mon-Fri 9:00 AM-5:00 PM; Sat-Sun Closed` or `24/7`.

**Timezone note:** this snapshot stores the schedule, but does not calculate a guaranteed real-time `Open now` status in a restaurant-specific timezone. Add an explicit timezone field and test daylight-saving transitions before using hours to reject or promise an order.

### Ratings and reviews

Customers can submit one review per account per restaurant, with a 1–5 star rating and optional title/body. The SQL trigger calculates the average rating and review count from the review records. The server derives the verified-order flag from completed order records; clients cannot set it. Reviews are available through the authenticated API.

### Restaurant messaging and allergy questions

Customers can ask for recommendations, message restaurant owners, or ask about a menu item's ingredients. The server validates restaurant ownership and conversation participation. Ingredient presence, removal capability, and cross-contact response are separate pieces of information; the app must not promise an item is allergy-safe based on AI guesswork or incomplete menu data.

### Themed watch-party menus

Owner-created themed menus group actual restaurant menu items. Presets offer example food ideas for wizarding-fantasy/Harry Potter-inspired and superhero/Marvel-inspired movie marathons, plus horror, anime, space and holiday watch parties. Presets are suggestions only: a restaurant must add the real dishes, set real prices, and enter current ingredient/allergen information before the dishes can be ordered. Franchise-inspired menus are not to be represented as official or affiliated without the relevant permissions.

## Database migration order

For a new database, apply the current base schemas and then the food migrations in this order:

1. `Backend/database/consolidated_commerce.sql`
2. `Backend/database/food_messaging.sql`
3. `Backend/database/consolidated_commerce.sql`

The matching Supabase migration copies are under `lib/supabase/migrations/`. Also apply the existing account/media/social/shop/TV migrations required by the features you deploy. Use your project's established migration process rather than running a duplicate migration out of order.

For cross-server inventory and TV pairing, apply `Backend/database/consolidated_platform.sql`; it intentionally contains no games tables. Demo warehouse/server seed rows are for development inventory only and must be replaced with real hardware information in production.

## Verification and limitations

- Added model-level tests for restaurant profile fields, ratings, themes, ingredient metadata, and episode order.
- Flutter/Dart CLI tools were not available in the packaging environment, so this snapshot has **not** been confirmed by a successful `flutter test`, `flutter analyze`, platform build, or live Supabase migration run. Run these checks locally before merging into your working branch.
- The change manifest compares against the available project ZIP snapshot. It cannot account for unuploaded local edits in another copy of the project.
