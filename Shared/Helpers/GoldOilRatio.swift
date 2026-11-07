import Foundation

/// Gold price divided by Brent price: barrels of oil one ounce of gold buys.
/// Both are quoted in USD, so the ratio has no unit and needs no FX rate.
enum GoldOilRatio {
    /// Ratio on every date where both series have a price on or before it.
    /// Prices that are zero, negative or not finite are ignored. Inputs ascending by date.
    static func ratioSeries(
        gold: [(date: String, value: Double)],
        oil: [(date: String, value: Double)]
    ) -> [(date: String, value: Double)] {
        let gold = gold.filter { $0.value.isFinite && $0.value > 0 }
        let oil = oil.filter { $0.value.isFinite && $0.value > 0 }
        let dates = Set(gold.map(\.date)).union(oil.map(\.date)).sorted()
        return dates.compactMap { date in
            guard let goldPrice = PortfolioHistoryBuilder.priceOnOrBefore(index: gold, date: date),
                  let oilPrice = PortfolioHistoryBuilder.priceOnOrBefore(index: oil, date: date) else { return nil }
            return (date, goldPrice / oilPrice)
        }
    }
}
