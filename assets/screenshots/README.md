# App Store Screenshots

## Required Sizes

### iOS Screenshots

| Device | Size (Portrait) | Notes |
|--------|-----------------|-------|
| **6.9" (iPhone 16 Pro Max)** | 1290 x 2796 | Required - highest res scales down |
| 6.5" (iPhone 14 Plus) | 1284 x 2778 | Optional - auto-scaled from 6.9" |
| 6.1" (iPhone 16) | 1170 x 2532 | Optional |
| 5.5" (iPhone 8 Plus) | 1242 x 2208 | Optional |

### iPad Screenshots (if supporting iPad)

| Device | Size (Portrait) | Notes |
|--------|-----------------|-------|
| **13" iPad Pro** | 2064 x 2752 | Required for iPad |
| 11" iPad | 1668 x 2420 | Optional |

### macOS Screenshots

| Resolution | Notes |
|------------|-------|
| **2880 x 1800** | Recommended (15" Retina) |
| 2560 x 1600 | Alternative (13" Retina) |
| 1440 x 900 | Minimum |

## Screenshot Naming Convention

```
ios-6.9-01-dashboard-hero.png
ios-6.9-02-dashboard-quadrants.png
ios-6.9-03-dashboard-accounts.png
ios-6.9-04-positions.png
ios-6.9-05-instruments.png
ios-6.9-06-settings.png

macos-01-dashboard.png
macos-02-holdings.png
macos-03-instruments.png
macos-04-reports.png
```

## Capture Instructions

### iOS

1. Boot iPhone 16 Pro Max simulator
2. Build and run Portfolio iOS from Xcode
3. Unlock with Touch ID (Simulator > Features > Touch ID > Matching Touch)
4. Run: `./scripts/capture_appstore_screenshots.sh`

### macOS

1. Build and run Portfolio macOS from Xcode
2. Resize window to desired size
3. Capture: `screencapture -w assets/screenshots/appstore/macos-01-dashboard.png`

## Tips for Great Screenshots

- Use **light mode** for main screenshots (more readable)
- Include **sample data** that shows app functionality
- Enable **Demo Mode** to hide real financial data
- Capture during **daytime hours** (status bar looks cleaner)
- Consider adding **marketing frames** around screenshots using tools like:
  - [AppMockUp](https://app-mockup.com)
  - [Screenshots Pro](https://screenshots.pro)
  - Figma/Sketch templates
