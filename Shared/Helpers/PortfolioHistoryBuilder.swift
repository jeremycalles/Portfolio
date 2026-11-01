import Foundation

/// Pure helpers for period charts and performance %.
/// Live holdings are a snapshot; historical quantity comes from buy/sell lots when present.
enum PortfolioHistoryBuilder {
    /// Binary search for the last entry whose date <= target. `index` must be ascending by date.
    static func priceOnOrBefore(index: [(date: String, value: Double)], date: String) -> Double? {
        guard !index.isEmpty else { return nil }
        var lo = 0, hi = index.count - 1
        var result: Int? = nil
        while lo <= hi {
            let mid = (lo + hi) / 2
            if index[mid].date <= date {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        guard let idx = result else { return nil }
        return index[idx].value
    }

    /// Sum of signed lots with `tx.date <= date`. Empty lots → `fallbackQuantity` (legacy “always held”).
    static func quantityOnDate(
        transactions: [(date: String, quantityDelta: Double)],
        date: String,
        fallbackQuantity: Double
    ) -> Double {
        if transactions.isEmpty { return fallbackQuantity }
        var qty = 0.0
        for tx in transactions where tx.date <= date {
            qty += tx.quantityDelta
        }
        return max(0, qty)
    }

    /// Quantity held on `date`, derived exclusively from the transaction ledger.
    /// `liveQuantity` and `today` remain in the signature for source compatibility.
    static func quantityActuallyHeld(
        transactions: [(date: String, quantityDelta: Double)],
        date: String,
        liveQuantity: Double,
        today: String
    ) -> Double {
        var qty = 0.0
        for tx in transactions where tx.date <= date {
            qty += tx.quantityDelta
        }
        return max(0, qty)
    }

    /// Unique sorted dates in `[cutoff, today]`, including endpoints, prices, and cashflow dates.
    static func chartDates(
        cutoff: String,
        today: String,
        priceDates: [[String]],
        transactionDates: [String] = []
    ) -> [String] {
        guard cutoff <= today else { return [] }
        var dates: Set<String> = [cutoff, today]
        for series in priceDates {
            for date in series where date >= cutoff && date <= today {
                dates.insert(date)
            }
        }
        for date in transactionDates where date >= cutoff && date <= today {
            dates.insert(date)
        }
        return dates.sorted()
    }

    /// Builds a converted series from ledger quantities and known prices.
    /// A position only enters the series on or after its first known market price.
    static func series(
        dates: [String],
        holdings: [(isin: String, quantity: Double)],
        prices: [String: [(date: String, value: Double)]],
        transactionsByIsin: [String: [(date: String, quantityDelta: Double)]] = [:],
        today: String,
        convert: (String, Double, String) async -> Double?
    ) async -> [(date: String, value: Double)] {
        guard !holdings.isEmpty else { return [] }
        var result: [(date: String, value: Double)] = []
        result.reserveCapacity(dates.count)

        for date in dates {
            var total = 0.0
            var complete = true
            for holding in holdings {
                let qty = quantityActuallyHeld(
                    transactions: transactionsByIsin[holding.isin] ?? [],
                    date: date,
                    liveQuantity: holding.quantity,
                    today: today
                )
                if qty <= 0 { continue }
                guard let price = priceOnOrBefore(index: prices[holding.isin] ?? [], date: date) else {
                    complete = false
                    break
                }
                let native = qty * price
                if let converted = await convert(holding.isin, native, date) {
                    total += converted
                } else {
                    complete = false
                    break
                }
            }
            if complete {
                result.append((date: date, value: total))
            }
        }
        return result
    }

    static func percentChange(from first: Double, to last: Double) -> Double? {
        guard first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    /// Time-weighted return in percent. `nav` values on a cashflow date are *after* the cashflow.
    /// Cashflows with date equal to the first NAV point are ignored (already in the start value).
    static func timeWeightedReturn(
        nav: [(date: String, value: Double)],
        cashflows: [(date: String, amountEUR: Double)]
    ) -> Double? {
        timeWeightedReturnSeries(nav: nav, cashflows: cashflows).last?.value
    }

    /// The curve and headline share one calculation. NAV observations are after
    /// flows; contributions never appear as investment gains. A fully withdrawn
    /// portfolio retains its earned return until it is funded again.
    static func timeWeightedReturnSeries(
        nav: [(date: String, value: Double)],
        cashflows: [(date: String, amountEUR: Double)]
    ) -> [(date: String, value: Double)] {
        guard let first = nav.first, first.value.isFinite, first.value >= 0 else { return [] }
        let flows = cashflows.filter { $0.date > first.date }.sorted { $0.date < $1.date }
        var flowIndex = 0
        var previous = first.value
        var factor = 1.0
        var started = previous > 0
        var result: [(date: String, value: Double)] = started ? [(first.date, 0)] : []
        for point in nav.dropFirst() {
            guard point.value.isFinite, point.value >= 0 else { return [] }
            var flow = 0.0
            while flowIndex < flows.count, flows[flowIndex].date <= point.date {
                flow += flows[flowIndex].amountEUR
                flowIndex += 1
            }
            if previous > 0 {
                let beforeFlow = point.value - flow
                guard beforeFlow >= -1e-9, beforeFlow.isFinite else { return [] }
                factor *= max(0, beforeFlow) / previous
            } else if point.value > 0 {
                // Without a recorded contribution there is no defensible return
                // for a position that previously had zero value.
                guard flow > 0 else { return [] }
                started = true
            }
            previous = point.value
            if started { result.append((point.date, (factor - 1) * 100)) }
        }
        return result
    }
}
