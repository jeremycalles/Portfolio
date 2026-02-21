#!/bin/bash

# iOS English Screenshot Capture Script
# Run this in Terminal to capture App Store screenshots in English

set -e

UDID="DF25E1D7-C267-4CA6-A402-F064711DDE43"
SCREENSHOTS_DIR="$HOME/github/PortfolioMultiplatform/assets/screenshots"

echo "=============================================="
echo "    iOS English Screenshot Capture"
echo "=============================================="
echo ""
echo "Simulator: iPhone 14 Plus EN"
echo "Resolution: 1284x2778 → resize to 1242x2688"
echo "Output: $SCREENSHOTS_DIR"
echo ""

# Check if simulator is booted
if ! xcrun simctl list devices | grep "$UDID" | grep -q "Booted"; then
    echo "Booting simulator..."
    xcrun simctl boot "$UDID" 2>/dev/null || true
    open -a Simulator
    sleep 5
fi

echo "=============================================="
echo "IMPORTANT: Unlock the app first!"
echo ""
echo "  Simulator menu: Features → Touch ID → Matching Touch"
echo "=============================================="
echo ""

read -p "Press Enter when app is UNLOCKED and showing DASHBOARD (hero card)..."
xcrun simctl io "$UDID" screenshot "$SCREENSHOTS_DIR/ios-1-dashboard.png"
echo "✓ Captured: ios-1-dashboard.png"
echo ""

read -p "Scroll down to show QUADRANTS section, press Enter..."
xcrun simctl io "$UDID" screenshot "$SCREENSHOTS_DIR/ios-2-dashboard-quadrants.png"
echo "✓ Captured: ios-2-dashboard-quadrants.png"
echo ""

read -p "Scroll down to show ACCOUNTS section, press Enter..."
xcrun simctl io "$UDID" screenshot "$SCREENSHOTS_DIR/ios-3-dashboard-accounts.png"
echo "✓ Captured: ios-3-dashboard-accounts.png"
echo ""

read -p "Tap QUADRANTS tab, press Enter..."
xcrun simctl io "$UDID" screenshot "$SCREENSHOTS_DIR/ios-4-quadrants.png"
echo "✓ Captured: ios-4-quadrants.png"
echo ""

read -p "Tap POSITIONS tab, press Enter..."
xcrun simctl io "$UDID" screenshot "$SCREENSHOTS_DIR/ios-5-positions.png"
echo "✓ Captured: ios-5-positions.png"
echo ""

echo "=============================================="
echo "Resizing screenshots to 1242x2688..."
echo "=============================================="

cd "$SCREENSHOTS_DIR"
for f in ios-1-dashboard.png ios-2-dashboard-quadrants.png ios-3-dashboard-accounts.png ios-4-quadrants.png ios-5-positions.png; do
    if [ -f "$f" ]; then
        sips -z 2688 1242 "$f" --out "$f" 2>/dev/null
        echo "✓ Resized: $f"
    fi
done

echo ""
echo "=============================================="
echo "Done! Final screenshots:"
echo "=============================================="
echo ""
file ios-*.png | grep -v appstore | grep -v README
echo ""
echo "Screenshots are ready for App Store submission!"
