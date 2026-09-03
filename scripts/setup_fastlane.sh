#!/usr/bin/env bash
# Use Homebrew Ruby + Bundler for fastlane (avoids macOS system Ruby 2.6).
set -euo pipefail

if [ -x /opt/homebrew/opt/ruby/bin/ruby ]; then
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
elif [ -x /usr/local/opt/ruby/bin/ruby ]; then
  export PATH="/usr/local/opt/ruby/bin:$PATH"
else
  echo "Homebrew Ruby not found. Install with: brew install ruby" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "ruby:   $(command -v ruby) ($(ruby --version))"
echo "bundle: $(command -v bundle) ($(bundle --version))"

if ! bundle --version | grep -qE 'Bundler version [34]\.'; then
  echo "Installing Bundler 4.x..."
  gem install bundler --no-document
fi

bundle install
echo
echo "Done. Next:"
echo "  export APP_STORE_CONNECT_API_KEY_PATH=\"\$HOME/.appstoreconnect/portfolio-api-key.json\""
echo "  bundle exec fastlane metadata_validate"
