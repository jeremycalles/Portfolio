# App Store Metadata

> **Source of truth:** edit `fastlane/metadata/<locale>/*.txt`, then run `bundle exec fastlane metadata_upload`.
> Setup: [fastlane/README.md](fastlane/README.md).
>
> Name, subtitle, keywords, and description are locked on a live version. `metadata_upload` creates the next Prepare for Submission version (currently **1.0.7**) and uploads indexed copy there. Promotional text is also patched on the live listing.

App name on the home screen stays **Portfolio Vault**. One App Store Connect app (`com.portfolio.app.ios`) covers iOS and macOS (universal purchase).

Apple search ranks **name + subtitle + keywords only** (160 characters per locale). Do **not** repeat a word across those three fields. Description and promotional text are for conversion (and Google), not Apple ranking. Categories: **Finance / Productivity**. Do not put Yahoo, Veracash, or AuCOFFRE in keywords.

---

## Indexed copy (findability)

### English (US) and English (Canada)

| Field | Copy | Limit |
|-------|------|-------|
| Name | `Portfolio Vault` | 15 / 30 |
| Subtitle | `Stocks, ETFs, Gold & Crypto` | 27 / 30 |
| Keywords | `mutual fund,NAV,OPCVM,bitcoin,silver,holdings,brokerage,watchlist,ISIN,wealth,offline,privacy,coin` | 98 / 100 |

### English (UK)

Same name and subtitle. Keywords: `shares,ISA,unit trust,NAV,OPCVM,bitcoin,silver,holdings,ISIN,wealth,offline,privacy,gilt,cash,coin` (98 / 100).

### French (France)

| Field | Copy | Limit |
|-------|------|-------|
| Name | `Portfolio Vault Portefeuille` | 28 / 30 |
| Subtitle | `PEA, OPCVM, or et crypto` | 24 / 30 |
| Keywords | `actions,investissement,placement,CTO,bitcoin,VL,bourse,courtier,lingot,argent,patrimoine,isin,cash` | 98 / 100 |

Store name adds **portefeuille** (what people type). Home screen stays Portfolio Vault.

### French (Canada)

Same name. Subtitle: `Actions, ETF, or et crypto` (no PEA/CTO). Keywords omit those France-specific wrappers.

### Extra locales (UI stays EN+FR)

de-DE, es-ES, it, nl-NL: translated name/subtitle/keywords plus a short description so the storefront is not empty. Each locale adds another 160 indexed characters.

---

## Promotional text

**Limit: 170** • Not indexed • Editable without a new version.

```
Track stocks, ETFs, gold, and crypto on iPhone and Mac. No account, no bank login. Data stays on device. Optional iCloud backup. Coins, funds, Face ID.
```

FR: *Actions, ETF, or et crypto sur iPhone et Mac. Sans compte, sans banque. Données sur l’appareil. Sauvegarde iCloud optionnelle. Pièces d’or, OPCVM, Face ID.*

---

## Description

**Limit: 4,000** • First ~255 characters are the search-result / Google hook.

Lead with what people type (stocks, gold, crypto, no account), then WHAT YOU CAN TRACK / FEATURES. Mention OPCVM NAV, physical coins, gold ounces, Face ID, EN+FR, optional iCloud backup. Full text lives in `fastlane/metadata/<locale>/description.txt`.

---

## What’s New

```
Initial release. Track stocks, ETFs, funds, gold, crypto, and bank accounts in one place. Your data stays on your device with optional iCloud sync. Available on iOS and macOS.
```

---

## App Icon

Generated from `assets/app-icon-source.jpg` into `Shared/Assets.xcassets/AppIcon.appiconset/`. Same catalog for iOS and macOS.

---

## Storefronts and screenshots

- Confirm **Pricing and Availability** includes FR, BE, CH, LU, CA, US, GB, and the rest of the EU. A listing in a disabled storefront does not rank.
- Screenshots are not uploaded by `metadata_upload`. First screenshot should be the dashboard total + chart (stocks / gold / on-device), not Settings. Files live in `assets/screenshots/`.
- Ratings are per country; French installs matter more than extra keywords.
