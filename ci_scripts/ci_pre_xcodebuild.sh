#!/bin/sh
# Xcode Cloud — runs before xcodebuild. Optionally uploads App Store metadata.
set -e

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

if [ "${UPLOAD_APP_STORE_METADATA:-0}" != "1" ]; then
  echo "UPLOAD_APP_STORE_METADATA is not 1 — skipping metadata upload."
  exit 0
fi

# Combined iOS+macOS workflows run this script before every action; upload once per build.
LOCK_DIR="$REPO_ROOT/.xcode-cloud"
mkdir -p "$LOCK_DIR"
LOCK_FILE="$LOCK_DIR/metadata-uploaded"
if [ -f "$LOCK_FILE" ]; then
  echo "App Store metadata already uploaded in this Xcode Cloud run — skipping."
  exit 0
fi

# post_clone writes this file; Xcode Cloud does not keep shell exports between scripts.
if [ -z "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]; then
  APP_STORE_CONNECT_API_KEY_PATH="$REPO_ROOT/.xcode-cloud/api_key.json"
fi
export APP_STORE_CONNECT_API_KEY_PATH

if [ ! -f "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
  echo "error: App Store Connect API key missing. Set APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, and APP_STORE_CONNECT_KEY_CONTENT on the Xcode Cloud workflow." >&2
  exit 1
fi

if [ -x /opt/homebrew/opt/ruby/bin/ruby ]; then
  export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"
elif [ -x /usr/local/opt/ruby/bin/ruby ]; then
  export PATH="/usr/local/opt/ruby/bin:/usr/local/lib/ruby/gems/3.3.0/bin:$PATH"
fi

export BUNDLE_PATH="${BUNDLE_PATH:-$REPO_ROOT/vendor/bundle}"

# Marketing version from Xcode project (Info.plist uses $(MARKETING_VERSION)).
if [ -z "${APP_VERSION:-}" ]; then
  APP_VERSION="$(grep -m1 'MARKETING_VERSION = ' "$REPO_ROOT/PortfolioMultiplatform.xcodeproj/project.pbxproj" | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/' | tr -d ' ')"
fi
export APP_VERSION="${APP_VERSION:-1.0.6}"

echo "=== ci_pre_xcodebuild: uploading App Store metadata for version $APP_VERSION ==="
python3 scripts/validate_app_store_metadata.py
bundle exec fastlane metadata_upload
touch "$LOCK_FILE"
touch "$LOCK_FILE"
