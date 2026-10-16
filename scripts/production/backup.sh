#!/usr/bin/env bash
set -euo pipefail

# Encrypted database and sanitized source snapshot. Does not copy large media
# payloads; configure a separate TrueNAS/ZFS snapshot task for media datasets.
: "${BACKUP_ROOT:?Set BACKUP_ROOT to a protected destination outside the project dataset}"
: "${BACKUP_WORK_ROOT:?Set BACKUP_WORK_ROOT to private tmpfs or encrypted scratch storage; plaintext dumps are created there temporarily}"
: "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL to the PostgreSQL connection string}"
: "${AGE_RECIPIENT:?Set AGE_RECIPIENT to an age public recipient key; plaintext backups are disabled}"

for command in age pg_dump tar sha256sum; do
  command -v "$command" >/dev/null 2>&1 || { echo "Required command is missing: $command" >&2; exit 2; }
done

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$BACKUP_ROOT" "$BACKUP_WORK_ROOT"
chmod 700 "$BACKUP_ROOT" "$BACKUP_WORK_ROOT"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_ID="mos-${STAMP}-$$"
WORK="$(mktemp -d "${BACKUP_WORK_ROOT%/}/.work-${BACKUP_ID}.XXXXXX")"
chmod 700 "$WORK"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$WORK/bundle"
# Database dump may contain private user data. The work directory must be on
# tmpfs or encrypted scratch storage; it remains 0700 until cleanup.
pg_dump --format=custom --no-owner --no-acl --file "$WORK/bundle/supabase.dump" "$SUPABASE_DB_URL"

# Include source and deployment instructions but exclude local credentials,
# certificates, build output, caches, and developer-specific config.
tar -czf "$WORK/bundle/project-snapshot.tar.gz" \
  --wildcards --wildcards-match-slash \
  --exclude='.git' --exclude='.dart_tool' --exclude='build' \
  --exclude='**/.env*' --exclude='*.pem' --exclude='*.key' \
  --exclude='*.p12' --exclude='*.pfx' --exclude='*.crt' --exclude='*.cert' \
  --exclude='**/*secret*' --exclude='**/*credential*' \
  --exclude='**/node_modules' --exclude='**/.packages' \
  --exclude='Backend/media' --exclude='**/media_library' \
  --exclude='**/uploads' --exclude='**/recordings' \
  -C "$PROJECT_ROOT" .
cat > "$WORK/bundle/backup-manifest.txt" <<MANIFEST
backup_id=$BACKUP_ID
created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
project_snapshot=project-snapshot.tar.gz
database_dump=supabase.dump
encrypted=true
media_payloads_included=false
MANIFEST

tar -czf "$WORK/bundle.tar.gz" -C "$WORK/bundle" .
OUT="$BACKUP_ROOT/${BACKUP_ID}.tar.gz.age"
age -r "$AGE_RECIPIENT" -o "$OUT" "$WORK/bundle.tar.gz"
sha256sum "$OUT" | awk '{print $1}' > "$OUT.sha256"
chmod 600 "$OUT" "$OUT.sha256"
echo "Encrypted backup created: $OUT"
echo "Verify the checksum and periodically test restoration. Media datasets require a separate TrueNAS snapshot/replication plan."
