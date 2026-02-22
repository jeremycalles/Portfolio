# App Store Screenshots

## Required Sizes

### iOS Screenshots

| Device | Size (Portrait) | Notes |
|--------|-----------------|-------|
| **6.5" (iPhone 14 Plus, XS Max)** | 1242 x 2688 | **Current screenshots** |
| 6.9" (iPhone 16 Pro Max) | 1290 x 2796 | Auto-scales from 6.5" |
| 6.1" (iPhone 16) | 1170 x 2532 | Auto-scales |
| 5.5" (iPhone 8 Plus) | 1242 x 2208 | Different aspect ratio |

### iPad Screenshots (if supporting iPad)

| Device | Size (Portrait) | Size (Landscape) | Notes |
|--------|-----------------|------------------|-------|
| **13" iPad Pro** | **2064 x 2752** | **2752 x 2064** | **Required** — App Store will block submission without this |
| 11" iPad | 1668 x 2420 | 2420 x 1668 | Optional |

### macOS Screenshots

| Resolution | Notes |
|------------|-------|
| **2880 x 1800** | Recommended (15" Retina) |
| 2560 x 1600 | Alternative (13" Retina) |
| 1440 x 900 | Minimum |

## Screenshot Naming Convention

```
# 13-inch iPad (required)
ipad-13-dashboard.png
ipad-13-holdings.png
ipad-13-instruments.png

ios-6.9-01-dashboard-hero.png
ios-6.9-02-dashboard-quadrants.png
...

macos-01-dashboard.png
macos-02-holdings.png
...
```

## Capture Instructions

### 13-inch iPad (required for App Store if app runs on iPad)

App Store Connect requires at least one screenshot at **2064 x 2752** (portrait) or **2752 x 2064** (landscape).

**Option A — Simulator (recommended)**

1. In Xcode, choose **Portfolio iOS** scheme and set destination to **iPad Pro 13-inch (M4)** or **iPad Pro 12.9-inch (6th generation)**.
2. Run the app (⌘R). Unlock if needed: **Simulator → Features → Touch ID → Matching Touch**.
3. Open the screen you want (e.g. Dashboard).
4. In Simulator: **File → Save Screen** (or ⌘S). The screenshot is saved to your Desktop.
5. If the saved image is not exactly 2064 x 2752, resize it:
   ```bash
   ./scripts/resize_ipad_screenshot.sh ~/Desktop/Simulator\ Screen\ Shot*.png assets/screenshots/ipad-13-dashboard.png
   ```
   Or with macOS `sips`:
   ```bash
   sips -z 2752 2064 --out assets/screenshots/ipad-13-dashboard.png "/path/to/your/screenshot.png"
   ```
6. Upload `ipad-13-dashboard.png` (or your filename) in App Store Connect under **App Store → 13" Display** for your iPad app.

**Option B — Resize an existing screenshot**

If you already have an iPad screenshot (e.g. 2048 x 2732 from an older simulator):

```bash
./scripts/resize_ipad_screenshot.sh /path/to/your.png assets/screenshots/ipad-13-portrait.png
```

### iOS (iPhone)

1. Boot iPhone 16 Pro Max simulator
2. Build and run Portfolio iOS from Xcode
3. Unlock with Touch ID (Simulator > Features > Touch ID > Matching Touch)
4. Capture screens as needed (File → Save Screen in Simulator)

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
