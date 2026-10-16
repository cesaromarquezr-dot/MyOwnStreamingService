# Streaming, AI discovery, delivery, and security update

This update extends the existing MyOwnStreamingService project. It is an integration baseline, not a claim that a production CDN, hosted AI model, DRM license service, or independently audited end-to-end encryption deployment has been provisioned.

## Included in the source

- **Personalized discovery:** the existing profile-aware recommendation ranker is exposed in the Streaming Companion delivery studio. It currently uses available profile, metadata, ratings, and viewing signals; it is not a hosted LLM or learned recommendation model.
- **Smart-thumbnail preview:** the backend uses FFmpeg to extract a frame at a selected timestamp. This is a useful preview/selection tool, but it is not generative AI or semantic visual ranking.
- **HLS/DASH VOD packaging:** authenticated backend endpoint calls FFmpeg to produce adaptive manifests and renditions in a cache beneath `MEDIA_ROOT/adaptive_cache`. The returned playback paths are opaque, short-lived capabilities (currently 60 minutes). FFmpeg must be installed on the backend host and accessible as `ffmpeg` on `PATH`.
- **CDN fallback hooks:** the Flutter studio can try the origin and configured HTTPS CDN candidates. Setting a URL does not create a CDN: each CDN must be provisioned to cache/proxy the origin path correctly, preserve manifests/segments, and apply your authorization and purge rules.
- **DRM readiness status:** the backend reports whether license endpoint environment variables are configured. It intentionally does not fake DRM encryption or license issuance. The current FFmpeg packaging is not DRM-protected.
- **Offline direct-file downloads:** the app stores eligible direct media downloads in app-private support storage and stores local metadata. This is not a DRM offline-license workflow and does not support downloading HLS/DASH playlists as offline packages. Only download content you are authorized to retain.
- **Google/Apple sign-in:** Flutter starts Supabase OAuth and exchanges a verified Supabase Auth access token for an app backend session. It requires an already-existing MyOwnStreamingService account with the same confirmed email; it does not silently create or merge accounts.
- **Text-only E2EE prototype:** per-profile X25519 keys are stored in device secure storage; the server stores public keys and opaque AES-GCM ciphertext envelopes. The chat UI restricts E2EE mode to plain text.

## Apply the database migration

Run the following in the Supabase SQL editor, in addition to any earlier social/comment migrations required by your installed version:

1. `Backend/database/social_e2ee.sql` (same migration is mirrored at `lib/supabase/migrations/social_e2ee.sql`).
2. Apply `Backend/database/social_message_enhancements.sql` if not already applied for message editing/pinning support.
3. Apply prior social rich-comment/reaction migrations if those features are not already deployed.

Back up the database before running schema changes against a production project.

## Social sign-in setup

1. Enable Google and/or Apple as providers in Supabase Auth and set their provider credentials.
2. Add `myownstreamingservice://login-callback` to the Supabase Auth redirect URL allow-list. Configure the same callback with the native provider setup where applicable.
3. Configure the app's normal Supabase URL/publishable key using your existing app setup and optionally override the callback:
   `--dart-define=SUPABASE_OAUTH_REDIRECT_URL=myownstreamingservice://login-callback`
4. Set backend environment variables `SUPABASE_URL` and either `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`. The backend verifies the access token through Supabase's `/auth/v1/user` endpoint. Do not put the service-role key in Flutter.
5. Try signing in with the same verified email as an existing app account. Account auto-linking/creation is deliberately not performed by this exchange route.

The OAuth deep-link schemes are registered in the Android manifest and iOS `Info.plist`; native provider credentials and platform signing configuration remain deployment tasks.

## Adaptive streaming and smart thumbnails

The adaptive routes are in `Backend/routes/playback_routes.dart`:

- `POST /api/v1/playback/adaptive` — body includes an authorized relative `path` and `format` (`hls` or `dash`).
- `POST /api/v1/playback/thumbnail` — body includes an authorized relative `path` and `seconds` timestamp.
- `GET /api/v1/playback/capabilities` — reports configured delivery/license endpoints.

Set `MEDIA_ROOT` to a directory containing your authorized source media. Ensure the API account's media policy can resolve the requested relative path. Because packaging is CPU- and disk-intensive, production deployments should add a background job queue, per-account concurrency quotas, disk-space monitoring, and cache eviction before exposing it broadly.

To advertise CDN candidates, set `PLAYBACK_CDN_BASE_URLS` to a comma-separated list of **HTTPS** base URLs, for example:

`PLAYBACK_CDN_BASE_URLS=https://cdn-a.example.com,https://cdn-b.example.com`

Configure each CDN as an origin pull/reverse proxy. Playback capability paths are returned under `/api/v1/playback/adaptive/<opaque-session>/...`; a CDN must rewrite or route them to the backend path for the same resource and cache the generated manifest/segments consistently. Protect purge operations and don't expose arbitrary origin files through a broad cache rule. Opaque path tokens expire after an hour and are held in backend memory, so use a shared capability/session store if running multiple API replicas.

## DRM is not activated by license URL alone

Optional capability indicators can be supplied with `WIDEVINE_LICENSE_URL`, `FAIRPLAY_LICENSE_URL`, and `PLAYREADY_LICENSE_URL`. These settings only advertise configuration. Production DRM requires a licensed DRM provider, correct packaging encryption (CENC/CBCS as supported), device-specific license exchange, entitlement checks, secure key handling, and compatible playback SDKs. Do not mark content as DRM-protected until those systems are implemented and tested together.

## Offline downloads

The Offline Downloads screen accepts direct, authorized single-file media URLs and stores the downloaded file in app-private storage. It intentionally rejects HLS/DASH manifest extensions and obvious HTML responses. This is a guardrail, not proof that every source is unprotected. Add explicit backend entitlement checks and a format-aware licensed DRM SDK before supporting protected/offline-entitled content. Uninstalling the app or clearing app data can remove local files.

## E2EE prototype limitations and safe use

The current `SocialE2eeService` uses X25519 + HKDF-SHA256 + AES-256-GCM for plain text messages. Private profile keys remain in device secure storage; the server receives only public keys and ciphertext envelopes. The current prototype:

- does **not** provide forward secrecy or a Double Ratchet;
- relies on a server-hosted public-key directory that may be substituted by a compromised server;
- requires members to open the conversation to publish their public key;
- needs the displayed fingerprints to be verified out of band for sensitive conversations;
- cannot recover old messages if the device key is lost, and doesn't yet support encrypted attachments, GIFs, voice/video calls, or multi-device key sync;
- has not received independent cryptographic review.

For production-sensitive conversations, integrate an audited protocol/library with key transparency, forward secrecy, device verification, key rotation/revocation, multi-device lifecycle, encrypted attachment handling, and abuse-reporting flows designed around minimal plaintext disclosure.

## Validation

The project archive includes these source changes and setup notes. FFmpeg HLS/DASH packaging was smoke-tested against a small local test clip in the build environment. Android manifest, iOS plist, and SVG are checked as XML. This environment does not contain the Flutter/Dart SDK, so `flutter analyze`, backend Dart analysis, and end-to-end device/Supabase tests were not run here. Run the following locally:

```powershell
flutter pub get
flutter analyze
flutter test
```

Then verify both OAuth callbacks on real devices, run the backend against a staging Supabase project, play an HLS and DASH test asset, test CDN origin pull/failover, and perform a security review before production deployment.
