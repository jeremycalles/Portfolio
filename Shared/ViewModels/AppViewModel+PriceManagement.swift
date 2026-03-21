import Foundation

// MARK: - Refresh Result
struct RefreshResult: Identifiable {
    let id = UUID()
    let successCount: Int
    let failureCount: Int
    let totalCount: Int
    let failedInstruments: [String]
    let timestamp: Date
    /// When all instruments fail, this may contain the first network/data error (e.g. for iOS diagnostics).
    let lastError: String?
    /// Per-instrument failure reasons for debugging (e.g. "JPMorgan Asia...: Yahoo: HTTP 403").
    let debugLogLines: [String]
    
    var succeeded: Bool { failureCount == 0 }
}

extension AppViewModel {
    // MARK: - Manual Price Management
    func addManualPrice(isin: String, date: String, value: Double, currency: String) async {
        let price = Price(id: nil, isin: isin, date: date, value: value, currency: currency)
        await db.addPrice(price)
    }
    
    // MARK: - Update Prices

    /// Use from SwiftUI `.refreshable` so the refresh is not cancelled when the user releases.
    /// Await the returned task; catch `CancellationError` to allow dismissal while refresh continues.
    func startRefreshTask(showCompletionDelay: Bool = false) -> Task<Void, Never> {
        Task.detached(priority: .userInitiated) { [self] in
            await self.updateAllPrices(showCompletionDelay: showCompletionDelay)
        }
    }

    func updateAllPrices(showCompletionDelay: Bool = true) async {
        isLoading = true
        let total = instruments.count
        let batchSize = 4
        var successCount = 0
        var failedNames: [String] = []
        var failedReasons: [String] = []
        
        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, total)
            let batch = Array(instruments[batchStart..<batchEnd])
            
            statusMessage = "Updating \(min(batchEnd, total))/\(total)..."
            
            // Fetch prices concurrently within the batch
            let results: [(Instrument, MarketDataResult)] = await withTaskGroup(of: (Instrument, MarketDataResult).self, returning: [(Instrument, MarketDataResult)].self) { group in
                for instrument in batch {
                    group.addTask {
                        let result = await self.marketData.fetchData(isin: instrument.isin, ticker: instrument.ticker)
                        return (instrument, result)
                    }
                }
                var collected: [(Instrument, MarketDataResult)] = []
                for await pair in group {
                    collected.append(pair)
                }
                return collected
            }
            
            for (instrument, result) in results {
                if let value = result.value {
                    let price = Price(
                        id: nil,
                        isin: instrument.isin,
                        date: result.date,
                        value: value,
                        currency: result.currency
                    )
                    await db.addPrice(price)
                    successCount += 1
                } else {
                    failedNames.append(instrument.displayName)
                    let reason = result.failureReason ?? "unknown"
                    failedReasons.append("\(instrument.displayName): \(reason)")
                }
            }
            
            // Inter-batch courtesy delay to reduce chance of 429
            if batchEnd < total {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Update exchange rates
        statusMessage = "Updating exchange rates..."
        if let rate = await marketData.fetchExchangeRate(from: "USD", to: "EUR") {
            await db.addExchangeRate(rate)
        }
        
        statusMessage = "Update complete!"
        isLoading = false
        
        // When all failed, capture first error from MarketDataService for diagnostics (e.g. iOS network)
        let diagnosticError: String? = (failedNames.count == total && total > 0)
            ? await marketData.takeLastFetchError()
            : nil
        
        // Store refresh result for banner display (with per-instrument debug log when there are failures)
        refreshResult = RefreshResult(
            successCount: successCount,
            failureCount: failedNames.count,
            totalCount: total,
            failedInstruments: failedNames,
            timestamp: Date(),
            lastError: diagnosticError,
            debugLogLines: failedReasons
        )
        
        // Align with Settings "Last refresh" (same key as iOS BackgroundTaskManager)
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
        
        await refreshAll()
        
        await fetchAndStoreBenchmarksInBackground()
        await recomputeDashboardCache()
        
        // Clear status after delay (skip for pull-to-refresh)
        if showCompletionDelay {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        statusMessage = ""
    }
    
    /// Fetches benchmark (S&P 500, Gold, MSCI World) daily history in parallel and stores in the prices table.
    func fetchAndStoreBenchmarksInBackground() async {
        // Fetch all three benchmarks in parallel
        async let sp500Prices = marketData.fetchSP500History(period: "2y", interval: "1d")
        async let goldPrices = marketData.fetchGoldHistory(period: "2y", interval: "1d")
        async let msciPrices = marketData.fetchMSCIWorldHistory(period: "2y", interval: "1d")
        
        let (sp500Result, goldResult, msciResult) = await (sp500Prices, goldPrices, msciPrices)
        
        for price in sp500Result { await db.addPrice(price) }
        for price in goldResult { await db.addPrice(price) }
        for price in msciResult { await db.addPrice(price) }
    }
    
    // MARK: - Backfill Historical Data
    func backfillHistorical(period: String = "1y", interval: String = "1mo") async {
        isLoading = true
        let total = instruments.count
        
        for (index, instrument) in instruments.enumerated() {
            statusMessage = "Backfilling \(index + 1)/\(total): \(instrument.displayName)"
            
            let prices = await marketData.fetchHistoricalData(
                isin: instrument.isin,
                ticker: instrument.ticker,
                period: period,
                interval: interval
            )
            
            for price in prices {
                await db.addPrice(price)
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        statusMessage = "Backfilling exchange rates..."
        let rates = await marketData.fetchHistoricalRates(from: "USD", to: "EUR", period: period, interval: interval)
        for rate in rates {
            await db.addExchangeRate(rate)
        }
        
        statusMessage = "Backfill complete!"
        isLoading = false
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        statusMessage = ""
    }
    
    // MARK: - Backfill Single Instrument
    func backfillSingleInstrument(_ instrument: Instrument, period: String = "1y", interval: String = "1mo", silent: Bool = false) async {
        if !silent {
            isLoading = true
            backfillLogs = []
            
            let timestamp = AppDateFormatter.yearMonthDayTime.string(from: Date())
            
            backfillLogs.append("[\(timestamp)] Starting backfill for \(instrument.displayName)")
            backfillLogs.append("[\(timestamp)] ISIN: \(instrument.isin)")
            backfillLogs.append("[\(timestamp)] Ticker: \(instrument.ticker ?? "N/A")")
            backfillLogs.append("[\(timestamp)] Period: \(period), Interval: \(interval)")
            backfillLogs.append("")
            
            statusMessage = "Backfilling: \(instrument.displayName)"
        }
        
        // Build list of tickers to try (primary, then "ISIN:CURRENCY" if applicable, then core ISIN)
        let coreIsin: String = {
            let id = instrument.isin
            if let colon = id.firstIndex(of: ":"), id.distance(from: id.startIndex, to: colon) == 12 {
                let prefix = String(id[..<colon])
                if prefix.allSatisfy({ $0.isLetter || $0.isNumber }) { return prefix }
            }
            return id
        }()
        var tickersToTry: [String] = [instrument.ticker ?? "N/A"].filter { $0 != "N/A" }
        if tickersToTry.isEmpty, coreIsin.count == 12 {
            let resolved = await marketData.resolveIsinToTicker(isin: coreIsin)
            tickersToTry = [resolved ?? coreIsin].filter { $0 != "N/A" }
        }
        if instrument.isin.contains(":"), !tickersToTry.contains(instrument.isin) {
            tickersToTry.append(instrument.isin)
        }
        if coreIsin.count == 12, coreIsin != instrument.isin, !tickersToTry.contains(coreIsin) {
            tickersToTry.append(coreIsin)
        }
        
        var prices: [Price] = []
        for ticker in tickersToTry {
            let ts = AppDateFormatter.yearMonthDayTime.string(from: Date())
            if !silent { backfillLogs.append("[\(ts)] Trying ticker: \(ticker)") }
            let result = await marketData.fetchHistoricalDataForTicker(isin: instrument.isin, ticker: ticker, period: period, interval: interval)
            let ts2 = AppDateFormatter.yearMonthDayTime.string(from: Date())
            if result.isEmpty {
                if !silent { backfillLogs.append("[\(ts2)]   → No data") }
            } else {
                if !silent { backfillLogs.append("[\(ts2)]   → ✓ \(result.count) price records") }
                prices = result
                break
            }
        }
        
        let fetchTimestamp = AppDateFormatter.yearMonthDayTime.string(from: Date())
        if !silent {
            if prices.isEmpty {
                backfillLogs.append("")
                backfillLogs.append("[\(fetchTimestamp)] ⚠️ No data returned from Yahoo Finance (tried \(tickersToTry.count) ticker(s))")
                backfillLogs.append("[\(fetchTimestamp)] This may happen if:")
                backfillLogs.append("  • The fund/instrument has no historical chart data on Yahoo Finance")
                backfillLogs.append("  • Yahoo Finance API rate limit was hit")
                backfillLogs.append("")
            } else {
                backfillLogs.append("")
                backfillLogs.append("[\(fetchTimestamp)] ✓ Fetched \(prices.count) price records")
            }
        }
        
        var addedCount = 0
        var skippedCount = 0
        
        let existingDates = Set((await db.getPriceHistory(forIsin: instrument.isin)).map { $0.date })
        for price in prices {
            if !existingDates.contains(price.date) {
                await db.addPrice(price)
                addedCount += 1
            } else {
                skippedCount += 1
            }
        }
        
        let saveTimestamp = AppDateFormatter.yearMonthDayTime.string(from: Date())
        if !silent {
            if addedCount > 0 {
                backfillLogs.append("[\(saveTimestamp)] ✓ Added \(addedCount) new prices")
            } else if !prices.isEmpty {
                backfillLogs.append("[\(saveTimestamp)] No new prices to add (all already exist)")
            }
            if skippedCount > 0 {
                backfillLogs.append("[\(saveTimestamp)] Skipped \(skippedCount) existing prices")
            }
        }
        
        // Backfill exchange rates if instrument is not EUR
        if let currency = instrument.currency, currency != "EUR" {
            if !silent {
                backfillLogs.append("")
                backfillLogs.append("[\(saveTimestamp)] Backfilling \(currency)/EUR exchange rates...")
            }
            
            let rates = await marketData.fetchHistoricalRates(from: currency, to: "EUR", period: period, interval: interval)
            
            for rate in rates {
                await db.addExchangeRate(rate)
            }
            
            if !silent {
                let rateTimestamp = AppDateFormatter.yearMonthDayTime.string(from: Date())
                backfillLogs.append("[\(rateTimestamp)] Fetched \(rates.count) exchange rates")
            }
        }
        
        if !silent {
            let endTimestamp = AppDateFormatter.yearMonthDayTime.string(from: Date())
            backfillLogs.append("")
            backfillLogs.append("[\(endTimestamp)] Backfill complete!")
            
            statusMessage = ""
            isLoading = false
            showBackfillLogs = true
        }
    }
}
