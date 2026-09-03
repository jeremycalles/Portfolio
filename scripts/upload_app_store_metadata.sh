#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 scripts/validate_app_store_metadata.py

if [[ -z "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
  echo "Set APP_STORE_CONNECT_API_KEY_PATH to your App Store Connect API key JSON." >&2
  echo "See fastlane/README.md" >&2
  exit 1
fi

export APP_VERSION="${APP_VERSION:-1.0.7}"
bundle exec fastlane metadata_upload
