# PortfolioMultiplatform - Portfolio Tracker

[![License: PolyForm Noncommercial](https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/Platform-iOS-blue)](https://developer.apple.com/ios/)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-blue)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange)](https://swift.org)

**PortfolioMultiplatform** is a privacy-focused portfolio tracker for stocks, ETFs, mutual funds, precious metals, cryptocurrencies, and bank accounts—with native iOS and macOS apps built from a **single shared codebase**.

### What matters most

- **Your data stays on your device** — Local SQLite only; no backend, no telemetry. You can back up the database to your iCloud; the app always uses local storage.
- **One codebase, two native apps** — Shared logic (models, services, view models, UI components) in `Shared/`; each platform adds its own layout and lifecycle.
- **Public APIs only for prices** — Refreshes request public market data (tickers/ISINs); no account linking or PII.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Supported Asset Types](#supported-asset-types)
- [Getting Started](#getting-started)
- [User Guide](#user-guide)
- [Data Sources](#data-sources)
- [Privacy & Security](#privacy--security)
- [Automation](#automation)
- [Development](#development)
- [Secrets and local config](#secrets-and-local-config)
- [Publishing to the App Store](#publishing-to-the-app-store)
- [License](#license)

---

## Overview

Consolidate all your financial assets into one view: track stocks, ETFs, mutual funds, gold, crypto, and bank accounts with accurate data (NAV for funds, market premiums for physical metals), multi-currency conversion, and offline access.

### Screenshots

#### macOS

<img src="assets/screenshots/macos-dashboard.png" width="800" />

#### iOS

<p float="left">
  <img src="assets/screenshots/ios-1-dashboard.png" width="200" />
  <img src="assets/screenshots/ios-2-dashboard-quadrants.png" width="200" />
  <img src="assets/screenshots/ios-3-dashboard-accounts.png" width="200" />
  <img src="assets/screenshots/ios-4-quadrants.png" width="200" />
  <img src="assets/screenshots/ios-5-positions.png" width="200" />
</p>

---

## Key Features

### Portfolio Management
- **Multi-Account Support**: Track holdings across multiple bank accounts and brokers
- **Cost Basis Tracking**: Record purchase dates and prices for accurate gain/loss calculations
- **Quadrant Organization**: Group instruments by category (Technology, Precious Metals, Fixed Income, etc.)

### Analytics & Reporting
- **Performance Comparison**: Compare your portfolio over different periods (1 day, 1 week, 1 month, 1 year, YTD)
- **Interactive Charts**: View portfolio trends, allocation breakdowns, and individual instrument price history
- **Gold Valuation**: See your portfolio value in gold ounces for inflation-adjusted perspective

### Data Management
- **Smart Fetching**: Automatically selects the best data source for each instrument type
- **Historical Backfilling**: Import years of historical data for comprehensive trend analysis
- **Background Updates**: Automatic price updates on macOS and iOS

### User Experience
- **Privacy Mode**: Hide sensitive values on screen (eye icon); data stays local
- **Face ID / Touch ID protection (iOS and macOS)**: Optionally require Face ID, Touch ID, or device password to access the dashboard. On iOS the app also locks when you leave the app; on both platforms it locks after 5 minutes of inactivity. Toggle in Settings.
- **Bilingual**: Full English and French localization
- **Native SwiftUI**: One shared codebase for iOS and macOS; platform-appropriate UI and navigation

---

## Supported Asset Types

| Asset Type | Examples | Data Source | Notes |
|------------|----------|-------------|-------|
| **Stocks** | Apple (AAPL), Tesla (TSLA) | Yahoo Finance | Real-time market prices |
| **ETFs** | MSCI World, S&P 500 | Yahoo Finance | Exchange-traded funds |
| **Mutual Funds (OPCVMs)** | Amundi, Carmignac | Financial Times | Accurate NAV from Morningstar |
| **Cryptocurrencies** | Bitcoin, Ethereum | Yahoo Finance | Major crypto pairs |
| **Precious Metals** | Gold, Silver | Veracash | Spot prices in EUR/gram |
| **Gold & Silver Coins** | Napoléon, Vera Max | AuCOFFRE | Includes market premiums |
| **Bank Accounts** | Manual entry | N/A | Cash position tracking |

### Special Instrument Types

#### Precious Metals (Veracash)
Track spot prices for gold and silver per gram in EUR:
- `VERACASH:GOLD_SPOT` - Gold spot price
- `VERACASH:GOLD_PREMIUM` - Gold premium price
- `VERACASH:SILVER_SPOT` - Silver spot price

#### Physical Coins (AuCOFFRE)
Physical coins include market premiums that vary based on demand:
- `COIN:NAPOLEON_20F` - Napoléon 20F Marianne Coq (~5.8g pure gold)
- `COIN:VERAMAX_GOLD_1/10OZ` - Vera Max 1/10 oz gold
- `COIN:GECKO_SILVER_1OZ` - Vera Silver Gecko 1 oz (no longer in AuCOFFRE catalog; app uses **Vera Silver 1 once** price as an estimate and shows “(est. Vera Silver 1 oz)” in the UI)
- `COIN:GOLD_BAR_1OZ` - Gold bar 1 oz (spot estimate)

---

## Getting Started

### iOS & macOS App

The native SwiftUI application provides the best experience for tracking your portfolio.

#### System Requirements
- **iOS**: iOS 17.0 or later (iPhone and iPad)
- **macOS**: macOS 14.0 Sonoma or later

#### Installation from Xcode

1. Clone the repository:
   ```bash
   git clone https://github.com/jeremycalles/Portfolio.git
   cd Portfolio
   ```

2. Open the Xcode project:
   ```bash
   open PortfolioMultiplatform.xcodeproj
   ```

3. Select your target:
   - **Portfolio iOS** for iPhone/iPad
   - **Portfolio macOS** for Mac

4. Build and run (`Cmd+R`)

#### First Launch

When you first launch PortfolioMultiplatform:
1. The app creates a local SQLite database for your data
2. Your preferred language is detected from system settings
3. You can start adding instruments and bank accounts immediately


## User Guide

The following describes how to use the app. All actions are done in the native iOS or macOS interface.

### Dashboard

The Dashboard is your portfolio command center, providing an instant overview of your financial position.

#### Portfolio Summary
At the top, you'll see:
- **Total Portfolio Value**: Sum of all holdings converted to EUR
- **Gold Equivalent**: Your portfolio value expressed in gold ounces (using current spot price)
- **Period Change**: Percentage change compared to your selected comparison period

#### Comparison Periods
Use the period selector to compare your portfolio against:
- **1 Day**: Yesterday's closing values
- **1 Week**: Values from 7 days ago
- **1 Month**: Values from 30 days ago
- **1 Year**: Values from 365 days ago
- **YTD (Year-to-Date)**: Values from January 1st

#### Portfolio Chart
The interactive chart shows your portfolio value over time:
- **Line Chart**: Track the trend of your total portfolio value
- **Time Ranges**: 1M, 3M, 6M, YTD, 1Y, 2Y, All
- **Gold Mode**: Toggle to view values in gold ounces instead of EUR

#### Allocation Views
Switch between different allocation perspectives:
- **By Quadrant**: See how your portfolio is distributed across asset categories
- **By Account**: View allocation across your bank accounts
- **By Holdings**: Individual instrument breakdown

#### Privacy Mode
Toggle the eye icon to hide sensitive values. The app remains fully functional but displays masked values—useful when viewing in public.

---

### Managing Instruments

Instruments are the financial assets you want to track (stocks, ETFs, funds, etc.).

#### Adding Instruments

1. Navigate to **Instruments** (macOS sidebar) or the instruments tab (iOS).
2. Tap the **+** button and enter:
   - **ISIN** (12 characters), e.g. `LU0389656892` for mutual funds
   - **Ticker**, e.g. `AAPL`, `BTC-EUR`
   - **Special key**, e.g. `VERACASH:GOLD_SPOT`, `COIN:NAPOLEON_20F`

#### Viewing Instrument Details

Click (macOS) or tap (iOS) on any instrument row to open its detail view. On iOS the full row is tappable. You can then view:
- **Current Price**: Latest fetched price with currency
- **Price History**: Historical prices in table or chart format
- **Assigned Quadrant**: Category grouping
- **Holdings**: Which accounts hold this instrument
- **Edit**: Use the Edit button (toolbar on iOS, sheet on macOS) to change name, ticker, or currency

#### Deleting Instruments

**Important:** Deleting an instrument removes all associated price history and holdings.

1. Select the instrument
2. Click/tap the delete button (trash icon)
3. Confirm the deletion

---

### Bank Accounts & Holdings

Track your investments across multiple brokers and accounts.

#### Adding Bank Accounts

1. Open **Accounts**, tap **+**, then enter bank name and account name (e.g. "TradeRepublic", "CTO").

#### Adding Holdings

1. Open **Holdings** (macOS sidebar or iOS tab), tap **+**, then choose account, instrument, quantity, and optionally purchase date/price.

#### Editing Holdings

Update quantity or purchase details for any holding:
- **iOS**: Tap a holding row on the **Holdings** screen. The full row is tappable; the edit screen opens with quantity and optional purchase info. Save or Cancel.
- **macOS**: Click a holding row in **Holdings** or **All Holdings**. The row shows a pencil icon next to the units to indicate it is editable. An Edit Holding sheet opens; change quantity and optionally include purchase date/price, then Save (⌘↵) or Cancel (Esc).

#### Viewing Holdings

The Holdings view shows:
- **Grouped by Account**: See all instruments in each account
- **Current Value**: Quantity × current price
- **Gain/Loss**: If purchase data is recorded, see unrealized gains

#### All Holdings View

Access the consolidated view to see:
- All holdings across all accounts
- Total portfolio value
- Expandable account sections  
- **Edit**: Click (macOS) or tap (iOS) any holding row to open the same Edit Holding flow as above.

---

### Quadrants (Portfolio Organization)

Quadrants help you categorize and analyze your portfolio by asset type or strategy.

#### Creating Quadrants

Suggested quadrant categories:
- **Technology**: Tech stocks and ETFs
- **Precious Metals**: Gold, silver, and coins
- **Fixed Income**: Bonds and money market funds
- **International**: Emerging markets and foreign stocks
- **Real Estate**: REITs and real estate funds

1. Open **Quadrants**, tap **+**, and enter a name (e.g. "Technology", "Precious Metals").
2. Assign instruments via the instrument detail: choose a quadrant from the picker.

#### Quadrant Reports

View your portfolio grouped by quadrant:
- Subtotal value per quadrant
- Percentage of total portfolio
- Performance change per quadrant
- Pie chart visualization

---

### Reports & Analytics

#### Portfolio Report

The Portfolio Report shows detailed analysis of your holdings:

| Column | Description |
|--------|-------------|
| Instrument | Name and identifier |
| Quantity | Units held |
| Current Price | Latest price |
| Current Value | Quantity × price in EUR |
| Change | Percentage change vs comparison period |

**Comparison periods:** 1 Day, 1 Week, 1 Month, 1 Year, YTD.

#### Quadrant Report

Portfolio grouped by category: subtotals per quadrant, change percentages, grand total, and unassigned instruments.

#### Price Graphs

Interactive charts for individual instruments:
- **Time Ranges**: 1M, 3M, 6M, YTD, 1Y, 2Y, All
- **Statistics**: Min, Max, Average, Data Points
- **Smooth Curves**: Catmull-Rom interpolation for better visualization

---

### Price Management

#### Automatic Updates

- **Manual refresh**: Settings → Update All Prices (or toolbar on macOS).
- **Background**: macOS Launch Agent or iOS Background Tasks (see [Automation](#automation)).

#### Historical Backfilling

Settings → Backfill Historical Data; choose period (1Y, 2Y, 5Y). Menu commands on macOS also offer 1Y/2Y/5Y backfill.

#### Manual Price Entry

For instruments without automatic data sources:
1. Navigate to **Price History**
2. Select the instrument
3. Click/tap **+** to add a new price
4. Enter date and price value

---

### Settings & Preferences

- **iOS**: Open the **Settings** tab in the tab bar.
- **macOS**: Use the application menu **PortfolioMultiplatform** → **Settings** (or press ⌘,). All preferences (General, Language, Database, Background Refresh) are in this window; there is no Settings item in the main window sidebar.

#### Face ID / Touch ID Protection (iOS and macOS)

In **Settings** → **Touch ID Protection**, enable or disable requiring Face ID (iPhone/iPad), Touch ID, or device password to view the dashboard. When enabled, the app shows a lock screen on launch. On iOS it also locks when you switch to another app; on both platforms it locks again after 5 minutes of inactivity.

#### Language

Switch between English and French:
1. Go to **Settings**
2. Select **Language**
3. Choose your preferred language

The app updates immediately without restart.

#### Database & Backup

- The database is stored **locally** only (no option to store it in iCloud). You can use **Backup to iCloud now** in Settings to copy the database file to your iCloud container; the app never opens the database from iCloud.
- **iOS**: Database path is shown in Settings; use Import/Export to transfer between devices.
- **macOS**: You can open the database folder from Settings (Database → Open in Finder).

#### Background Refresh (macOS)

On first launch, the app offers to enable automatic price updates. You can accept, decline, or check **"Don't ask again"** to dismiss the prompt permanently. You can always enable or disable automatic refresh later from Settings.

To configure manually:
1. Go to **Settings** → **Background Refresh**
2. Choose an interval (1 hour, 3 hours, 6 hours, or 12 hours)
3. Click **Enable** to install the Launch Agent and start the in-app timer

The scheduler works in two complementary ways:
- **Launch Agent**: A system-level `launchd` plist (`~/Library/LaunchAgents/com.portfolio.app.pricerefresh.plist`) triggers the app via a `portfolio://refresh` URL scheme at the configured interval — even when the app is not in the foreground.
- **In-app Timer**: A repeating timer refreshes prices while the app is running, providing seamless updates without the Launch Agent.

Logs are written to `~/Library/Logs/PortfolioApp/refresh.log` and can be viewed directly in the Settings panel or opened in Finder.

#### Background Tasks (iOS)

iOS automatically refreshes prices in the background when the system allows. View refresh logs in Settings to monitor update status.

---

## Data Sources

PortfolioMultiplatform uses multiple data sources to ensure accurate pricing:

| Source | Assets | Data Type |
|--------|--------|-----------|
| **Yahoo Finance** | Stocks, ETFs, Crypto | Real-time prices, historical data |
| **Financial Times** | Mutual Funds | NAV from Morningstar |
| **Veracash** | Gold, Silver | Spot prices in EUR/gram |
| **AuCOFFRE** | Physical Coins | Prices with market premiums |

### Why Multiple Sources?

- **Mutual Funds**: Exchange prices are often stale due to low liquidity. Financial Times provides accurate NAV (Net Asset Value) from Morningstar.
- **Physical Coins**: Unlike spot prices, coins trade with premiums that vary based on demand, rarity, and market conditions. AuCOFFRE provides real-time market prices including these premiums.

---

## Privacy & Security

### Privacy-first design

PortfolioMultiplatform is built so that **your data never leaves your control**:

- **No server for your data**: There is no backend or cloud service that stores your portfolio. All positions, accounts, instruments, and price history live only on your device.
- **No personal data sent**: The app does not send any personally identifiable information or portfolio contents to any third party. No telemetry, analytics, or crash reporting.
- **Local storage only**: A single SQLite database in the app’s container (path shown in Settings). Preferences (language, privacy mode) are in `UserDefaults` on device only.
- **iCloud backup**: You can back up the database to your iCloud (Settings → Backup to iCloud now). The app copies the local file to your iCloud container; it never opens or runs the database from iCloud. No data is sent to the app developer or any other server.

### What leaves your device (market data only)

When you refresh prices, the app requests **public market data** from public APIs (Yahoo Finance, Financial Times, Veracash, AuCOFFRE). Only instrument identifiers (e.g. ticker symbols, ISINs) are sent to fetch prices; no portfolio structure, holdings quantities, or personal details are included. This is the same as opening a financial website in a browser.

### Access protection (iOS and macOS)

On **iOS** and **macOS** you can enable **Touch ID Protection** (Face ID on iPhone/iPad) in Settings so that the dashboard is hidden until you authenticate. On iOS the app also locks when you leave it (e.g. switch app or go home); on both platforms it locks again after 5 minutes of inactivity. Turn this on or off in **Settings** → **Touch ID Protection**.

### Data you control

- **Export, backup, delete**: You can copy, move, or delete the database file at any time. On macOS you can choose the project/data path; on iOS the database lives in the app container.
- **Privacy mode**: Toggle with the eye icon to hide all monetary values on screen; state is stored locally only. Perfect for public viewing.

---

## Automation

### macOS Launch Agent

The app manages a proper Launch Agent for automatic background updates:
1. Open **Settings** → **Background Refresh**
2. Select your preferred interval (1h, 3h, 6h, or 12h)
3. Click **Enable** to generate and install the plist

The Launch Agent runs `/usr/bin/open -g portfolio://refresh` at the configured interval. This opens the app in the background (or sends the URL to the running instance) and triggers a full price refresh — instruments, exchange rates, and benchmarks (S&P 500, Gold, MSCI World). The plist is written to `~/Library/LaunchAgents/com.portfolio.app.pricerefresh.plist` and managed via `launchctl`. Changing the interval automatically reinstalls the agent with the new schedule.

### iOS Background Refresh

iOS uses the system's Background Tasks framework:
- Minimum 3-hour interval between updates
- System determines actual timing based on usage patterns
- View refresh history in Settings

---

## Development

### Project Structure

Shared logic lives in `Shared/`; iOS and macOS add their own views and lifecycle. No backend—all state is local.

```
PortfolioMultiplatform/
├── Shared/                       # Shared code (both platforms)
│   ├── Models/                   # Data models (Instrument, Holding, etc.)
│   ├── Services/                 # Core services
│   │   ├── DatabaseService.swift
│   │   ├── MarketDataService.swift
│   │   ├── LanguageManager.swift
│   │   ├── DemoModeManager.swift       # Privacy/demo mode
│   │   └── HapticService.swift         # Cross-platform haptics
│   ├── ViewModels/               # AppViewModel and extensions
│   ├── Views/
│   │   ├── Charts/               # EnhancedTrendCard, AllocationRingChart, etc.
│   │   ├── Dashboard/            # Dashboard sections (Quadrants, Holdings, Accounts)
│   │   ├── Components/           # Shared UI components
│   │   │   ├── AddHoldingSheet.swift
│   │   │   ├── PriceEditorSheet.swift
│   │   │   ├── BackfillLogsSheet.swift
│   │   │   └── ChangeLabel.swift
│   │   ├── DashboardView.swift
│   │   ├── ReportsView.swift
│   │   └── EditHoldingView.swift
│   ├── Helpers/                  # Formatting, date utilities
│   └── Resources/                # Localization (en, fr)
├── iOS/                          # iOS-specific code
│   ├── iOSRootView.swift         # Main iOS entry point
│   ├── BackgroundTaskManager.swift
│   ├── IOSLockManager.swift
│   └── Views/                    # iOS-specific views
│       └── Components/           # Period selector, view mode selector
├── macOS/                        # macOS-specific code
│   ├── MacOSSchedulerManager.swift
│   ├── MacOSLockManager.swift
│   └── Views/                    # macOS-specific views
│       ├── ContentView.swift     # Main macOS navigation
│       ├── AccountsView.swift
│       ├── InstrumentsView.swift
│       └── MacOSSettingsViews.swift
├── PortfolioTests/
├── PortfolioMultiplatform.xcodeproj/
├── assets/screenshots/
└── README.md
```

### Architecture Highlights

- **Maximum Code Sharing**: Charts, dashboard components, sheets, and services are shared between platforms
- **Platform-Specific UI**: Each platform has its own navigation and settings views optimized for the experience
- **Clean Separation**: Platform-specific code is clearly isolated in `iOS/` and `macOS/` folders
- **Unified Services**: `HapticService` and `DemoModeManager` provide consistent behavior across platforms

### Running Tests

**From Xcode:**
- Press `Cmd+U` to run all tests
- Use Test Navigator (`Cmd+6`) for individual tests

**From Command Line:**
```bash
# iOS tests
xcodebuild test \
  -project PortfolioMultiplatform.xcodeproj \
  -scheme "Portfolio iOS" \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# macOS tests
xcodebuild test \
  -project PortfolioMultiplatform.xcodeproj \
  -scheme "Portfolio macOS" \
  -destination 'platform=macOS'
```

### Test Structure

| File | Purpose |
|------|---------|
| `PortfolioTests.swift` | Basic test setup |
| `CurrencyConversionTests.swift` | Currency conversion logic |
| `DashboardSnapshotTests.swift` | UI snapshot tests |
| `TestFixtures.swift` | Test data fixtures |
| `MockDatabaseService.swift` | Mock services |

---

## Secrets and local config

Do not commit secrets or local signing config. The repo uses **automatic signing** with no team ID in source; set your **Team** in Xcode (**Signing & Capabilities**) for each app target. Other sensitive paths (e.g. `ExportOptions.plist`, `.env`, `*.xcconfig`, credentials) are listed in [.gitignore](.gitignore). Never commit API keys, tokens, or provisioning profiles.

## Publishing to the App Store

### Prerequisites

- **Apple Developer Program** membership ($99/year) — [developer.apple.com/programs](https://developer.apple.com/programs/)
- Your Apple ID added in **Xcode → Settings → Accounts**. In the project, set your **Team** under **Signing & Capabilities** for the iOS and/or macOS target (bundle IDs: **com.portfolio.app.ios**, **com.portfolio.app.macos**).

### 1. Create the app(s) in App Store Connect

- **iOS:** [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App** → iOS, bundle ID **com.portfolio.app.ios**, SKU (e.g. `portfolio-ios`).
- **macOS:** Same, New App → macOS, bundle ID **com.portfolio.app.macos**, SKU (e.g. `portfolio-macos`).

### 2. Archive and upload

1. In Xcode, select the **Portfolio iOS** (or **Portfolio macOS**) scheme and destination **Any iOS Device (arm64)** or **My Mac**.
2. **Product → Archive**. Wait for the archive to finish.
3. In the **Organizer**, select the new archive → **Distribute App** → **App Store Connect** → **Upload** (keep defaults: automatic signing, upload symbols).
4. Wait a few minutes for the build to appear in App Store Connect under the app’s **TestFlight** / **App Store** tab.

### 3. Complete the App Store listing

In App Store Connect, for each app:

- **App Information:** Category (e.g. **Finance**), subcategory if needed.
- **Pricing and Availability:** Free or paid; countries/regions.
- **App Privacy:** Privacy policy URL (required); state what data you collect (or that you don’t).
- **Version Information:** Screenshots (required sizes), description, keywords, support URL, **Build** (select the uploaded build), **What’s New**.

### 4. Submit for review

1. In the version’s **App Store** tab, complete any missing required fields.
2. **App Review Information:** add contact and notes.
3. **Add for Review** → accept export compliance and declarations → **Submit**.

**Tip:** Build number increments automatically at each build. If the build doesn’t appear under the version, wait a bit or check **TestFlight** for processing/errors.

---

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE).

**Summary:**
- ✅ **Free for non-commercial use** — personal projects, research, education, hobby use
- ✅ **Modifications allowed** — you can modify and distribute for non-commercial purposes
- ❌ **Commercial use requires permission** — contact for commercial licensing

---

## Support

For questions, issues, or feature requests, please open an issue on GitHub.

---

*Built with SwiftUI · SQLite*
