import XCTest
import SwiftUI
import SnapshotTesting
@testable import Portfolio

/// Snapshot tests for Dashboard UI components
/// These tests capture screenshots of UI components and compare them against reference images
/// to detect visual regressions in currency display
final class DashboardSnapshotTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Set recording mode to true to generate new reference snapshots
        // Change to false after initial snapshots are recorded
        // isRecording = true  // Uncomment to regenerate snapshots
    }
    
    // MARK: - Currency Display Snapshot Tests
    
    /// Test that currency formatting produces expected output
    func testCurrencyFormatting_EUR() throws {
        // Given: Various EUR values
        let values: [Double] = [1234.56, 0.01, 99999.99, 0.00]
        
        // When: Formatted as EUR
        for value in values {
            let formatted = formatCurrency(value, currency: "EUR")
            
            // Then: Should contain expected patterns
            XCTAssertFalse(formatted.isEmpty, "Formatted currency should not be empty")
            // EUR values should have the € symbol or EUR text
            let hasEuroSymbol = formatted.contains("€") || formatted.contains("EUR")
            XCTAssertTrue(hasEuroSymbol, "EUR format '\(formatted)' should contain € or EUR")
        }
    }
    
    /// Test that currency formatting produces expected output for USD
    func testCurrencyFormatting_USD() throws {
        // Given: Various USD values
        let values: [Double] = [50.56, 13629.26, 0.01]
        
        // When: Formatted as USD
        for value in values {
            let formatted = formatCurrency(value, currency: "USD")
            
            // Then: Should contain expected patterns
            XCTAssertFalse(formatted.isEmpty, "Formatted currency should not be empty")
            // USD values should have the $ symbol or USD text
            let hasUSDSymbol = formatted.contains("$") || formatted.contains("USD")
            XCTAssertTrue(hasUSDSymbol, "USD format '\(formatted)' should contain $ or USD")
        }
    }
    
    /// Test dashboard hero card value display format
    func testDashboardHeroCard_ValueFormat() throws {
        // Given: A portfolio total in EUR
        let totalEUR = TestFixtures.ExpectedValues.totalPortfolioValueEUR
        
        // When: Formatted for display
        let formatted = formatCurrency(totalEUR, currency: "EUR")
        
        // Then: Should be properly formatted
        XCTAssertFalse(formatted.isEmpty)
        
        // The total (~€35,445) should format to a reasonable string
        XCTAssertTrue(formatted.count > 5, "Formatted value should have reasonable length")
    }
    
    /// Test that USD holding shows correctly converted EUR value
    func testDashboardHolding_USDConvertedToEUR() throws {
        // Given: A USD holding value converted to EUR
        let jpMorganEUR = TestFixtures.ExpectedValues.jpMorganValueEUR
        
        // When: Displayed on dashboard (should show EUR)
        let formatted = formatCurrency(jpMorganEUR, currency: "EUR")
        
        // Then: Should show EUR symbol, not USD
        XCTAssertTrue(formatted.contains("€") || formatted.contains("EUR"),
                      "Converted value should display as EUR, got: \(formatted)")
        XCTAssertFalse(formatted.contains("$") && !formatted.contains("€"),
                       "Should not show $ alone for EUR-converted value")
    }
    
    /// Test that EUR holding shows EUR symbol
    func testDashboardHolding_EURShowsEURSymbol() throws {
        // Given: An EUR holding value
        let cmAmGoldEUR = TestFixtures.ExpectedValues.cmAmGoldValueEUR
        
        // When: Displayed on dashboard
        let formatted = formatCurrency(cmAmGoldEUR, currency: "EUR")
        
        // Then: Should show EUR symbol
        XCTAssertTrue(formatted.contains("€") || formatted.contains("EUR"),
                      "EUR value should display EUR symbol, got: \(formatted)")
    }
    
    // MARK: - Value Consistency Tests
    
    /// Test that all displayed values are in EUR
    func testAllDisplayedValues_AreInEUR() throws {
        // Given: Holdings with mixed currencies
        let holdings = [
            ("JPMorgan USD Fund", TestFixtures.ExpectedValues.jpMorganValueEUR),
            ("CM-AM Gold EUR Fund", TestFixtures.ExpectedValues.cmAmGoldValueEUR),
            ("EUR Stock", TestFixtures.ExpectedValues.eurStockValueEUR)
        ]
        
        // When: All values are formatted for display
        for (name, value) in holdings {
            let formatted = formatCurrency(value, currency: "EUR")
            
            // Then: All should show EUR
            XCTAssertTrue(formatted.contains("€") || formatted.contains("EUR"),
                          "\(name) should display as EUR, got: \(formatted)")
        }
    }
    
    /// Test account totals are in EUR
    func testAccountTotals_InEUR() throws {
        // Given: Account totals
        let account1Total = TestFixtures.ExpectedValues.account1TotalEUR
        let account2Total = TestFixtures.ExpectedValues.account2TotalEUR
        
        // When: Formatted for display
        let formatted1 = formatCurrency(account1Total, currency: "EUR")
        let formatted2 = formatCurrency(account2Total, currency: "EUR")
        
        // Then: Both should be in EUR format
        XCTAssertTrue(formatted1.contains("€") || formatted1.contains("EUR"))
        XCTAssertTrue(formatted2.contains("€") || formatted2.contains("EUR"))
    }
    
    // MARK: - Snapshot Tests (Requires Initial Recording)
    
    /// Snapshot test for hero card with total portfolio value
    func testSnapshot_HeroCardTotalDisplay() throws {
        // Create a simple view showing the formatted total
        let total = TestFixtures.ExpectedValues.totalPortfolioValueEUR
        let formatted = formatCurrency(total, currency: "EUR")
        
        let view = VStack {
            Text("Portfolio Total")
                .font(.caption)
            Text(formatted)
                .font(.title)
                .fontWeight(.bold)
        }
        .padding()
        .frame(width: 300)
        
        // Snapshot the view
        assertSnapshot(of: view, as: .image)
    }
    
    /// Snapshot test for holding row with USD instrument showing EUR
    func testSnapshot_HoldingRow_USDtoEUR() throws {
        let name = "JPMorgan Funds - Asia Growth Fund"
        let valueEUR = TestFixtures.ExpectedValues.jpMorganValueEUR
        let quantity = TestFixtures.ExpectedValues.jpMorganQuantity
        
        let view = HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(quantity, specifier: "%.2f") units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(valueEUR, currency: "EUR"))
                .font(.headline)
        }
        .padding()
        .frame(width: 350)
        
        assertSnapshot(of: view, as: .image)
    }
    
    /// Snapshot test for holding row with EUR instrument
    func testSnapshot_HoldingRow_EUR() throws {
        let name = "CM-AM SICAV - CM-AM Global Gold"
        let valueEUR = TestFixtures.ExpectedValues.cmAmGoldValueEUR
        let quantity = TestFixtures.ExpectedValues.cmAmGoldQuantity
        
        let view = HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(quantity, specifier: "%.2f") units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(valueEUR, currency: "EUR"))
                .font(.headline)
        }
        .padding()
        .frame(width: 350)
        
        assertSnapshot(of: view, as: .image)
    }
    
    /// Snapshot test for account summary showing EUR total
    func testSnapshot_AccountSummary() throws {
        let accountName = "Investment Account"
        let totalEUR = TestFixtures.ExpectedValues.account1TotalEUR
        
        let view = VStack(alignment: .leading, spacing: 8) {
            Text(accountName)
                .font(.headline)
            HStack {
                Text("Total Value:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatCurrency(totalEUR, currency: "EUR"))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .frame(width: 300)
        
        assertSnapshot(of: view, as: .image)
    }
}
