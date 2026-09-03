# Agent guide — Portfolio Vault

Privacy-first SwiftUI portfolio tracker. **No backend, no telemetry, no API keys.** All user data is local SQLite. Market APIs receive only public identifiers (ISIN / ticker).

Display name: **Portfolio Vault**. Xcode project: `PortfolioMultiplatform.xcodeproj`. Module: `PortfolioMultiplatform`.

Do not treat `README.md` as the source of truth for structure or automation — several sections are stale (see [Docs drift](#docs-drift)).

---

## Targets and IDs

| Target | Product | Bundle ID | Version (as of review) |
|--------|---------|-----------|------------------------|
| Portfolio iOS | Portfolio Vault.app | `com.portfolio.app.ios` | 1.0.6 / 19 |
| Portfolio macOS | Portfolio Vault.app | `com.portfolio.app.ios` (same ID; universal purchase) | 1.0.6 / 19 |
| PortfolioRefreshLoginItem | helper (LSUIElement) | `com.portfolio.app.ios.RefreshLoginItem` | 1.0.4 / 16 — bump with the Mac app |
| PortfolioCoreTests | `.xctest` hosted on **iOS** | `com.portfolio.app.tests` | — |

Team: `73Y2U9Q7Q7`. Deployment: **iOS 17**, **macOS 15**. Schemes: `Portfolio iOS`, `Portfolio macOS`.

App group (macOS + login item): `73Y2U9Q7Q7.group.com.portfolio.app`. iCloud container referenced in code: `iCloud.com.portfolio.app` (entitlement **not** in repo plists — backup UI stays hidden until added in Xcode / Developer portal).

---

## Layout (where to edit)

```
Shared/                  Cross-platform only. Keep platform #if to a minimum.
  PortfolioApp.swift     @main, scenes, iOS AppDelegate, macOS URL + Darwin refresh
  Models/Models.swift    Instrument, Holding, Price, ReportPeriod, INDEX:* benchmarks
  ViewModels/            AppViewModel + PriceManagement / History / Reports
  Services/              DatabaseService, MarketDataService, LanguageManager, DemoMode, …
  Views/                 Dashboard, charts, shared sheets
  Resources/{en,fr}.lproj/Localizable.strings
iOS/                     Tab UI, lock, BGTaskScheduler, walkthrough
macOS/                   SplitView, settings window, scheduler, lock
  RefreshLoginItem/      Headless helper — Darwin notify only, no UI
Tests/PortfolioCoreTests Swift Testing (`import Testing`). Host: iOS app.
ci_scripts/              Xcode Cloud hooks (`ci_post_clone.sh` writes stub Local.xcconfig)
```

There is **no** `Packages/PortfolioCore`. SPM deps: SQLite.swift, SwiftSoup. `swift-snapshot-testing` is linked but unused — do not add snapshot tests unless you actually adopt it.

App icon: replace `assets/app-icon-source.jpg`, then run `scripts/icon_gen/generate.js`. Xcode only compiles the PNGs listed in `AppIcon.appiconset/Contents.json`. Do not leave an unlisted `icon.svg` in that folder.

---

## Architecture (do not fight this)

```
SwiftUI  →  AppViewModel (@MainActor)  →  DatabaseService (@MainActor facade)
                                         →  DatabaseActor (all SQLite I/O)
                                         →  MarketDataService (actor)
```

- One shared `AppViewModel`. CRUD and `refreshAll()` live in the main file; price/backfill in `+PriceManagement`; history/charts in `+History`; reports in `+Reports`.
- After any write that changes totals, call `refreshHoldings()` / `refreshInstruments()` **and** `recomputeDashboardCache()`. `refreshAll()` already recomputes — do not call both unless you have a reason (today `updateAllPrices` does; avoid adding a third pass).
- `AppViewModel.init` already `refreshAll()`s. iOS `iOSRootView.onAppear` does it again — do not add a third launch refresh.
- Preview: `AppViewModel.preview` / `init(forPreview:)` — never hit the DB.
- Demo mode (`DemoModeManager`) randomizes **display** quantities only. Privacy mode (`@AppStorage("privacyMode")`) only masks UI. Do not persist demo quantities.
- Dates in SQLite are `yyyy-MM-dd` strings via `AppDateFormatter`. Do not invent new formatters.
- Currency: display/report values convert to EUR via `convertToEUR` / `CurrencyConversion.euros`. Missing FX rates return `nil` and that point is omitted — never treat the raw amount as EUR.

### Market data routing (`MarketDataService.fetchData`)

1. Pseudo-ISINs: `VERACASH:*`, `COIN:*` (HTML scrape).
2. 12-char ISIN (and `ISIN:CURRENCY`) → Financial Times, then Yahoo.
3. Tickers / crypto → Yahoo (`AAPL`, `BTC-EUR`).
4. Benchmarks stored as `INDEX:SP500`, `INDEX:GOLD`, `INDEX:MSCI_WORLD`.

Refresh: batches of 4 + 0.5s delay; HTTP 429 retries 1s/2s/4s. Do not raise concurrency without a rate-limit plan. Prefer `AppLogger` over new `print()`s.

### Background refresh

| Platform | Mechanism | Interval |
|----------|-----------|----------|
| iOS | `BGAppRefreshTask` `com.portfolio.app.refresh` + foreground poll | min 3h (`lastBackgroundRefresh`) |
| macOS | `SMAppService` login item + in-app `Timer` + Darwin `com.portfolio.app.refreshRequested` | 1h / 3h / 6h / 12h |

macOS also accepts `portfolio://refresh`. The login item **must wake the main app** if it is not running — Darwin notify is dropped otherwise. **Do not** reintroduce `launchctl` / `~/Library/LaunchAgents` plists. iOS must report `setTaskCompleted(success: true)` when the attempt finished; per-ticker failures must not be reported as task failure (iOS deprioritizes the app).

### Lock

`IOSLockManager` / `MacOSLockManager` + `BiometricAuth`. Locks on background (iOS) and after 5 minutes idle. Keys: `ios_biometric_protection_enabled`, `macos_touch_id_protection_enabled`.

---

## Localization

User-visible strings go through `L10n` (`LanguageManager.swift`) **and** both `en.lproj` and `fr.lproj`. Keys must match exactly.

- Runtime language switch rebuilds UI via `.id(languageManager.refreshID)`.
- ~38 keys exist in strings files but have no `L10n` accessor (leftover Multipeer/export copy). Reuse or delete; do not duplicate.
- Status / error strings in `AppViewModel` and the macOS “Don’t ask again” / “Not now” prompt are still hardcoded English. New copy must be localized.

---

## Persistence rules

Schema is `create(ifNotExists:)` only — **no migration version**. Additive columns need an explicit `ALTER` path or existing installs will ignore them.

`insert(or: .replace)` upserts on PRIMARY KEY / UNIQUE conflict. After `migrateNaturalKeys`, unique indexes exist on `prices(isin, date)`, `exchange_rates(from, to, date)`, `holdings(account_id, isin)`, and `bank_accounts(bank_name, account_name)`. Do not drop those indexes.

Paths: iOS `Documents/PortfolioData/stocks.db`; macOS `Application Support/Portfolio/data/stocks.db`. Import: `closeConnection()` → replace file → `reconnectToDatabase()` → `refreshAll()`. Never open the iCloud copy as the live DB.

---

## Versioning and App Store

When bumping a release:

1. Check App Store Connect for the **next unused** `CURRENT_PROJECT_VERSION` (do not reuse a build number).
2. Set `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` on **iOS and macOS** together.
3. Bump **PortfolioRefreshLoginItem** to the same marketing/build as macOS (it is currently behind).
4. Default path: **Xcode Cloud** archive → App Store Connect. `ci_scripts/ci_post_clone.sh` must keep writing `Local.xcconfig` (gitignored).
5. Local signing: copy `Local.xcconfig.example` → `Local.xcconfig`. Do not commit secrets, `.xcconfig` overrides, or provisioning profiles.
6. After archive, confirm the build appears in TestFlight before calling the version done.

Copy for listings: `AppStore-Metadata.md` (app name there still says “PortfolioMultiplatform” — store name is Portfolio Vault).

---

## Tests

```bash
xcodebuild test -project PortfolioMultiplatform.xcodeproj \
  -scheme "Portfolio iOS" \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Coverage today: models, formatters, date helpers only. No DatabaseActor / MarketData / ViewModel tests. Prefer Swift Testing (`@Test`, `#expect`).

---

## Docs drift

README (and README_fr) still describe: a `Packages/PortfolioCore` package, macOS 14, a Launch Agent plist + `launchctl`, and bundle ID `com.portfolio.app.macos`. None of that is current. Prefer this file.

---

## Working rules

1. Shared logic in `Shared/`. Platform UI and lifecycle only in `iOS/` or `macOS/`.
2. No new network destinations, analytics, or account-linking.
3. No secrets in the repo. Yahoo / FT / Veracash / AuCOFFRE are unauthenticated public endpoints — scraping is brittle; isolate HTML parsers.
4. Do not add a Swift package layer unless asked. Tests import `@testable import PortfolioMultiplatform`.
5. Keep diffs tight. Do not “fix” README, unused strings, or version drift unless that is the task.
6. User-facing text: `L10n` + both `.strings` files in the same change.
