#!/bin/sh
# Xcode Cloud — runs after clone. Writes Local.xcconfig, installs Ruby gems, and optional ASC API key.
set -e

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

# Create a stub Local.xcconfig so Xcode Cloud does not error on the missing file reference.
echo "// CI build - no local overrides" > "$REPO_ROOT/Local.xcconfig"

if [ "${UPLOAD_APP_STORE_METADATA:-0}" != "1" ]; then
  echo "UPLOAD_APP_STORE_METADATA is not 1 — skipping fastlane install."
  exit 0
fi

echo "=== ci_post_clone: App Store metadata setup ==="

# Prefer Homebrew Ruby on Xcode Cloud macOS images (system Ruby 2.6 is too old for fastlane).
if [ -x /opt/homebrew/opt/ruby/bin/ruby ]; then
  export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"
elif [ -x /usr/local/opt/ruby/bin/ruby ]; then
  export PATH="/usr/local/opt/ruby/bin:/usr/local/lib/ruby/gems/3.3.0/bin:$PATH"
fi

ruby --version
gem install bundler --no-document
bundle config set path 'vendor/bundle'
bundle install --jobs 4 --retry 3

# Write API key JSON from Xcode Cloud workflow secrets (Environment variables).
if [ -n "${APP_STORE_CONNECT_KEY_ID:-}" ] && [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ] && [ -n "${APP_STORE_CONNECT_KEY_CONTENT:-}" ]; then
  KEY_DIR="$REPO_ROOT/.xcode-cloud"
  mkdir -p "$KEY_DIR"
  KEY_FILE="$KEY_DIR/AuthKey.p8"
  JSON_FILE="$KEY_DIR/api_key.json"
  printf '%s' "$APP_STORE_CONNECT_KEY_CONTENT" > "$KEY_FILE"
  ruby -rjson -e "File.write('$JSON_FILE', JSON.pretty_generate({key_id: ENV['APP_STORE_CONNECT_KEY_ID'], issuer_id: ENV['APP_STORE_CONNECT_ISSUER_ID'], key_filepath: '$KEY_FILE', duration: 1200, in_house: false}))"
  export APP_STORE_CONNECT_API_KEY_PATH="$JSON_FILE"
  echo "App Store Connect API key configured."
else
  echo "No App Store Connect API key env vars — metadata upload will be skipped."
fi
