#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created Backend/.env from .env.example. Add server-only API credentials, then run this script again."
  exit 1
fi
# Backend/.env must be shell-compatible KEY=value syntax.
set -a
. ./.env
set +a
exec dart run server.dart
