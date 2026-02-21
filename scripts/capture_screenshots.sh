#!/bin/bash

# App Store Screenshot Capture Script
# Run this AFTER building and installing the app via Xcode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$PROJECT_DIR/assets/screenshots/appstore"

# Create screenshots directory
mkdir -p "$SCREENSHOTS_DIR"

echo "=== App Store Screenshot Capture ==="
echo ""
echo "This script captures screenshots for App Store submission."
echo "Screenshots will be saved to: $SCREENSHOTS_DIR"
echo ""

# Check for available simulators
echo "Available iPhone simulators:"
xcrun simctl list devices available | grep -E "iPhone (16 Pro Max|15 Pro Max)" | head -5
echo ""

# Find iPhone 16 Pro Max
IPHONE_UDID=$(xcrun simctl list devices available | grep "iPhone 16 Pro Max" | head -1 | grep -oE "[A-F0-9-]{36}")

if [ -z "$IPHONE_UDID" ]; then
    echo "Error: iPhone 16 Pro Max simulator not found"
    exit 1
fi

echo "Using iPhone 16 Pro Max: $IPHONE_UDID"
echo ""

# Boot simulator if not booted
BOOT_STATUS=$(xcrun simctl list devices | grep "$IPHONE_UDID" | grep -o "(Booted)" || true)
if [ -z "$BOOT_STATUS" ]; then
    echo "Booting iPhone 16 Pro Max simulator..."
    xcrun simctl boot "$IPHONE_UDID"
    sleep 5
fi

# Open Simulator app
open -a Simulator

echo ""
echo "=== INSTRUCTIONS ==="
echo ""
echo "1. Build and run the app from Xcode (Cmd+R) with scheme 'Portfolio iOS'"
echo "2. The app should launch in the iPhone 16 Pro Max simulator"
echo "3. When ready, come back here and press Enter for each screenshot"
echo ""
echo "Required screenshots for App Store (6.9\" display - 1290 x 2796 pixels):"
echo "  1. Dashboard - Portfolio summary with hero card"
echo "  2. Dashboard - Quadrants allocation view"  
echo "  3. Dashboard - Accounts breakdown"
echo "  4. Positions - Holdings list"
echo "  5. Instruments - With price chart"
echo "  6. Settings - App preferences"
echo ""

capture_screenshot() {
    local name=$1
    local filename="ios-6.9-$name.png"
    echo "Capturing: $filename"
    xcrun simctl io "$IPHONE_UDID" screenshot "$SCREENSHOTS_DIR/$filename"
    echo "  Saved: $SCREENSHOTS_DIR/$filename"
}

read -p "Press Enter when app is running and showing DASHBOARD (hero card)..."
capture_screenshot "01-dashboard-hero"

read -p "Press Enter when showing DASHBOARD with QUADRANTS section visible..."
capture_screenshot "02-dashboard-quadrants"

read -p "Press Enter when showing DASHBOARD with ACCOUNTS section visible..."
capture_screenshot "03-dashboard-accounts"

read -p "Press Enter when on POSITIONS tab..."
capture_screenshot "04-positions"

read -p "Press Enter when on INSTRUMENTS tab with a price chart visible..."
capture_screenshot "05-instruments"

read -p "Press Enter when on SETTINGS tab..."
capture_screenshot "06-settings"

echo ""
echo "=== iOS Screenshots Complete ==="
echo ""
echo "Files saved:"
ls -la "$SCREENSHOTS_DIR"/ios-*.png 2>/dev/null || echo "No screenshots found"

echo ""
echo "=== macOS Screenshots ==="
echo ""
echo "For macOS screenshots (2880 x 1800 pixels recommended):"
echo "1. Run the macOS app from Xcode (select 'Portfolio macOS' scheme)"
echo "2. Resize window to desired dimensions"
echo "3. Use Cmd+Shift+4, then press Space to capture the window"
echo "4. Save as:"
echo "   - macos-01-dashboard.png"
echo "   - macos-02-holdings.png"
echo "   - macos-03-instruments.png"
echo "   - macos-04-reports.png"
echo ""
echo "Or use this command to capture the frontmost window:"
echo "  screencapture -w $SCREENSHOTS_DIR/macos-screenshot.png"
echo ""
