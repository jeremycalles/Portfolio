#!/bin/bash

# App Store Screenshot Capture Script
# Captures screenshots at required resolutions for App Store

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$PROJECT_DIR/assets/screenshots/appstore"

mkdir -p "$SCREENSHOTS_DIR"

echo "=============================================="
echo "     App Store Screenshot Capture Tool"
echo "=============================================="
echo ""
echo "Screenshots will be saved to:"
echo "  $SCREENSHOTS_DIR"
echo ""

# Get iPhone 16 Pro Max UUID
IPHONE_UDID=$(xcrun simctl list devices available | grep "iPhone 16 Pro Max" | head -1 | grep -oE "[A-F0-9-]{36}")

if [ -z "$IPHONE_UDID" ]; then
    echo "ERROR: iPhone 16 Pro Max simulator not found"
    echo "Please install it via Xcode > Settings > Platforms"
    exit 1
fi

echo "Using: iPhone 16 Pro Max ($IPHONE_UDID)"
echo ""

# Check if simulator is booted
BOOT_STATUS=$(xcrun simctl list devices | grep "$IPHONE_UDID" | grep -o "(Booted)" || true)
if [ -z "$BOOT_STATUS" ]; then
    echo "Booting simulator..."
    xcrun simctl boot "$IPHONE_UDID" 2>/dev/null || true
    sleep 5
fi

# Open Simulator
open -a Simulator

# Set light mode
xcrun simctl ui "$IPHONE_UDID" appearance light

echo ""
echo "=============================================="
echo "            CAPTURE INSTRUCTIONS"
echo "=============================================="
echo ""
echo "BEFORE CAPTURING:"
echo "  1. Make sure the app is running"
echo "  2. Unlock with Touch ID (Simulator > Features > Touch ID > Matching Touch)"
echo "  3. If no data exists, add sample holdings first"
echo ""
echo "REQUIRED SCREENSHOTS (6.9\" - 1290x2796):"
echo "  1. Dashboard - Hero card with portfolio value"
echo "  2. Dashboard - Quadrants allocation chart"
echo "  3. Dashboard - Accounts breakdown"
echo "  4. Positions - Holdings list"
echo "  5. Instruments - Price chart visible"
echo "  6. Settings (optional)"
echo ""
echo "=============================================="
echo ""

capture() {
    local name=$1
    local filename="ios-6.9-$name.png"
    xcrun simctl io "$IPHONE_UDID" screenshot "$SCREENSHOTS_DIR/$filename"
    echo "✓ Captured: $filename"
}

# Interactive capture
read -p "Ready? Navigate to DASHBOARD (hero card) and press Enter: "
capture "01-dashboard-hero"

read -p "Scroll to QUADRANTS section, press Enter: "
capture "02-dashboard-quadrants"

read -p "Scroll to ACCOUNTS section, press Enter: "
capture "03-dashboard-accounts"

read -p "Navigate to POSITIONS tab, press Enter: "
capture "04-positions"

read -p "Navigate to INSTRUMENTS tab (with chart), press Enter: "
capture "05-instruments"

read -p "Navigate to SETTINGS tab (optional), press Enter or Ctrl+C to skip: "
capture "06-settings"

echo ""
echo "=============================================="
echo "              iOS SCREENSHOTS DONE"
echo "=============================================="
echo ""
ls -la "$SCREENSHOTS_DIR"/ios-*.png 2>/dev/null
echo ""

echo "=============================================="
echo "            macOS SCREENSHOTS"
echo "=============================================="
echo ""
echo "For macOS (2880x1800 or window capture):"
echo "  1. Run 'Portfolio macOS' from Xcode"
echo "  2. Resize window as needed"
echo "  3. Use these commands to capture:"
echo ""
echo "  # Capture frontmost window:"
echo "  screencapture -w $SCREENSHOTS_DIR/macos-01-dashboard.png"
echo ""
echo "  # Or specific window by clicking:"
echo "  screencapture -W $SCREENSHOTS_DIR/macos-screenshot.png"
echo ""
echo "Recommended macOS screenshots:"
echo "  - macos-01-dashboard.png"
echo "  - macos-02-holdings.png"
echo "  - macos-03-instruments.png"
echo "  - macos-04-reports.png"
echo ""
