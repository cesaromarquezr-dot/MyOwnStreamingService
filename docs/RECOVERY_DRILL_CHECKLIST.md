# Recovery Drill Checklist

Perform quarterly and after major database, storage, or authentication changes. Do not run a destructive restore against the only live database.

## Database

- [ ] Take a fresh encrypted backup with `scripts/production/backup.sh`.
- [ ] Verify the checksum file and confirm the archive can be decrypted by the designated recovery identity.
- [ ] Restore into a new staging database using `scripts/production/restore_supabase.sh` with `SUPABASE_TARGET_LABEL=staging` and explicit `CONFIRM_RESTORE=RESTORE`.
- [ ] Validate login, profile ownership, RLS boundaries, media metadata, watch state, account membership, conversations, marketplace records, and order status.
- [ ] Record elapsed recovery time and any missing tables/objects.

## TrueNAS media

- [ ] Verify each media dataset has an appropriate ZFS snapshot schedule.
- [ ] Verify replication to a physically or administratively separate destination.
- [ ] Restore a representative media file and its metadata from a snapshot.
- [ ] Validate file checksums, ownership, permissions, SMB/NFS isolation, and the media agent's read-only paths.
- [ ] Verify regenerated HLS/DASH segments and thumbnails can be rebuilt from authorized source media.

## Service and clients

- [ ] Restore the backend and required secrets from separately protected secret management.
- [ ] Check TLS certificate and reverse proxy health before reopening remote access.
- [ ] Run Flutter analyzer/tests and backend smoke tests.
- [ ] Test a signed playback URL expiry, session revocation, and unauthorized profile/account access.
- [ ] Confirm no stale profile presence or unintended activity sharing remains after recovery.
- [ ] Document the drill owner, date, recovery time, and follow-up actions.
