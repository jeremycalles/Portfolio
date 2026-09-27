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

    /// Carry-forward, then the first known price if the series starts after `date`.
    static func priceOnOrBeforeOrFirst(index: [(date: String, value: Double)], date: String) -> Double? {
        priceOnOrBefore(index: index, date: date) ?? index.first?.value
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

    /// Quantity actually held on `date`.
    /// Lots apply on their own dates. The gap between the live quantity and the sum of lots
    /// is already held before the first lot, so a partial lot does not drop the rest of the position.
    static func quantityActuallyHeld(
        transactions: [(date: String, quantityDelta: Double)],
        date: String,
        liveQuantity: Double
    ) -> Double {
        if transactions.isEmpty { return max(0, liveQuantity) }
        let recorded = transactions.reduce(0.0) { $0 + $1.quantityDelta }
        var qty = liveQuantity - recorded
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

    /// True when lots do not add up to the live quantity, so the line keeps shares that have no lot.
    static func historyUsesUnrecordedQuantity(
        holdings: [(isin: String, quantity: Double)],
        transactionsByIsin: [String: [(date: String, quantityDelta: Double)]]
    ) -> Bool {
        for holding in holdings {
            let lots = transactionsByIsin[holding.isin] ?? []
            if lots.isEmpty { continue }
            let recorded = lots.reduce(0.0) { $0 + $1.quantityDelta }
            if abs(holding.quantity - recorded) > 0.000_1 { return true }
        }
        return false
    }

    /// Builds a converted series. Quantity is what was actually held that day.
    /// Quantity 0 on a date skips that holding (not in the portfolio yet / already sold).
    static func series(
        dates: [String],
        holdings: [(isin: String, quantity: Double)],
        prices: [String: [(date: String, value: Double)]],
        transactionsByIsin: [String: [(date: String, quantityDelta: Double)]] = [:],
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
                    liveQuantity: holding.quantity
                )
                if qty <= 0 { continue }
                guard let price = priceOnOrBeforeOrFirst(index: prices[holding.isin] ?? [], date: date) else {
                    continue
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
        guard let first = nav.first else { return nil }
        var cfByDate: [String: Double] = [:]
        for cf in cashflows {
            if abs(cf.amountEUR) > 1e-12 {
                cfByDate[cf.date, default: 0] += cf.amountEUR
            }
        }
        let startDate = first.date
        cfByDate[startDate] = nil

        if cfByDate.isEmpty {
            return percentChange(from: first.value, to: nav.last?.value ?? first.value)
        }

        var factor = 1.0
        var start = first.value
        var started = first.value > 0

        for point in nav.dropFirst() {
            if let cf = cfByDate[point.date], abs(cf) > 1e-12 {
                let before = point.value - cf
                if started, start > 0, before > 0 {
                    factor *= before / start
                }
                start = point.value
                started = start > 0
            }
        }

        guard started, start > 0, let last = nav.last else { return nil }
        factor *= last.value / start
        return (factor - 1) * 100
    }
}
