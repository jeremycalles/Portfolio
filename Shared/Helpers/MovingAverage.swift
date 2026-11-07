import Foundation

/// Trailing moving-average windows offered on detail charts.
enum MovingAverageWindow: String, CaseIterable, Identifiable, Hashable {
    case days30 = "30d"
    case days200 = "200d"
    case years7 = "7y"

    var id: String { rawValue }

    /// Calendar length of the window. "200 days" follows the market convention
    /// of 200 trading sessions, about 40 calendar weeks.
    var lengthInDays: Double {
        switch self {
        case .days30: return 30
        case .days200: return 280
        case .years7: return 7 * 365.25
        }
    }

    var label: String {
        switch self {
        case .days30: return L10n.chartMovingAverage30d
        case .days200: return L10n.chartMovingAverage200d
        case .years7: return L10n.chartMovingAverage7y
        }
    }
}

/// Moving averages over irregular observations (daily recent prices, weekly
/// older ones). Each observation holds until the next, so the average is a
/// time integral, not a mean of the last N points.
enum MovingAverage {
    private static let secondsPerDay = 86_400.0

    private struct StepSeries {
        let days: [Double]
        let values: [Double]
        /// Integral of the step function from `days[0]` to `days[i]`.
        let cumulative: [Double]

        init?(_ points: [(date: Date, value: Double)]) {
            let sorted = points
                .filter { $0.value.isFinite }
                .sorted { $0.date < $1.date }
            var days: [Double] = []
            var values: [Double] = []
            for point in sorted {
                let day = point.date.timeIntervalSinceReferenceDate / MovingAverage.secondsPerDay
                if let last = days.last, abs(last - day) < 1e-9 {
                    values[values.count - 1] = point.value
                } else {
                    days.append(day)
                    values.append(point.value)
                }
            }
            guard !days.isEmpty else { return nil }
            var cumulative = [0.0]
            cumulative.reserveCapacity(days.count)
            for i in 1..<days.count {
                cumulative.append(cumulative[i - 1] + values[i - 1] * (days[i] - days[i - 1]))
            }
            self.days = days
            self.values = values
            self.cumulative = cumulative
        }

        /// Last index whose day is on or before `day`.
        func index(atOrBefore day: Double) -> Int? {
            guard day >= days[0] else { return nil }
            var lo = 0
            var hi = days.count - 1
            while lo < hi {
                let mid = (lo + hi + 1) / 2
                if days[mid] <= day { lo = mid } else { hi = mid - 1 }
            }
            return lo
        }

        func integral(to day: Double) -> Double? {
            guard let i = index(atOrBefore: day) else { return nil }
            return cumulative[i] + values[i] * (day - days[i])
        }

        func value(at day: Double) -> Double? {
            index(atOrBefore: day).map { values[$0] }
        }
    }

    /// Trailing average at each of `dates`. A date gets no value until a full
    /// window of observations precedes it.
    static func series(
        _ points: [(date: Date, value: Double)],
        window: MovingAverageWindow,
        at dates: [Date]
    ) -> [(date: Date, value: Double)] {
        guard let steps = StepSeries(points) else { return [] }
        return dates.compactMap { date in
            average(steps, window: window, endingAt: date).map { (date, $0) }
        }
    }

    /// Average divided by the series value at each date. Multiplying any line
    /// proportional to `points` by this ratio draws the average on that line's
    /// scale, so crossings and gaps stay exact without currency conversion.
    static func ratios(
        _ points: [(date: Date, value: Double)],
        window: MovingAverageWindow,
        at dates: [Date]
    ) -> [(date: Date, value: Double)] {
        guard let steps = StepSeries(points) else { return [] }
        return dates.compactMap { date in
            let day = date.timeIntervalSinceReferenceDate / secondsPerDay
            guard let current = steps.value(at: day), current > 0,
                  let average = average(steps, window: window, endingAt: date) else { return nil }
            let ratio = average / current
            return ratio.isFinite ? (date, ratio) : nil
        }
    }

    /// Ratios for every window, omitting windows without enough history.
    static func ratiosByWindow(
        _ points: [(date: Date, value: Double)],
        at dates: [Date]
    ) -> [MovingAverageWindow: [(date: Date, value: Double)]] {
        var result: [MovingAverageWindow: [(date: Date, value: Double)]] = [:]
        for window in MovingAverageWindow.allCases {
            let ratios = ratios(points, window: window, at: dates)
            if !ratios.isEmpty { result[window] = ratios }
        }
        return result
    }

    private static func average(_ steps: StepSeries, window: MovingAverageWindow, endingAt date: Date) -> Double? {
        let end = date.timeIntervalSinceReferenceDate / secondsPerDay
        let start = end - window.lengthInDays
        guard start >= steps.days[0],
              let to = steps.integral(to: end),
              let from = steps.integral(to: start) else { return nil }
        let average = (to - from) / window.lengthInDays
        return average.isFinite ? average : nil
    }
}
