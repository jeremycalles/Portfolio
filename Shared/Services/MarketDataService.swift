import Foundation
#if canImport(SwiftSoup)
import SwiftSoup
#endif

// MARK: - Market Data Service
actor MarketDataService {
    static let shared = MarketDataService()
    
    private let session: URLSession
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = ["User-Agent": userAgent]
        session = URLSession(configuration: config)
    }
    
    /// When identifier is "ISIN:CURRENCY" (e.g. LU0169518387:USD), returns the 12-char ISIN for FT/search; otherwise returns the original.
    private func coreIsinForLookup(_ isin: String) -> String {
        if let colonIndex = isin.firstIndex(of: ":"), colonIndex == isin.index(isin.startIndex, offsetBy: 12) {
            let prefix = String(isin[..<colonIndex])
            if prefix.count == 12, prefix.allSatisfy({ $0.isLetter || $0.isNumber }) {
                return prefix
            }
        }
        return isin
    }
    
    /// Percent-encodes a ticker for use in URLs (e.g. "LU0169518387:USD" → "LU0169518387%3AUSD").
    private func urlEncodedTicker(_ ticker: String) -> String {
        ticker.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "?"))) ?? ticker
    }
    
    /// Extract desired currency from identifier suffix (e.g. "LU0169518387:USD" → "USD", "LU0169518387" → nil).
    private func desiredCurrencyFromIdentifier(_ isin: String) -> String? {
        guard let colonIdx = isin.firstIndex(of: ":"), isin.distance(from: isin.startIndex, to: colonIdx) == 12 else { return nil }
        let suffix = String(isin[isin.index(after: colonIdx)...]).uppercased()
        return ["USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "SGD", "HKD"].contains(suffix) ? suffix : nil
    }
    
    // MARK: - Fetch Market Data
    func fetchData(isin: String, ticker: String? = nil) async -> MarketDataResult {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let coreIsin = coreIsinForLookup(isin)
        
        // Special case: Veracash Gold Premium
        if isin == "VERACASH:GOLD_PREMIUM" {
            let value = await scrapeVeracashGold(premium: true)
            return MarketDataResult(
                isin: isin,
                ticker: "VERACASH_GOLD_PREM",
                name: "Veracash Gold Premium Gram",
                value: value,
                currency: "EUR",
                date: String(today)
            )
        }
        
        // Special case: Veracash Gold Spot
        if isin == "VERACASH:GOLD_SPOT" {
            let value = await scrapeVeracashGold(premium: false)
            return MarketDataResult(
                isin: isin,
                ticker: "VERACASH_GOLD_SPOT",
                name: "Veracash Gold Spot Gram",
                value: value,
                currency: "EUR",
                date: String(today)
            )
        }
        
        // Special case: Veracash Silver
        if isin == "VERACASH:SILVER_SPOT" {
            let value = await scrapeVeracashSilver()
            return MarketDataResult(
                isin: isin,
                ticker: "VERACASH_SILVER_SPOT",
                name: "Veracash Silver Spot Gram",
                value: value,
                currency: "EUR",
                date: String(today)
            )
        }
        
        // Special case: AuCOFFRE coins (Napoleon, Vera Max, Gecko, Gold Bar)
        if isin.starts(with: "COIN:") {
            return await scrapeAuCoffreCoin(isin: isin)
        }
        
        let isValidIsin = coreIsin.count == 12 && coreIsin.allSatisfy { $0.isLetter || $0.isNumber }
        let desiredCurrency = desiredCurrencyFromIdentifier(isin)
        print("[MarketData] Fetching data for ISIN: \(isin), coreIsin: \(coreIsin), isValidIsin: \(isValidIsin), desiredCurrency: \(desiredCurrency ?? "any")")
        
        // For ISINs (including "ISIN:CURRENCY" like LU0169518387:USD), try Financial Times first
        if isValidIsin {
            // First try FT with full identifier (e.g. LU0169518387:USD) – FT may have a separate page
            if desiredCurrency != nil && isin != coreIsin {
                print("[MarketData] Trying FT with full identifier \(isin)...")
                if let ftResult = await scrapeFT(isin: isin) {
                    if let ftCurrency = ftResult.currency, ftCurrency.uppercased() == desiredCurrency {
                        print("[MarketData] FT SUCCESS for \(isin): \(ftResult.value ?? -1) \(ftCurrency)")
                        return MarketDataResult(isin: isin, ticker: ftResult.ticker, name: ftResult.name, value: ftResult.value, currency: ftResult.currency, date: ftResult.date)
                    } else {
                        print("[MarketData] FT returned \(ftResult.currency ?? "?") but need \(desiredCurrency!) – skipping")
                    }
                }
            }
            
            // Then try FT with core ISIN (skip if currency doesn't match when a specific currency is desired)
            print("[MarketData] Trying FT for \(coreIsin)...")
            if let ftResult = await scrapeFT(isin: coreIsin) {
                if let desired = desiredCurrency, let ftCurrency = ftResult.currency, ftCurrency.uppercased() != desired {
                    print("[MarketData] FT returned \(ftCurrency) but need \(desired) – skipping FT")
                } else {
                    print("[MarketData] FT SUCCESS for \(coreIsin): \(ftResult.value ?? -1) \(ftResult.currency ?? "?")")
                    return MarketDataResult(isin: isin, ticker: ftResult.ticker, name: ftResult.name, value: ftResult.value, currency: ftResult.currency, date: ftResult.date)
                }
            } else {
                print("[MarketData] FT FAILED for \(coreIsin)")
            }
        }
        
        // Resolve ticker if not provided (search by core ISIN so Yahoo finds the fund)
        var resolvedTicker = ticker
        if resolvedTicker == nil || resolvedTicker == "N/A" {
            print("[MarketData] Resolving ticker for \(coreIsin)...")
            resolvedTicker = await resolveIsinToTicker(isin: coreIsin)
            print("[MarketData] Resolved ticker: \(resolvedTicker ?? "nil")")
        }
        if resolvedTicker == nil && !isValidIsin {
            resolvedTicker = isin
        }
        
        // Try Yahoo Finance (URL-encode ticker so symbols like LU0169518387:USD work)
        if let tickerSymbol = resolvedTicker {
            print("[MarketData] Trying Yahoo Finance for \(tickerSymbol)...")
            if let yahooResult = await fetchYahooFinance(ticker: tickerSymbol, isin: isin) {
                print("[MarketData] Yahoo SUCCESS for \(tickerSymbol): \(yahooResult.value ?? -1)")
                return yahooResult
            }
            print("[MarketData] Yahoo FAILED for \(tickerSymbol)")
        }
        
        // Fallback to FT for ISINs (only if no specific currency requested, or currency matches)
        print("[MarketData] Trying FT fallback for \(coreIsin)...")
        if let ftResult = await scrapeFT(isin: coreIsin) {
            if let desired = desiredCurrency, let ftCurrency = ftResult.currency, ftCurrency.uppercased() != desired {
                print("[MarketData] FT fallback returned \(ftCurrency) but need \(desired) – skipping")
            } else {
                print("[MarketData] FT fallback SUCCESS for \(coreIsin)")
                return MarketDataResult(isin: isin, ticker: ftResult.ticker, name: ftResult.name, value: ftResult.value, currency: ftResult.currency, date: ftResult.date)
            }
        }
        
        // Return empty result
        print("[MarketData] ALL METHODS FAILED for \(isin)")
        return MarketDataResult(
            isin: isin,
            ticker: resolvedTicker,
            name: nil,
            value: nil,
            currency: nil,
            date: String(today)
        )
    }
    
    // MARK: - Yahoo Finance
    private func fetchYahooFinance(ticker: String, isin: String) async -> MarketDataResult? {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let encoded = urlEncodedTicker(ticker)
        
        // Try the Yahoo Finance quote API (ticker URL-encoded so symbols like LU0169518387:USD work)
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=5d") else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let result = results.first else {
                return nil
            }
            
            // Get price
            var price: Double?
            var priceDate = String(today)
            
            if let meta = result["meta"] as? [String: Any] {
                price = meta["regularMarketPrice"] as? Double
            }
            
            // Fallback to indicators
            if price == nil,
               let indicators = result["indicators"] as? [String: Any],
               let quote = (indicators["quote"] as? [[String: Any]])?.first,
               let closes = quote["close"] as? [Double?] {
                // Get last non-nil close
                price = closes.compactMap { $0 }.last
            }
            
            // Get timestamps for date
            if let timestamps = result["timestamp"] as? [Int], let lastTimestamp = timestamps.last {
                let date = Date(timeIntervalSince1970: TimeInterval(lastTimestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                priceDate = formatter.string(from: date)
            }
            
            // Get metadata
            var name: String?
            var currency = "USD"
            
            if let meta = result["meta"] as? [String: Any] {
                currency = meta["currency"] as? String ?? "USD"
            }
            
            // Try to get name from quote summary
            name = await fetchYahooName(ticker: ticker)
            
            guard let finalPrice = price else { return nil }
            
            return MarketDataResult(
                isin: isin,
                ticker: ticker,
                name: name,
                value: finalPrice,
                currency: currency,
                date: priceDate
            )
        } catch {
            print("Yahoo Finance error for \(ticker): \(error)")
            return nil
        }
    }
    
    private func fetchYahooName(ticker: String) async -> String? {
        let encoded = urlEncodedTicker(ticker)
        guard let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(encoded)") else { return nil }
        
        do {
            let (data, _) = try await session.data(from: url)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let quoteResponse = json["quoteResponse"] as? [String: Any],
               let results = quoteResponse["result"] as? [[String: Any]],
               let first = results.first {
                return first["longName"] as? String ?? first["shortName"] as? String
            }
        } catch {
            // Ignore name fetch errors
        }
        return nil
    }
    
    // MARK: - ISIN to Ticker Resolution
    func resolveIsinToTicker(isin: String) async -> String? {
        let encoded = isin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? isin
        guard let url = URL(string: "https://query2.finance.yahoo.com/v1/finance/search?q=\(encoded)") else {
            print("[Yahoo Search] Invalid URL for \(isin)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        // Try up to 2 times with a delay (Yahoo sometimes rate-limits)
        for attempt in 0..<2 {
            if attempt > 0 {
                print("[Yahoo Search] Retrying after delay...")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            do {
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("[Yahoo Search] HTTP status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 429 {
                        print("[Yahoo Search] Rate limited, will retry")
                        continue
                    }
                }
                
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("[Yahoo Search] Response: \(responseStr.prefix(200))...")
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let quotes = json["quotes"] as? [[String: Any]] {
                    print("[Yahoo Search] Found \(quotes.count) quotes")
                    if let first = quotes.first,
                       let symbol = first["symbol"] as? String {
                        print("[Yahoo Search] Resolved to: \(symbol)")
                        return symbol
                    }
                }
            } catch {
                print("[Yahoo Search] Error (attempt \(attempt + 1)): \(error)")
            }
        }
        print("[Yahoo Search] Failed to resolve \(isin)")
        return nil
    }
    
    // MARK: - Financial Times Scraping
#if canImport(SwiftSoup)
    private func scrapeFT(isin: String) async -> MarketDataResult? {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        
        // Try both funds and ETFs pages (FT may redirect between them)
        let urls = [
            "https://markets.ft.com/data/funds/tearsheet/summary?s=\(isin)",
            "https://markets.ft.com/data/etfs/tearsheet/summary?s=\(isin)"
        ]
        
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            print("[FT] Trying URL: \(urlString)")
            
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[FT] No HTTP response")
                    continue
                }
                
                print("[FT] HTTP status: \(httpResponse.statusCode), final URL: \(httpResponse.url?.absoluteString ?? "?")")
                
                guard (200...399).contains(httpResponse.statusCode),
                      let html = String(data: data, encoding: .utf8) else {
                    print("[FT] Bad status or no HTML, data size: \(data.count)")
                    continue
                }
                
                print("[FT] HTML size: \(html.count) chars")
                
                let doc = try SwiftSoup.parse(html)
                
                // Check for error page
                if let title = try? doc.title() {
                    print("[FT] Page title: \(title)")
                    if title.contains("Error") {
                        continue
                    }
                }
                
                // Parse price - find the row whose label is "Price (EUR)" etc.
                let labelElements = try doc.select("span.mod-ui-data-list__label")
                let valueElements = try doc.select("span.mod-ui-data-list__value")
                print("[FT] Found \(labelElements.count) labels, \(valueElements.count) values")
                
                var price: Double?
                var currency = "EUR"
                for i in 0..<labelElements.count {
                    guard i < valueElements.count else { break }
                    let labelText = try labelElements.get(i).text()
                    let valueText = try valueElements.get(i).text()
                    print("[FT] Label[\(i)]: '\(labelText)' = '\(valueText)'")
                    
                    guard labelText.contains("Price (") else { continue }
                    let cleanValue = valueText.replacingOccurrences(of: ",", with: "")
                    price = Double(cleanValue)
                    if labelText.contains("USD") { currency = "USD" }
                    else if labelText.contains("EUR") { currency = "EUR" }
                    else if labelText.contains("GBP") { currency = "GBP" }
                    else if labelText.contains("CHF") { currency = "CHF" }
                    else if labelText.contains("JPY") { currency = "JPY" }
                    print("[FT] Found price: \(price ?? -1) \(currency)")
                    break
                }
                
                guard let finalPrice = price else {
                    print("[FT] No price found in labels")
                    continue
                }
                
                // Parse name
                var name: String?
                if let nameElement = try? doc.select("h1.mod-tearsheet-overview__header__name").first() {
                    name = try? nameElement.text()
                }
                print("[FT] Success: \(name ?? "?") = \(finalPrice) \(currency)")
                
                return MarketDataResult(
                    isin: isin,
                    ticker: "N/A",
                    name: name,
                    value: finalPrice,
                    currency: currency,
                    date: String(today)
                )
            } catch {
                print("[FT] Exception for \(isin) at \(urlString): \(error)")
                continue
            }
        }
        
        print("[FT] All URLs failed for \(isin)")
        return nil
    }
#else
    private func scrapeFT(isin: String) async -> MarketDataResult? {
        // SwiftSoup not available; skip FT scraping
        return nil
    }
#endif
    
    // MARK: - Veracash Scraping
#if canImport(SwiftSoup)
    private func scrapeVeracashGold(premium: Bool) async -> Double? {
        let url = URL(string: "https://www.veracash.com/gold-price-and-chart")!
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            let doc = try SwiftSoup.parse(html)
            
            // Look for list items containing gold prices
            for li in try doc.select("li") {
                let text = try li.text()
                
                // For premium gold, look for "GoldPremium" or similar
                if premium {
                    if text.contains("GoldPremium") || (text.contains("Gold") && text.contains("Premium")) {
                        if let price = extractEuroPrice(from: text) {
                            // Check if it's per gram or per ounce
                            if text.lowercased().contains("ounce") {
                                return price / 31.1034768 // Convert troy ounce to gram
                            }
                            return price
                        }
                    }
                } else {
                    // For spot gold, look for gold price but exclude premium
                    if text.contains("Gold") && text.contains("€") && !text.contains("Premium") && !text.contains("GoldPremium") {
                        if let price = extractEuroPrice(from: text) {
                            if text.lowercased().contains("ounce") {
                                return price / 31.1034768
                            }
                            return price
                        }
                    }
                }
            }
        } catch {
            print("Veracash gold scraping failed: \(error)")
        }
        return nil
    }
#else
    private func scrapeVeracashGold(premium: Bool) async -> Double? {
        // SwiftSoup not available; skip Veracash scraping
        return nil
    }
#endif
#if canImport(SwiftSoup)
    private func scrapeVeracashSilver() async -> Double? {
        let url = URL(string: "https://www.veracash.com/gold-price-and-chart")!
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            let doc = try SwiftSoup.parse(html)
            
            for li in try doc.select("li") {
                let text = try li.text()
                
                if text.contains("Silver") && text.contains("€") {
                    if let price = extractEuroPrice(from: text) {
                        if text.lowercased().contains("ounce") {
                            return price / 31.1034768
                        }
                        return price
                    }
                }
            }
        } catch {
            print("Veracash silver scraping failed: \(error)")
        }
        return nil
    }
#else
    private func scrapeVeracashSilver() async -> Double? {
        // SwiftSoup not available; skip Veracash scraping
        return nil
    }
#endif
    
    // MARK: - AuCOFFRE Coin Scraping
    // Coin configuration: maps pseudo-ISIN to scraping source
    // Uses either /cours-or main page (for common coins) or specific quotation pages
    private static let coinConfigs: [String: (url: String, searchText: String, name: String, ticker: String)] = [
        "COIN:NAPOLEON_20F": (
            url: "https://www.aucoffre.com/cours-or",
            searchText: "Napoléon 20F",
            name: "Napoléon 20F",
            ticker: "NAPOLEON_20F"
        ),
        "COIN:VERAMAX_GOLD_1/10OZ": (
            url: "https://www.aucoffre.com/cours/categorie-supertype/graphique-cotation-187",
            searchText: "Vera Max",
            name: "Vera Max 1/10 oz Or",
            ticker: "VERAMAX_GOLD"
        ),
        "COIN:GECKO_SILVER_1OZ": (
            url: "https://www.aucoffre.com/cours-argent",
            searchText: "Vera Silver 1 once 2021",
            name: "Vera Silver Gecko 1 oz",
            ticker: "GECKO_SILVER"
        ),
        // Note: COIN:GOLD_BAR_1OZ uses Veracash gold spot price - handled separately below
    ]
    
    // Historical data URLs for coins (AuCOFFRE quotation pages with embedded chart data)
    // These pages contain ~6 months of historical price data in the initialData JSON
    private static let coinHistoricalURLs: [String: String] = [
        "COIN:NAPOLEON_20F": "https://www.aucoffre.com/cours/categorie-supertype/graphique-cotation-1",
        "COIN:VERAMAX_GOLD_1/10OZ": "https://www.aucoffre.com/cours/categorie-supertype/graphique-cotation-187",
        "COIN:GECKO_SILVER_1OZ": "https://www.aucoffre.com/cours/categorie-supertype/graphique-cotation-291",
        // Note: COIN:GOLD_BAR_1OZ uses Yahoo Finance gold futures (GC=F) - handled separately
    ]
    
#if canImport(SwiftSoup)
    private func scrapeAuCoffreCoin(isin: String) async -> MarketDataResult {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        
        // Special case: Gold bar uses Veracash spot price × troy ounce weight
        if isin == "COIN:GOLD_BAR_1OZ" {
            let gramPrice = await scrapeVeracashGold(premium: false)
            let ouncePrice = gramPrice.map { $0 * 31.1034768 } // Convert gram to troy ounce
            return MarketDataResult(
                isin: isin,
                ticker: "GOLD_BAR_1OZ",
                name: "Lingot Or 1 once (Veracash Spot)",
                value: ouncePrice,
                currency: "EUR",
                date: String(today)
            )
        }
        
        guard let config = Self.coinConfigs[isin] else {
            return MarketDataResult(isin: isin, ticker: nil, name: nil, value: nil, currency: "EUR", date: String(today))
        }
        
        guard let url = URL(string: config.url) else {
            return MarketDataResult(isin: isin, ticker: config.ticker, name: config.name, value: nil, currency: "EUR", date: String(today))
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...399).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                print("[AuCOFFRE] Failed to fetch \(config.url)")
                return MarketDataResult(isin: isin, ticker: config.ticker, name: config.name, value: nil, currency: "EUR", date: String(today))
            }
            
            let doc = try SwiftSoup.parse(html)
            
            // Strategy: Find table rows containing the product name, then extract the price
            // The /cours-or and /cours-argent pages have tables with: Product | Variation | Price | Premium
            for row in try doc.select("tr") {
                let rowText = try row.text()
                
                // Check if this row contains our product (use searchText for matching)
                if rowText.contains(config.searchText) {
                    // Look for price cells in this row (format: "XXX,XX €")
                    let cells = try row.select("td")
                    for cell in cells {
                        let cellText = try cell.text().trimmingCharacters(in: .whitespaces)
                        // Price cell contains € but not % (to exclude variation column)
                        if cellText.contains("€") && !cellText.contains("%") {
                            if let price = extractAuCoffrePrice(from: cellText) {
                                print("[AuCOFFRE] Found \(config.name): \(price) EUR")
                                return MarketDataResult(isin: isin, ticker: config.ticker, name: config.name, value: price, currency: "EUR", date: String(today))
                            }
                        }
                    }
                }
            }
            
            // Fallback: Look for the product in links and find price in same context
            for link in try doc.select("a") {
                let linkText = try link.text()
                if linkText.contains(config.searchText) {
                    // Found the product link, look for price in parent row
                    if let parentRow = link.parent()?.parent() {
                        let rowText = try parentRow.text()
                        if let price = extractAuCoffrePrice(from: rowText) {
                            print("[AuCOFFRE] Found \(config.name) via link: \(price) EUR")
                            return MarketDataResult(isin: isin, ticker: config.ticker, name: config.name, value: price, currency: "EUR", date: String(today))
                        }
                    }
                }
            }
            
            print("[AuCOFFRE] Could not find '\(config.searchText)' on \(config.url)")
        } catch {
            print("[AuCOFFRE] Scraping error for \(isin): \(error)")
        }
        
        return MarketDataResult(isin: isin, ticker: config.ticker, name: config.name, value: nil, currency: "EUR", date: String(today))
    }
    
    private func extractAuCoffrePrice(from text: String) -> Double? {
        // Look for price pattern like "613,47 €" or "2 798,32 €" or "613.47 €"
        // Pattern: digits with optional spaces/dots for thousands, comma or dot for decimals, then €
        let components = text.components(separatedBy: "€")
        
        for (index, component) in components.enumerated() {
            guard index < components.count - 1 else { continue }
            
            let beforeEuro = component.trimmingCharacters(in: .whitespaces)
            
            // Find the last number-like sequence before €
            var priceString = ""
            var foundNumber = false
            
            for char in beforeEuro.reversed() {
                if char.isNumber || char == "," || char == "." || (char == " " && foundNumber) {
                    foundNumber = true
                    priceString = String(char) + priceString
                } else if foundNumber {
                    break
                }
            }
            
            // Clean: remove spaces, convert comma to dot for parsing
            var cleanPrice = priceString
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            // Handle European format: "1.234,56" -> "1234.56"
            if cleanPrice.contains(",") {
                // If has both . and , assume . is thousands separator
                if cleanPrice.contains(".") {
                    cleanPrice = cleanPrice.replacingOccurrences(of: ".", with: "")
                }
                cleanPrice = cleanPrice.replacingOccurrences(of: ",", with: ".")
            }
            
            if let price = Double(cleanPrice), price > 10 {
                return price
            }
        }
        
        return nil
    }
    
    /// Scrape historical price data from AuCOFFRE quotation pages.
    /// AuCOFFRE embeds ~6 months of historical data in the page HTML as JSON.
    func scrapeAuCoffreHistorical(isin: String) async -> [Price] {
        guard let urlString = Self.coinHistoricalURLs[isin],
              let url = URL(string: urlString) else {
            print("[AuCOFFRE Historical] No historical URL configured for \(isin)")
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("fr-FR,fr;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...399).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                print("[AuCOFFRE Historical] Failed to fetch \(urlString)")
                return []
            }
            
            // Extract the JSON data block containing initialData
            // Format: {"state": {...}, "initialData": {"data": [[timestamp_ms, price], ...]}, "config": {...}}
            guard let jsonRange = html.range(of: #"<script[^>]*>\s*(\{[^<]*"initialData"[^<]*\})\s*</script>"#, options: .regularExpression) else {
                print("[AuCOFFRE Historical] Could not find initialData JSON in page for \(isin)")
                return []
            }
            
            // Extract just the JSON object
            let scriptContent = String(html[jsonRange])
            guard let jsonStart = scriptContent.firstIndex(of: "{"),
                  let jsonEnd = scriptContent.lastIndex(of: "}") else {
                print("[AuCOFFRE Historical] Could not extract JSON from script for \(isin)")
                return []
            }
            
            let jsonString = String(scriptContent[jsonStart...jsonEnd])
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let initialData = json["initialData"] as? [String: Any],
                  let historical = initialData["data"] as? [[Any]] else {
                print("[AuCOFFRE Historical] Could not parse initialData for \(isin)")
                return []
            }
            
            // Convert [timestamp_ms, price] pairs to Price objects
            var prices: [Price] = []
            var seenDates: Set<String> = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for point in historical {
                guard point.count >= 2,
                      let timestampMs = point[0] as? Double,
                      let price = point[1] as? Double else { continue }
                
                let date = Date(timeIntervalSince1970: timestampMs / 1000)
                let dateString = dateFormatter.string(from: date)
                
                // Keep only one price per day (use the first occurrence)
                if !seenDates.contains(dateString) {
                    seenDates.insert(dateString)
                    prices.append(Price(
                        id: nil,
                        isin: isin,
                        date: dateString,
                        value: price,
                        currency: "EUR"
                    ))
                }
            }
            
            // Sort by date
            prices.sort { $0.date < $1.date }
            
            print("[AuCOFFRE Historical] Found \(prices.count) historical prices for \(isin)")
            return prices
            
        } catch {
            print("[AuCOFFRE Historical] Scraping error for \(isin): \(error)")
            return []
        }
    }
#else
    private func scrapeAuCoffreCoin(isin: String) async -> MarketDataResult {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        // Gold bar uses Veracash spot even without SwiftSoup (calls the #else stub)
        if isin == "COIN:GOLD_BAR_1OZ" {
            let gramPrice = await scrapeVeracashGold(premium: false)
            let ouncePrice = gramPrice.map { $0 * 31.1034768 }
            return MarketDataResult(isin: isin, ticker: "GOLD_BAR_1OZ", name: "Lingot Or 1 once (Veracash Spot)", value: ouncePrice, currency: "EUR", date: String(today))
        }
        let config = Self.coinConfigs[isin]
        return MarketDataResult(isin: isin, ticker: config?.ticker, name: config?.name, value: nil, currency: "EUR", date: String(today))
    }
    
    // Stub: SwiftSoup not available, cannot scrape historical data
    func scrapeAuCoffreHistorical(isin: String) async -> [Price] {
        print("[AuCOFFRE Historical] SwiftSoup not available, cannot scrape historical data")
        return []
    }
#endif
    
    private func extractEuroPrice(from text: String) -> Double? {
        // Extract price after € symbol
        guard let euroIndex = text.firstIndex(of: "€") else { return nil }
        let afterEuro = String(text[text.index(after: euroIndex)...])
        
        // Get the first number-like sequence
        var priceString = ""
        var foundDigit = false
        
        for char in afterEuro {
            if char.isNumber || char == "." || char == "," {
                foundDigit = true
                if char == "," {
                    priceString.append(".") // European decimal
                } else {
                    priceString.append(char)
                }
            } else if foundDigit && (char == " " || char == "/") {
                break
            }
        }
        
        return Double(priceString)
    }
    
    // MARK: - Exchange Rate
    func fetchExchangeRate(from fromCurrency: String, to toCurrency: String) async -> ExchangeRate? {
        let pair = "\(fromCurrency)\(toCurrency)=X"
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(pair)?interval=1d&range=5d")!
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let result = results.first else {
                return nil
            }
            
            var rate: Double?
            var rateDate = String(today)
            
            // Get rate from meta
            if let meta = result["meta"] as? [String: Any] {
                rate = meta["regularMarketPrice"] as? Double
            }
            
            // Fallback to indicators
            if rate == nil,
               let indicators = result["indicators"] as? [String: Any],
               let quote = (indicators["quote"] as? [[String: Any]])?.first,
               let closes = quote["close"] as? [Double?] {
                rate = closes.compactMap { $0 }.last
            }
            
            // Get date
            if let timestamps = result["timestamp"] as? [Int], let lastTimestamp = timestamps.last {
                let date = Date(timeIntervalSince1970: TimeInterval(lastTimestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                rateDate = formatter.string(from: date)
            }
            
            guard let finalRate = rate else { return nil }
            
            return ExchangeRate(
                id: nil,
                date: rateDate,
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                rate: finalRate
            )
        } catch {
            print("Exchange rate fetch failed for \(pair): \(error)")
            return nil
        }
    }
    
    // MARK: - Historical Data
    
    /// Fetch historical gold futures prices from Yahoo Finance (GC=F).
    /// Used as a proxy for COIN:GOLD_BAR_1OZ historical data.
    /// Gold futures are priced in USD per troy ounce - we convert to EUR.
    private func fetchGoldFuturesHistory(isin: String, period: String = "1y", interval: String = "1mo") async -> [Price] {
        // Fetch gold futures (GC=F) - priced in USD per troy ounce
        let goldUrl = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/GC=F?interval=\(interval)&range=\(period)")!
        let fxUrl = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/EURUSD=X?interval=\(interval)&range=\(period)")!
        
        do {
            // Fetch gold prices and FX rates in parallel
            async let goldData = session.data(from: goldUrl)
            async let fxData = session.data(from: fxUrl)
            
            let (goldResult, fxResult) = try await (goldData, fxData)
            
            // Parse gold prices
            guard let goldJson = try? JSONSerialization.jsonObject(with: goldResult.0) as? [String: Any],
                  let goldChart = goldJson["chart"] as? [String: Any],
                  let goldResults = goldChart["result"] as? [[String: Any]],
                  let goldFirst = goldResults.first,
                  let goldTimestamps = goldFirst["timestamp"] as? [Int],
                  let goldIndicators = goldFirst["indicators"] as? [String: Any],
                  let goldQuote = (goldIndicators["quote"] as? [[String: Any]])?.first,
                  let goldCloses = goldQuote["close"] as? [Double?] else {
                print("[Gold Futures] Failed to parse gold futures data")
                return []
            }
            
            // Parse FX rates
            var fxRates: [String: Double] = [:]
            if let fxJson = try? JSONSerialization.jsonObject(with: fxResult.0) as? [String: Any],
               let fxChart = fxJson["chart"] as? [String: Any],
               let fxResults = fxChart["result"] as? [[String: Any]],
               let fxFirst = fxResults.first,
               let fxTimestamps = fxFirst["timestamp"] as? [Int],
               let fxIndicators = fxFirst["indicators"] as? [String: Any],
               let fxQuote = (fxIndicators["quote"] as? [[String: Any]])?.first,
               let fxCloses = fxQuote["close"] as? [Double?] {
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                
                for (index, timestamp) in fxTimestamps.enumerated() {
                    if let rate = fxCloses[index] {
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        let dateString = formatter.string(from: date)
                        fxRates[dateString] = rate
                    }
                }
            }
            
            // Get most recent FX rate as fallback (use max date key)
            let currentFxRate = fxRates.keys.max().flatMap { fxRates[$0] } ?? 1.0
            
            // Convert gold prices from USD to EUR
            var prices: [Price] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            for (index, timestamp) in goldTimestamps.enumerated() {
                guard let usdPrice = goldCloses[index] else { continue }
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let dateString = formatter.string(from: date)
                
                // Use date-specific FX rate or fallback to current
                let fxRate = fxRates[dateString] ?? currentFxRate
                let eurPrice = fxRate > 0 ? usdPrice / fxRate : usdPrice
                
                prices.append(Price(
                    id: nil,
                    isin: isin,
                    date: dateString,
                    value: round(eurPrice * 100) / 100,  // Round to 2 decimal places
                    currency: "EUR"
                ))
            }
            
            print("[Gold Futures] Found \(prices.count) historical prices (converted to EUR)")
            return prices
            
        } catch {
            print("[Gold Futures] Failed to fetch historical data: \(error)")
            return []
        }
    }
    
    func fetchHistoricalData(isin: String, ticker: String?, period: String = "1y", interval: String = "1mo") async -> [Price] {
        // Veracash - no historical data available
        if isin.starts(with: "VERACASH:") {
            print("Historical data not available for \(isin) (scraped data)")
            return []
        }
        
        // AuCOFFRE coins - scrape historical data from quotation pages
        if isin.starts(with: "COIN:") {
            if isin == "COIN:GOLD_BAR_1OZ" {
                // Gold bar uses Yahoo Finance gold futures (GC=F) as proxy
                return await fetchGoldFuturesHistory(isin: isin, period: period, interval: interval)
            } else {
                // Other coins: scrape from AuCOFFRE (limited to ~6 months)
                return await scrapeAuCoffreHistorical(isin: isin)
            }
        }
        
        let coreIsin = coreIsinForLookup(isin)
        var resolvedTicker = ticker
        if resolvedTicker == nil || resolvedTicker == "N/A" {
            resolvedTicker = await resolveIsinToTicker(isin: coreIsin)
        }
        let isValidIsin = coreIsin.count == 12 && coreIsin.allSatisfy { $0.isLetter || $0.isNumber }
        if resolvedTicker == nil && !isValidIsin {
            resolvedTicker = isin
        }
        
        guard let primaryTicker = resolvedTicker else { return [] }
        
        // Try primary ticker first (e.g. LU0169518387.SG from Yahoo search)
        var prices = await fetchHistoricalPricesFromYahooChart(tickerSymbol: primaryTicker, isin: isin, period: period, interval: interval)
        
        // If no data and identifier is "ISIN:CURRENCY", try full identifier as Yahoo symbol (e.g. LU0169518387:USD)
        if prices.isEmpty && isin.contains(":"), primaryTicker != isin {
            print("[MarketData] No data for \(primaryTicker), trying full identifier as ticker: \(isin)")
            prices = await fetchHistoricalPricesFromYahooChart(tickerSymbol: isin, isin: isin, period: period, interval: interval)
        }
        
        // Last fallback: try core ISIN only (e.g. LU0169518387)
        if prices.isEmpty && isValidIsin && coreIsin != primaryTicker {
            print("[MarketData] No data for \(primaryTicker)/\(isin), trying core ISIN: \(coreIsin)")
            prices = await fetchHistoricalPricesFromYahooChart(tickerSymbol: coreIsin, isin: isin, period: period, interval: interval)
        }
        
        return prices
    }
    
    /// Fetches historical prices from Yahoo Finance for a single ticker symbol. Used by backfill to try multiple tickers with visible logging.
    func fetchHistoricalDataForTicker(isin: String, ticker: String, period: String = "1y", interval: String = "1mo") async -> [Price] {
        await fetchHistoricalPricesFromYahooChart(tickerSymbol: ticker, isin: isin, period: period, interval: interval)
    }
    
    private func fetchHistoricalPricesFromYahooChart(tickerSymbol: String, isin: String, period: String, interval: String) async -> [Price] {
        let encoded = urlEncodedTicker(tickerSymbol)
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=\(interval)&range=\(period)") else { return [] }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let result = results.first else {
                return []
            }
            
            var currency = "USD"
            if let meta = result["meta"] as? [String: Any] {
                currency = meta["currency"] as? String ?? "USD"
            }
            
            guard let timestamps = result["timestamp"] as? [Int],
                  let indicators = result["indicators"] as? [String: Any],
                  let quote = (indicators["quote"] as? [[String: Any]])?.first,
                  let closes = quote["close"] as? [Double?] else {
                return []
            }
            
            var prices: [Price] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            for (index, timestamp) in timestamps.enumerated() {
                guard let close = closes[index] else { continue }
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let dateString = formatter.string(from: date)
                
                prices.append(Price(
                    id: nil,
                    isin: isin,
                    date: dateString,
                    value: close,
                    currency: currency
                ))
            }
            
            return prices
        } catch {
            print("Historical data fetch failed for \(tickerSymbol): \(error)")
            return []
        }
    }
    
    /// Fetches S&P 500 index daily history from Yahoo Finance (^GSPC) for benchmark comparison.
    /// Store with isin SP500IndexIsin; call in background after instrument price updates.
    func fetchSP500History(period: String = "2y", interval: String = "1d") async -> [Price] {
        await fetchHistoricalPricesFromYahooChart(tickerSymbol: "^GSPC", isin: SP500IndexIsin, period: period, interval: interval)
    }
    
    func fetchHistoricalRates(from fromCurrency: String, to toCurrency: String, period: String = "1y", interval: String = "1mo") async -> [ExchangeRate] {
        let pair = "\(fromCurrency)\(toCurrency)=X"
        
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(pair)?interval=\(interval)&range=\(period)")!
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let result = results.first else {
                return []
            }
            
            guard let timestamps = result["timestamp"] as? [Int],
                  let indicators = result["indicators"] as? [String: Any],
                  let quote = (indicators["quote"] as? [[String: Any]])?.first,
                  let closes = quote["close"] as? [Double?] else {
                return []
            }
            
            var rates: [ExchangeRate] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            for (index, timestamp) in timestamps.enumerated() {
                guard let close = closes[index] else { continue }
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let dateString = formatter.string(from: date)
                
                rates.append(ExchangeRate(
                    id: nil,
                    date: dateString,
                    fromCurrency: fromCurrency,
                    toCurrency: toCurrency,
                    rate: close
                ))
            }
            
            return rates
        } catch {
            print("Historical rates fetch failed for \(pair): \(error)")
            return []
        }
    }
}
