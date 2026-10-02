import Foundation

struct PortfolioCashflow: Equatable, Sendable {
    let date: String
    let amountEUR: Double
}

struct DashboardDerivedSeries: Sendable {
    let investedCapital: [(date: Date, value: Double)]
    let sp500: [(date: Date, value: Double)]
    let gold: [(date: Date, value: Double)]
    let msciWorld: [(date: Date, value: Double)]
    let timeWeightedReturn: Double?
}

struct PortfolioChartEvent: Identifiable, Equatable {
    let id: String
    let date: Date
    let accountId: Int
    let isin: String
    let kind: HoldingTransactionKind
    let amountEUR: Double

    init(transaction: HoldingTransaction, amountEUR: Double) {
        id = "\(transaction.id ?? 0)-\(transaction.accountId)-\(transaction.isin)-\(transaction.date)"
        date = AppDateFormatter.yearMonthDay.date(from: transaction.date) ?? .distantPast
        accountId = transaction.accountId
        isin = transaction.isin
        kind = transaction.kind
        self.amountEUR = amountEUR
    }
}

struct DashboardSnapshot {
    var portfolio: [(date: Date, value: Double)] = []
    var investedCapital: [(date: Date, value: Double)] = []
    var sp500: [(date: Date, value: Double)] = []
    var gold: [(date: Date, value: Double)] = []
    var msciWorld: [(date: Date, value: Double)] = []
    var goldOunces: [(date: Date, value: Double)] = []
    var events: [PortfolioChartEvent] = []
    var timeWeightedReturn: Double?
    var gainEUR: Double?
}

enum PortfolioAnalytics {
    /// Runs CPU-only dashboard derivations on the cooperative executor instead of
    /// blocking the main actor that publishes the finished snapshot.
    nonisolated static func deriveDashboardSeries(
        portfolio: [(date: Date, value: Double)],
        allCashflows: [PortfolioCashflow],
        periodCashflows: [PortfolioCashflow],
        sp500Index: [(date: String, value: Double)],
        goldIndex: [(date: String, value: Double)],
        msciWorldIndex: [(date: String, value: Double)]
    ) async -> DashboardDerivedSeries {
        let nav = portfolio.map {
            (AppDateFormatter.yearMonthDay.string(from: $0.date), $0.value)
        }
        return DashboardDerivedSeries(
            investedCapital: investedCapitalSeries(dates: portfolio.map(\.date), cashflows: allCashflows),
            sp500: benchmarkSeries(portfolio: portfolio, benchmark: sp500Index, cashflows: periodCashflows),
            gold: benchmarkSeries(portfolio: portfolio, benchmark: goldIndex, cashflows: periodCashflows),
            msciWorld: benchmarkSeries(portfolio: portfolio, benchmark: msciWorldIndex, cashflows: periodCashflows),
            timeWeightedReturn: PortfolioHistoryBuilder.timeWeightedReturn(
                nav: nav,
                cashflows: periodCashflows.map { ($0.date, $0.amountEUR) }
            )
        )
    }

    static func cashflowsByDate(_ cashflows: [PortfolioCashflow]) -> [String: Double] {
        Dictionary(grouping: cashflows, by: \.date)
            .mapValues { $0.reduce(0) { $0 + $1.amountEUR } }
    }

    static func investedCapitalSeries(
        dates: [Date],
        cashflows: [PortfolioCashflow]
    ) -> [(date: Date, value: Double)] {
        let ordered = cashflows.sorted { $0.date < $1.date }
        var flowIndex = 0
        var invested = 0.0
        var result: [(date: Date, value: Double)] = []
        result.reserveCapacity(dates.count)
        for date in dates {
            let dateString = AppDateFormatter.yearMonthDay.string(from: date)
            while flowIndex < ordered.count, ordered[flowIndex].date <= dateString {
                invested += ordered[flowIndex].amountEUR
                flowIndex += 1
            }
            result.append((date, invested))
        }
        return result
    }

    /// Simulates an index portfolio receiving the same external flows as the real
    /// portfolio. This makes benchmark lines comparable when positions change.
    static func benchmarkSeries(
        portfolio: [(date: Date, value: Double)],
        benchmark: [(date: String, value: Double)],
        cashflows: [PortfolioCashflow]
    ) -> [(date: Date, value: Double)] {
        guard let first = portfolio.first else { return [] }
        let firstDate = AppDateFormatter.yearMonthDay.string(from: first.date)
        guard let firstPrice = PortfolioHistoryBuilder.priceOnOrBefore(index: benchmark, date: firstDate),
              firstPrice > 0 else { return [] }

        let groupedFlows = cashflowsByDate(cashflows)
        var units = first.value / firstPrice
        var result: [(date: Date, value: Double)] = []
        result.reserveCapacity(portfolio.count)

        for (index, point) in portfolio.enumerated() {
            let dateString = AppDateFormatter.yearMonthDay.string(from: point.date)
            guard let price = PortfolioHistoryBuilder.priceOnOrBefore(index: benchmark, date: dateString),
                  price > 0 else { continue }
            if index > 0, let flow = groupedFlows[dateString] {
                units += flow / price
            }
            result.append((point.date, max(0, units * price)))
        }
        return result
    }

    static func rebasedPercent(
        _ series: [(date: Date, value: Double)]
    ) -> [(date: Date, value: Double)] {
        guard let first = series.first?.value, first > 0 else { return [] }
        return series.map { ($0.date, (($0.value / first) - 1) * 100) }
    }
}
