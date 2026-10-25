# External Food & Marketplace Integrations

## Included in this build

- `lib/external_marketplace.dart` adds an External Food & Marketplace screen.
- Mercado Libre uses the public catalog search endpoint `GET /sites/{SITE_ID}/search?q=...` for the selected supported country (Mexico is the default). Results show listing title, price/currency when supplied, thumbnail, seller and the official listing link.
- Amazon Mexico, eBay, Uber Eats and Rappi open provider-owned search pages. The app does not scrape those websites, store their credentials, or claim API/checkout access that has not been granted.
- The screen is linked from the existing unified `MarketplaceHubScreen`.

## Provider production access

### Mercado Libre

The current public catalog search integration is intended for discovery only. Before production rollout, review the current Mercado Libre developer terms, authentication rules, rate limits, attribution and site-specific policies. Do not assume search access permits order creation or checkout.

### Amazon

Amazon Creators API requires an accepted Amazon Associates account, marketplace-specific onboarding and API credentials. Store credentials on the backend. Implement signed requests and follow the Amazon program's display, caching, attribution and affiliate-link policies before replacing the search handoff.

### eBay

eBay Browse/Buy API production access can require eBay Partner Network and business-unit approval. Implement OAuth/token handling on the backend after credentials and required production access are granted. Do not expose client secrets in Flutter.

### Uber Eats

Uber Eats Marketplace API is primarily for approved partner/merchant integrations, with written approval/licensing requirements for applicable use cases. The current implementation opens Uber Eats search; it does not submit orders or access private menus.

### Rappi

The current implementation opens Rappi search where the service supports it. No undocumented/private Rappi API is called.

## Security and checkout

- Never place API secrets or client secrets in `lib/`, app assets, `--dart-define`, or a distributed mobile binary.
- Put partner credentials and token exchanges in the authenticated backend, with per-provider environment variables, least-privilege scopes, timeouts, rate limits, redacted logs and secret rotation.
- Keep third-party checkout on the provider's official flow unless the provider has explicitly approved in-app ordering and the backend implements its contractual requirements.
- Display provider, currency, and source links; treat listing prices and availability as time-sensitive.

## Verification

The source archive was ZIP-integrity checked after packaging. Flutter SDK tooling is not available in the packaging environment, so run `flutter pub get` and `flutter analyze` locally before merging, then test Mercado Libre network access on Android, iOS and Web (Web may be subject to provider CORS policies).
