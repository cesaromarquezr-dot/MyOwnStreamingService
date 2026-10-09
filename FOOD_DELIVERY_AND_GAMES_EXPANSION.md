# MyOwnStreamingService — Food & Delivery + Games Expansion

Updated: October 9, 2026

Food & Delivery and Games are two independent features. Food & Delivery does not share game engines, tournaments, phone-motion controls, or media-library mechanics. Games does not depend on the food ordering workflow.

## Games

### Catalog and device scope

- Added catalog categories for trivia, party, music, movie/TV, racing, dance/rhythm, fighting, tournaments, and sports.
- Added 150+ planned catalog concepts across board/card games, word/puzzle games, party games, music quizzes, movie/TV quizzes, dance/rhythm, motion sports, Music Racing, and cross-game tournaments.
- Added the Crossover Arena Fighter as a TV/console/PC-only catalog item. It is filtered out on mobile targets. Current platform checks recognize desktop builds, large web windows, and TV layouts; actual PS5/Xbox/Switch 2 packaging still depends on platform-specific build/toolchain support.
- Music and movie/TV entries describe using existing server media IDs and metadata rather than duplicating the server's source audio/video.
- Phone motion-controller support is identified in the catalog for planned dance, rhythm, and motion games.
- A planned item is clearly labeled **PLANNED** and opens an explanation instead of launching a fake playable match. Existing implemented games remain available.

### Scope note

The expanded catalog is a roadmap, not a claim that all the new games are already playable. The full party engine (QR/join codes, lobby, host rotation, phone controllers and mic answers), dance choreography/scoring engine, motion controller calibration, music/movie metadata question generation, Music Racing, cross-game tournament scoring, and the fighter's combat/character/stage assets still require implementation. Distribution of recognizable third-party characters, art, audio, footage, names, and likenesses requires appropriate rights/licenses.

## Food & Delivery

### Discovery

- Users can use device GPS or manually enter country, state/region, city, postal/ZIP code, and street address.
- Manual search geocodes the selected location. Nearby search merges restaurants registered in the platform database with best-effort public OpenStreetMap-backed directory listings returned by Photon.
- Restaurant cards display available name, cuisine, address, approximate distance, phone, platform menu availability, fees, and ratings when the platform has that information. External listings may include a website and listed opening hours when the data provider supplies them.
- OpenStreetMap attribution is displayed in the UI. External directory results can be incomplete, stale, or missing phone, hours, images, and menu data; public Photon service availability is not guaranteed.
- External directory listings are informational only. They cannot be ordered from in-app until the restaurant owner registers a platform restaurant and adds its menu, prices, fulfillment options, fees, and tax configuration. This prevents guessed third-party prices or menus from appearing as real checkout prices.
- The external provider can be disabled using `FOOD_EXTERNAL_DIRECTORY_ENABLED=false`. It defaults to enabled. It uses an in-memory 10-minute cache and bounds results/request sizes.

### Restaurant owner onboarding

- A user can open **Restaurant Owner Center** from Food & Delivery, regardless of which streaming server the account uses.
- Owners can register restaurant name, cuisine, description, phone, street/city/region/postal/country, resolve the address to coordinates, set currency/minimum order/delivery fee/configured tax rate, and enable delivery and/or pickup. The platform service fee is controlled centrally by MyOwnStreamingService, not by each merchant.
- Owners can upload restaurant and menu-item images from a device (JPG, PNG, or WebP up to 5 MB), or provide a photo URL.
- Owners can add menu items with category, description, price, and image; they can also create percentage coupons with a minimum subtotal and optional redemption cap support in the backend.
- Ownership belongs to the account identity, not to its selected streaming-server assignment. Accounts can register separate restaurants in the same city when they use this shared marketplace database/backend. Separate standalone deployments with separate databases do not automatically share listings; those deployments need a common marketplace API/database or federation.

### Customer checkout, fees, and rewards

- Checkout supports **Delivery** or **Pickup** when the restaurant offers both. Pickup removes the delivery fee and uses the restaurant address; delivery requires a street address.
- The invoice itemizes restaurant subtotal, coupon discount, estimated tax, platform service fee, delivery fee (delivery only), and total.
- Coupon codes are validated server-side against restaurant, active dates, minimum subtotal, and redemption limits. Example: `WELCOME10` for 10% off, if the restaurant creates that coupon.
- Restaurant loyalty points are earned per order using the restaurant's configured points rate and displayed in checkout and the user's restaurant rewards summary.
- Existing restaurant rating/review fields are shown where available, but a full customer review submission/moderation and merchant reputation-points workflow is not part of this change. Rewards are earn-only here; redeeming points for discounts still needs implementation.
- The platform service fee defaults to 199 cents and can be changed using `FOOD_PLATFORM_SERVICE_FEE_CENTS` in the backend environment. Tax is based on the merchant-configured percentage. This is not a jurisdiction-aware tax-compliance service, and merchants must configure applicable rates correctly.
- The order backend deliberately blocks actual order placement unless `FOOD_PAYMENT_MOCK=true` is enabled for local development. A real payment-provider adapter is required before production orders can be paid. Delivery dispatch, courier assignment, and live courier GPS tracking are not integrated by this change.

### Database and photo storage setup

Apply `Backend/database/food_delivery.sql` to the Supabase project. It creates/updates restaurant fee and contact fields, order invoice fields, restaurant ownership, coupons, rewards ledger, and the `food-restaurant-images` public-storage bucket for restaurant/menu photos. The authenticated backend performs uploads using its server-side Supabase credentials; never put a service-role key in the Flutter app.

## Server-name save workflow and navigation

After naming a server and choosing **Save & Continue**, the server is claimed, the app opens profile selection/creation, and selecting or creating a profile calls back into the main home screen. The root navigator is used to avoid the selection route remaining underneath the main app.

The More (three-dot) sheet has a bounded height and scrollable contents to reduce bottom-edge overflow in short viewports. Flutter layout behavior still needs device testing on actual target TVs and aspect ratios.

## Verification status

The edited source was checked structurally, but Flutter/Dart tooling was not installed in the execution environment, so `flutter analyze`, unit tests, and real-device UI tests could not be run. Run the project's normal Flutter analyzer/tests after installing the SDK and exercising Food & Delivery on phone/tablet/PC/TV layouts.
