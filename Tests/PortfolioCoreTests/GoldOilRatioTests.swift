import Testing
@testable import PortfolioMultiplatform

@Suite("GoldOilRatio")
struct GoldOilRatioTests {
    @Test("divides gold by oil on a shared date")
    func sharedDate() {
        let result = GoldOilRatio.ratioSeries(gold: [("2024-01-02", 2000)], oil: [("2024-01-02", 80)])
        #expect(result.count == 1 && result[0].value == 25)
    }

    @Test("uses the last known price when a series skips a date")
    func alignsOnOrBefore() {
        let gold = [("2024-01-01", 2000.0), ("2024-01-02", 2100.0), ("2024-01-03", 2200.0)]
        let oil = [("2024-01-01", 100.0), ("2024-01-03", 110.0)]
        let result = GoldOilRatio.ratioSeries(gold: gold, oil: oil)
        #expect(result.map(\.date) == ["2024-01-01", "2024-01-02", "2024-01-03"])
        #expect(result[1].value == 21) // 2100 / 100, oil still at its 01-01 price
        #expect(result[2].value == 20)
    }

    @Test("skips dates before both series have started")
    func noPriceYet() {
        let result = GoldOilRatio.ratioSeries(
            gold: [("2024-01-05", 2000)],
            oil: [("2024-01-10", 80)]
        )
        #expect(result.map(\.date) == ["2024-01-10"])
    }

    @Test("ignores zero and negative prices")
    func ignoresNonPositive() {
        let gold = [("2024-01-01", 2000.0), ("2024-01-02", 2000.0)]
        let oil = [("2024-01-01", 80.0), ("2024-01-02", -37.0)]
        let result = GoldOilRatio.ratioSeries(gold: gold, oil: oil)
        // The negative oil price is dropped, so 01-02 carries the 01-01 oil price forward.
        #expect(result.count == 2 && result.allSatisfy { $0.value == 25 })
        #expect(GoldOilRatio.ratioSeries(gold: [("2024-01-01", 0)], oil: [("2024-01-01", 80)]).isEmpty)
    }

    @Test("an empty side gives an empty ratio")
    func emptyInput() {
        #expect(GoldOilRatio.ratioSeries(gold: [], oil: [("2024-01-01", 80)]).isEmpty)
    }
}
