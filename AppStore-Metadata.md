# App Store metadata review — 1 November 2026

Source files: `fastlane/metadata/<locale>/*.txt`. Home-screen name remains **Portfolio Vault**.

## Status

App Store Connect has **1.1.0** drafts (`PREPARE_FOR_SUBMISSION`) for iOS and macOS. Description, keywords, promotional text and What’s New have been uploaded and verified across all nine locales. New iPhone screenshots are being uploaded; existing iPad and macOS images are retained. Version 1.0.9 remains live. This release is being prepared for review and has not been submitted to Apple.

The release uses the committed iPhone redesign and branded unlock screen. Screenshot fixture changes remain outside the shipping source. All three app targets and tooling defaults are aligned to **1.1.0 (55)**. Build 55 is one greater than the highest uploaded build (54), verified directly through App Store Connect before the bump. The existing combined Xcode Cloud workflow will archive and upload both platforms.

## Review findings and changes

- The live opening listed asset types but did little to explain the insight users get. New copy leads with ownership, return and allocation, followed by concrete capabilities.
- “Real-time prices” was too broad for source-dependent market data. Copy now explains that prices may be delayed and historical coverage varies.
- Valuing a portfolio in gold ounces is not an inflation adjustment. Removed that claim. Gold remains an asset and benchmark where supported.
- “Your data never leaves your device” conflicted with optional cloud backup. New copy distinguishes local portfolio storage, public-identifier price requests, and optional iCloud backup. Current iOS entitlements include iCloud; runtime availability is still required.
- Holdings and transactions are manual. The description now says so explicitly, avoiding an expectation of automatic bank imports.
- New benefit-led What’s New focuses on the iPhone redesign and improvements visible in the working source. Already-live transaction-ledger features are described as lasting capabilities rather than presented as newly released.
- Removed unsupported “watchlist” and German “Sparplan” search terms. Revised English/French/German terms toward tracking, performance, allocation and privacy. Name and subtitle remain unchanged to preserve their asset-specific search coverage.
- Descriptions and release notes are aligned across all nine storefront locales. Additional storefronts explicitly state that the interface supports English and French.

Keywords are relevance-based candidates, not measured search-volume or ranking recommendations. No acquisition or conversion analytics were available for this review.

## Keyword candidates

Apple limits keywords to 100 characters. Avoid repeating words from the existing name and subtitle. Retain the current localized names and subtitles for this iteration.

| Locale | Length | Keywords |
|---|---:|---|
| en-US | 97/100 | `tracker,investment,performance,allocation,profit,holdings,bitcoin,silver,mutual fund,ISIN,privacy` |
| en-GB | 98/100 | `tracker,investment,performance,allocation,profit,shares,ISA,bitcoin,silver,unit trust,ISIN,privacy` |
| en-CA | 97/100 | `tracker,investment,performance,allocation,profit,holdings,bitcoin,silver,mutual fund,ISIN,privacy` |
| fr-FR | 95/100 | `actions,ETF,suivi,rendement,répartition,gain,CTO,bitcoin,bourse,patrimoine,ISIN,confidentialité` |
| fr-CA | 96/100 | `suivi,rendement,répartition,placement,bitcoin,bourse,patrimoine,fonds,OPCVM,ISIN,confidentialité` |
| de-DE | 92/100 | `Fonds,Rendite,Allokation,Gewinn,Depot,bitcoin,Silber,ISIN,Vermögen,offline,Datenschutz,Münze` |
| es-ES | 97/100 | `fondos,NAV,bitcoin,plata,ISIN,patrimonio,offline,privacidad,moneda,broker,efectivo,cartera,divisa` |
| it | 98/100 | `fondi,NAV,bitcoin,argento,ISIN,patrimonio,offline,privacy,moneta,broker,contanti,obbligazioni,cash` |
| nl-NL | 97/100 | `fonds,NAV,bitcoin,zilver,ISIN,vermogen,offline,privacy,munt,broker,cash,depot,belegging,obligatie` |

## What’s New — English (1.2.0)

Compare your portfolio with your own categories, and read trends with moving averages.

• Compare to: plot your portfolio's return against MSCI World, the S&P 500, gold or any of your categories, up to three lines at a time. Each category's chart can be compared too.
• Moving averages: add 30-day, 200-day and 7-year averages to holding and category charts, with a short guide to what they show.
• Gold / Oil: a new card shows how many barrels of Brent crude an ounce of gold buys, with its own chart.
• Swiping on a chart now scrolls the page; touch and hold to read values.
• Your portfolio line keeps one color, holding pages no longer show a blank gap, and quantities use your region's number format.

Your portfolio stays under your control: no account, no bank connection, no analytics.

French and other localized versions live in the corresponding `release_notes.txt` files.

## iPhone screenshots

Prepared under `assets/screenshots/ios-2026-11-01/`, with localized English and French sets. Recommended order:

1. **See your investments clearly** — overview and portfolio value.
2. **Understand what you earned** — actual investment-return chart and benchmark comparisons.
3. **All your positions. One place.** — searchable positions and their returns.
4. **Know where your money sits** — allocation by category.
5. **Your portfolio. Your privacy.** — masked amounts and the dark appearance.

Screens use the current SwiftUI views in a temporary screenshot-only build, with a deterministic fictional EUR portfolio. The screenshot fixture is outside the repository and is excluded from shipping code. No personal holdings were read. Percentage returns and allocations are illustrative, not a promise of investment results.

PNG exports are RGB, without transparency, at **1320 × 2868** and **1206 × 2622**, accepted iPhone portrait dimensions. The smaller export is composed from the same large-device capture; it is not a separate device interaction test. Contact sheets are previews and must not be uploaded. Use the five numbered PNGs in the appropriate locale/size folder. Keep existing macOS screenshots.

## Validation and publication

Run `python3 scripts/validate_app_store_metadata.py` for listing limits. Screenshot dimensions, color mode, ordering and text fit are checked by the screenshot generator, and the English/French contact sheets are reviewed visually.

The user authorized publishing the package to the 1.1.0 drafts and uploading a new build through Xcode Cloud. Metadata and screenshots are uploaded directly through Apple’s API because the local pinned fastlane tools are unavailable. No live promotional text was changed. The metadata lane deliberately skips screenshots. Before a release, follow the repository’s App Store Connect build-number and Xcode Cloud checklist.

Apple references:
- https://developer.apple.com/app-store/product-page/
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
