# Production Readiness and Reliability

This release adds practical foundations for security/privacy controls, regression checks, recoverable offline playback progress, root-level accessibility, Hey Media action policy, owner-only operational probes, and backup/restore scripts. It is not a claim that the system is fully production-certified.

## Included code

- `lib/production_readiness.dart`: owner-gated dashboard. Ownership is confirmed through the backend's profile-governance capability endpoint. Dashboard checks are authenticated endpoint probes, not host CPU/memory/disk monitoring.
- `lib/privacy_preferences.dart`: persisted per-profile privacy preferences. Presence updates respect the local share-presence and share-activity choices; playback QoE collection is opt-in (off by default); recommendations can use a chronological generic mode when personalization is off.
- `lib/offline_sync_queue.dart`: bounded purpose-specific queue for playback progress; updates are coalesced by profile/media. It does not accept arbitrary action types and is not used for chats, payments, credentials, or media blobs.
- `lib/accessibility_offline_settings.dart`: text scaling, high contrast, reduce motion, subtitle and audio-description preferences, presence privacy, and pending progress sync.
- `lib/app_accessibility.dart`: applies profile text scale, contrast, and reduced-animation preference at the app root.
- `lib/core/services/hey_media_action_policy.dart`: shared confirmation policy for consequential Hey Media actions. Every action executor must still re-check authorization at the backend and must use this policy before side effects.
- `Backend/database/consolidated_platform.sql`: service-role-only tables for privacy preference synchronization, sanitized AI action audits, idempotent sync receipts, health snapshots, and backup records. There are deliberately no browser-client RLS policies.
- `.github/workflows/flutter-quality.yml`: analyze and test gate on push/PR.
- `scripts/production/backup.sh` and `scripts/production/restore_supabase.sh`: encrypted PostgreSQL backup bundle and guarded database restore.

## First rollout checklist

1. Create a verified backup before applying schema changes.
2. Apply `Backend/database/consolidated_platform.sql` after existing base and account/social migrations. The app currently stores privacy preferences on-device and directly enforces presence/telemetry choices; cross-device privacy preference synchronization and audit ingestion require authenticated backend endpoints to be added before those tables are used.
3. Configure `AGE_RECIPIENT`, `BACKUP_ROOT`, `BACKUP_WORK_ROOT`, and `SUPABASE_DB_URL` for the scheduled backup environment. `BACKUP_WORK_ROOT` must be a private tmpfs or encrypted scratch directory because unencrypted PostgreSQL dumps and bundles exist there briefly; do not point it at a shared or unencrypted media dataset. Use a dedicated encrypted backup destination outside the media pool being snapshotted; restrict its permissions and test decryption/restore separately.
4. Configure a separate TrueNAS ZFS snapshot and replication task for actual media datasets. The backup script deliberately does not recursively copy movie/music files, and it does not operate the TrueNAS API.
5. Run `scripts/production/backup.sh`, verify the SHA-256 file, and perform a restore to a disposable staging database. Set `RESTORE_WORK_ROOT` to private tmpfs/encrypted scratch storage before restoring. Production restore requires an additional explicit environment acknowledgement.
6. Protect `Backend/.env` and service-role secrets outside the source tree. The backup bundle excludes `.env` files, private-key/certificate file extensions, common credential-name patterns, developer caches, upload/recording folders, and `Backend/media`; review your own secret naming conventions before relying on it. The restore script refuses to run without the adjacent SHA-256 file and a valid matching digest.
7. Enable the GitHub Actions workflow and fix current analyzer/test failures rather than weakening the gates.
8. Add a trusted server-side metrics collector for CPU, memory, disk SMART, ZFS pool state, certificate expiry, transcoding queue age, response latency, buffering rates, delivery failures, and backup/restore results. The Flutter dashboard's current probes do not collect these host metrics.

## Offline behavior and limitations

- Playback progress is retained in the app state and represented in a per-account pending queue. Repeated updates for the same profile/media replace older queued values; writes are throttled to limit flash/storage churn.
- The Settings page can retry the account snapshot sync. Queue contents are cleared only after the authenticated account-snapshot endpoint confirms success.
- `lib/offline_metadata_cache.dart` stores a bounded profile-scoped metadata cache when the profile has opted in. It excludes playback/trailer URLs, user-activity fields, and private media paths; it pins restored items to the cached profile rather than retaining the original account-wide access list. It does not download media files.
- Automatic network-change event handling is not installed because this repository has no connectivity plugin. Users can explicitly retry when a connection returns; future work can add connectivity event triggers after the server-side sync receipt/reconciliation endpoint is in place. Do not claim support for secure offline video downloads until encryption, platform download entitlements, rights checks, key expiry, and device-bound playback are implemented.
- Cross-device playback progress must be verified against actual account snapshot restore logic. The client includes `playbackProgress` in the synchronized snapshot, but a dedicated per-profile progress table and server-side reconciliation are recommended before relying on it for production device continuity.

## Privacy and AI action safety

- `sharePresence` and `shareActivity` settings suppress presence updates in the API wrapper and clear an existing activity on opt-out.
- Playback diagnostic collection is disabled by default and checks the profile's opt-in setting before recording.
- Turning off personalized recommendations switches local discovery ranking to a newest-first generic list, while continuing to exclude the profile's disliked/completed items.
- The Hey Media policy distinguishes read-only discovery/playback from actions needing explicit confirmation. The current assistant is primarily a local query/plan experience; future order/payment/delete/security executors must call the policy and enforce the same role and ownership rules at the server. Never treat a client decision as authorization.

## Tests

Run `flutter pub get`, `flutter analyze`, and `flutter test`. The CI workflow will enforce analysis/tests, but its first run can fail on pre-existing analyzer findings. Also test on Windows, Android/iOS, modern desktop browsers, and TV remotes before release; this repository environment does not certify those hardware/browser combinations.
