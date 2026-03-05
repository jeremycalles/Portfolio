#!/bin/sh
set -e

# Create a stub Local.xcconfig so Xcode Cloud does not error on the missing file reference.
echo "// CI build - no local overrides" > "$CI_PRIMARY_REPOSITORY_PATH/Local.xcconfig"
