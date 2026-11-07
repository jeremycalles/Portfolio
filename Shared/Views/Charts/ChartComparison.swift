import SwiftUI

/// A series drawn next to the main line of `PortfolioTrendChart`.
struct ChartComparison: Identifiable {
    enum Kind {
        /// Index levels scaled like the same money invested: goes through the
        /// chart's own display logic, with the whole portfolio's cashflows.
        case benchmark
        /// A return in percent computed elsewhere (a quadrant, with its own
        /// cashflows). Drawn as is, and only in return mode.
        case precomputedReturn
    }

    enum Group {
        case index
        case quadrant
    }

    let id: String
    let label: String
    let color: Color
    let history: [(date: Date, value: Double)]
    var kind: Kind = .benchmark
    var group: Group = .index

    static let sp500ID = "index.sp500"
    static let goldID = "index.gold"
    static let msciWorldID = "index.msciWorld"

    static func quadrantID(_ quadrantId: Int) -> String { "quadrant.\(quadrantId)" }
}

enum ChartComparisonSelection {
    /// At most this many comparisons next to the main line.
    static let limit = 3
    static let defaultValue = [ChartComparison.msciWorldID, ChartComparison.sp500ID, ChartComparison.goldID].joined(separator: ",")
    static let storageKey = "chartComparisons"

    static func ids(_ stored: String) -> [String] {
        stored.split(separator: ",").map(String.init)
    }

    /// Adds `id`, dropping the oldest choice when the limit is reached.
    static func adding(_ id: String, to stored: String) -> String {
        var values = ids(stored).filter { $0 != id }
        values.append(id)
        if values.count > limit { values.removeFirst(values.count - limit) }
        return values.joined(separator: ",")
    }

    static func removing(_ id: String, from stored: String) -> String {
        ids(stored).filter { $0 != id }.joined(separator: ",")
    }

    static func quadrantIDs(_ stored: String) -> [Int] {
        ids(stored).compactMap { $0.hasPrefix("quadrant.") ? Int($0.dropFirst("quadrant.".count)) : nil }
    }
}
