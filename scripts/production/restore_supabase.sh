#!/usr/bin/env bash
set -euo pipefail

# Destructive database restore. Always test against a staging database first.
: "${AGE_IDENTITY:?Set AGE_IDENTITY to the path of an age private identity file}"
: "${RESTORE_WORK_ROOT:?Set RESTORE_WORK_ROOT to private tmpfs or encrypted scratch storage; plaintext restore bundles are created there temporarily}"
: "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL to the PostgreSQL target URL}"
: "${SUPABASE_TARGET_LABEL:?Set SUPABASE_TARGET_LABEL to a human-readable target name}"
: "${CONFIRM_RESTORE:?Set CONFIRM_RESTORE=RESTORE only after reviewing and verifying the backup}"
[[ "$CONFIRM_RESTORE" == "RESTORE" ]] || { echo 'Restore aborted: CONFIRM_RESTORE must equal RESTORE.' >&2; exit 2; }
[[ -f "${1:-}" ]] || { echo "Usage: AGE_IDENTITY=... SUPABASE_DB_URL=... SUPABASE_TARGET_LABEL=... CONFIRM_RESTORE=RESTORE $0 backup.tar.gz.age" >&2; exit 2; }
BACKUP="$1"
for command in age pg_restore tar sha256sum; do
  command -v "$command" >/dev/null 2>&1 || { echo "Required command is missing: $command" >&2; exit 2; }
done
CHECKSUM_FILE="${BACKUP}.sha256"
[[ -s "$CHECKSUM_FILE" ]] || { echo "Missing checksum file: $CHECKSUM_FILE; refusing restore." >&2; exit 3; }
EXPECTED_SHA256="$(head -n 1 "$CHECKSUM_FILE" | tr -d "[:space:]")"
[[ "$EXPECTED_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "Malformed SHA-256 checksum file." >&2; exit 3; }
ACTUAL_SHA256="$(sha256sum "$BACKUP" | awk '{print $1}')"
[[ "$EXPECTED_SHA256" == "$ACTUAL_SHA256" ]] || { echo "Backup checksum mismatch; refusing restore." >&2; exit 3; }
if [[ "${SUPABASE_TARGET_LABEL,,}" == *prod* && "${ALLOW_PRODUCTION_RESTORE:-}" != "I_HAVE_VERIFIED_BACKUP_AND_TARGET" ]]; then
  echo 'Production target blocked. Set ALLOW_PRODUCTION_RESTORE=I_HAVE_VERIFIED_BACKUP_AND_TARGET only after a reviewed recovery procedure.' >&2
  exit 2
fi
mkdir -p "$RESTORE_WORK_ROOT"
chmod 700 "$RESTORE_WORK_ROOT"
WORK="$(mktemp -d "${RESTORE_WORK_ROOT%/}/.restore.XXXXXX")"
chmod 700 "$WORK"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
age -d -i "$AGE_IDENTITY" -o "$WORK/bundle.tar.gz" "$BACKUP"
mkdir "$WORK/bundle"
tar -xzf "$WORK/bundle.tar.gz" -C "$WORK/bundle"
[[ -s "$WORK/bundle/supabase.dump" ]] || { echo 'Backup is missing supabase.dump; refusing restore.' >&2; exit 3; }
echo "Target label: $SUPABASE_TARGET_LABEL"
echo 'About to replace objects contained in this database dump. Confirm that the target and backup have been reviewed.'
pg_restore --clean --if-exists --no-owner --no-acl --dbname="$SUPABASE_DB_URL" "$WORK/bundle/supabase.dump"
echo 'Database restore command completed. Validate application login, RLS, account/profile ownership, media metadata, and key workflows before returning to service.'
