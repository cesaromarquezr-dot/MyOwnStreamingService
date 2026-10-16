# Page-specific customization buttons

## Behavior

- Removed the single app-wide floating Customize button.
- Added a reusable `PageCustomizeButton` app-bar action. Every use supplies an explicit page ID, and the app shell opens the matching customization page instead of relying on the current/global page.
- Home, Details, Friends, Actors, Library, Collections, Hey Marathon, Movies, TV Shows, TV Channels, Food & Delivery, Store, Store Creation/Storefront Designer, and Seller Dashboard now expose their own Customize action.
- Music keeps its existing Customize action.
- Added a Hey Marathon promotional card directly to the Home content, with a Plan button opening the existing marathon planner.

## Important implementation details

- `lib/page_customization_button.dart` owns the shared button and callback registration, avoiding imports from page modules back into `main.dart`.
- `lib/main.dart` registers `_openPageCustomizationFor` during app initialization and removes the global floating action button.
- Page IDs remain explicit (`home`, `details`, `friends`, `actors`, `library`, `collections`, `hey-marathon` (Hey Marathon), `movies`, `series`, `my-tv`, `food-delivery`, `shop`, `store-creation`, and `seller-dashboard`) so the right settings are saved independently.
- Store creation/settings routes use `/app/page/store-creation` to keep the page identity aligned with the settings being edited.

## Validation

- Source-level anchors were checked by the patch script.
- ZIP integrity and import/button coverage were checked after packaging.
- `flutter analyze` and `flutter test` were not run: Flutter/Dart SDK executables are unavailable in this environment. ZIP integrity and source-level assertions were checked. Live Supabase behavior was not tested.
