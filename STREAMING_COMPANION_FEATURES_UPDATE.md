# Streaming Companion feature integration

This update adds a single, discoverable entry point for social, discovery, group-watch, offline-browsing, profile-safety, and home-server features, and surfaces it from **More → Streaming Companion**.

## Added or connected in this update

- **Streaming Companion hub** (`lib/streaming_companion_hub.dart`): routes to existing Friends/Communities, Activity Timeline, Group Watch, shared watchlist, collections/recommendation voting, Smart Search, people connections, achievements, profile statistics, X-Ray/spoiler controls, home-server scan/health, storage dashboard, parental controls, library privacy, account security, and remote-access screens.
- **Watch Together launcher**: select a title, optionally invite other profiles in the current account, create a backend Group Watch session, and open its synchronized session screen.
- **Shared group watchlist screen**: refresh the backend-backed shared list, remove an item, or acquire it into the active profile's library using the existing API.
- **Offline library snapshot**: save the current library's metadata to profile-scoped local preferences and browse that snapshot later. This is an offline metadata fallback only; it does not download media files or promise offline playback.
- **Custom social reactions**: post reactions, chat message reactions, and review reactions now offer a custom short reaction/emoji input in addition to preset reactions.
- **Chat message editing and pinning**: edit your own text-only messages, show an “Edited” marker, and pin/unpin messages; group pins are restricted to owners/moderators by the backend.
- **More menu entry**: exposes all of the above from one place without adding another permanent bottom-navigation item.

## Existing capabilities reused

The project already included social posts and communities, GIF/video URL comments, story features, rich chat with emoji/media/voice-message paths and typing state, group watch API/session controls, import/rip (ARM), server scanning, content-governance settings, profile achievements, people connections, recommendations, and a spoiler-protection preference in X-Ray. This update connects them rather than building parallel duplicate implementations.

## Backend and setup notes

- Keep the backend configured and authenticated for social feeds, reviews, watchlist changes, watch-party sessions, server scans, account security, and profile governance.
- Keep TrueNAS media behind the backend / home-server authorization flow; do not place NAS credentials in the Flutter app or expose SMB directly to clients.
- Apply the existing social reactions/comments migration if it has not been applied, then apply `Backend/database/social_message_enhancements.sql` (also mirrored at `lib/supabase/migrations/social_message_enhancements.sql`) to add persistent chat message pin state. The offline snapshot is local to the device.
- The offline snapshot contains serialized media metadata and URLs only. Poster images may depend on the image cache; source video/audio stays on the NAS and still needs a reachable, authorized stream URL.

## Validation limitation

The container used to prepare this update does not have Flutter or Dart installed, so `flutter analyze` and a device build could not be run here. The ZIP was checked for integrity after packaging; run `flutter pub get` and `flutter analyze` in the project folder before merging or shipping.
