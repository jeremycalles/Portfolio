import Foundation
import Testing
@testable import PortfolioMultiplatform

@Suite("MovingAverage")
struct MovingAverageTests {
    private let origin = AppDateFormatter.yearMonthDay.date(from: "2020-01-01")!

    private func day(_ offset: Int) -> Date {
        origin.addingTimeInterval(Double(offset) * 86_400)
    }

    private func approx(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 1e-9
    }

    private func daily(_ count: Int, value: (Int) -> Double) -> [(date: Date, value: Double)] {
        (0..<count).map { (day($0), value($0)) }
    }

    @Test("a constant series averages to itself")
    func constantSeries() {
        let points = daily(100) { _ in 42 }
        let averages = MovingAverage.series(points, window: .days30, at: [day(30), day(99)])
        #expect(averages.count == 2 && averages.allSatisfy { approx($0.value, 42) })
    }

    @Test("each observation holds until the next")
    func stepFunction() {
        let points = [(day(0), 10.0), (day(15), 20.0)]
        let average = MovingAverage.series(points, window: .days30, at: [day(30)])
        #expect(approx(average.first?.value, 15))
    }

    @Test("a daily ramp averages the values held over the window")
    func dailyRamp() {
        let points = daily(61) { Double($0) }
        let average = MovingAverage.series(points, window: .days30, at: [day(60)])
        // Values 30...59 are each held for one day.
        #expect(approx(average.first?.value, 44.5))
    }

    @Test("weekly and daily observations are weighted by time")
    func mixedGranularity() {
        let weekly = stride(from: 0, to: 28, by: 7).map { (day($0), 10.0) }
        let dailyTail = (28..<30).map { (day($0), 40.0) }
        let average = MovingAverage.series(weekly + dailyTail, window: .days30, at: [day(30)])
        // 28 days at 10, then 2 days at 40.
        #expect(approx(average.first?.value, 12))
    }

    @Test("no value until a full window of history precedes the date")
    func insufficientHistory() {
        let points = daily(100) { _ in 1 }
        #expect(MovingAverage.series(points, window: .days200, at: [day(99)]).isEmpty)
        #expect(MovingAverage.series(points, window: .days30, at: [day(29)]).isEmpty)
        #expect(MovingAverage.series(points, window: .days30, at: [day(30)]).count == 1)
    }

    @Test("ratios divide the average by the current value")
    func ratios() {
        let points = [(day(0), 10.0), (day(15), 20.0)]
        let ratios = MovingAverage.ratios(points, window: .days30, at: [day(30)])
        #expect(approx(ratios.first?.value, 0.75))
    }

    @Test("ratios skip non-positive values")
    func ratiosSkipZero() {
        let points = daily(40) { $0 < 35 ? 5 : 0 }
        #expect(MovingAverage.ratios(points, window: .days30, at: [day(39)]).isEmpty)
    }

    @Test("windows without enough history are omitted")
    func ratiosByWindow() {
        let points = daily(300) { _ in 1 }
        let result = MovingAverage.ratiosByWindow(points, at: [day(299)])
        #expect(Set(result.keys) == [.days30, .days200])
    }

    @Test("a seven-year window works on monthly data")
    func sevenYearsMonthly() {
        let points = stride(from: 0, through: 2_700, by: 30).map { (day($0), 3.0) }
        let average = MovingAverage.series(points, window: .years7, at: [day(2_700)])
        #expect(approx(average.first?.value, 3))
    }

    @Test("duplicate dates keep the last observation")
    func duplicateDates() {
        let points = [(day(0), 1.0), (day(0), 5.0), (day(30), 9.0)]
        let average = MovingAverage.series(points, window: .days30, at: [day(30)])
        #expect(approx(average.first?.value, 5))
    }
}
