import Foundation
@testable import Portfolio

/// Test fixtures providing predictable data for unit and snapshot tests
struct TestFixtures {
    
    // MARK: - Exchange Rate (Fixed for Predictable Calculations)
    
    /// Fixed USD to EUR rate: 1 USD = 0.85 EUR
    static let usdToEurRate: Double = 0.85
    
    // MARK: - Instruments
    
    /// JPMorgan USD Fund - Tests USD to EUR conversion
    static let jpMorganFund = Instrument(
        isin: "LU0169518387",
        ticker: "N/A",
        name: "JPMorgan Funds - Asia Growth Fund A (acc) - USD",
        type: "Fund",
        currency: "USD",
        quadrantId: 1
    )
    
    /// CM-AM Gold Fund - Tests EUR (no conversion needed)
    static let cmAmGoldFund = Instrument(
        isin: "FR0007390174",
        ticker: "N/A",
        name: "CM-AM SICAV - CM-AM Global Gold RC",
        type: "Fund",
        currency: "EUR",
        quadrantId: 2
    )
    
    /// Sample stock in EUR
    static let sampleEurStock = Instrument(
        isin: "FR0000120271",
        ticker: "TOT.PA",
        name: "TotalEnergies SE",
        type: "Stock",
        currency: "EUR",
        quadrantId: nil
    )
    
    static let instruments: [Instrument] = [
        jpMorganFund,
        cmAmGoldFund,
        sampleEurStock
    ]
    
    // MARK: - Prices
    
    /// JPMorgan Fund Prices (in USD)
    static let jpMorganPrices: [Price] = [
        Price(id: 1, isin: "LU0169518387", date: "2026-01-29", value: 50.56, currency: "USD"),
        Price(id: 2, isin: "LU0169518387", date: "2026-01-28", value: 49.68, currency: "USD"),
        Price(id: 3, isin: "LU0169518387", date: "2026-01-27", value: 48.68, currency: "USD"),
        Price(id: 4, isin: "LU0169518387", date: "2026-01-22", value: 48.06, currency: "USD"),
    ]
    
    /// CM-AM Gold Fund Prices (in EUR)
    static let cmAmGoldPrices: [Price] = [
        Price(id: 10, isin: "FR0007390174", date: "2026-01-29", value: 112.20, currency: "EUR"),
        Price(id: 11, isin: "FR0007390174", date: "2026-01-28", value: 111.50, currency: "EUR"),
        Price(id: 12, isin: "FR0007390174", date: "2026-01-27", value: 110.80, currency: "EUR"),
        Price(id: 13, isin: "FR0007390174", date: "2026-01-22", value: 112.00, currency: "EUR"),
    ]
    
    /// EUR Stock Prices
    static let eurStockPrices: [Price] = [
        Price(id: 20, isin: "FR0000120271", date: "2026-01-29", value: 58.42, currency: "EUR"),
        Price(id: 21, isin: "FR0000120271", date: "2026-01-28", value: 57.89, currency: "EUR"),
    ]
    
    static let pricesByISIN: [String: [Price]] = [
        "LU0169518387": jpMorganPrices,
        "FR0007390174": cmAmGoldPrices,
        "FR0000120271": eurStockPrices
    ]
    
    // MARK: - Exchange Rates
    
    static let exchangeRates: [ExchangeRate] = [
        ExchangeRate(id: 1, date: "2026-01-29", fromCurrency: "USD", toCurrency: "EUR", rate: 0.85),
        ExchangeRate(id: 2, date: "2026-01-28", fromCurrency: "USD", toCurrency: "EUR", rate: 0.84),
        ExchangeRate(id: 3, date: "2026-01-27", fromCurrency: "USD", toCurrency: "EUR", rate: 0.835),
        ExchangeRate(id: 4, date: "2026-01-22", fromCurrency: "USD", toCurrency: "EUR", rate: 0.852),
    ]
    
    // MARK: - Bank Accounts
    
    static let bankAccounts: [BankAccount] = [
        BankAccount(id: 1, bankName: "Test Bank", accountName: "Investment Account"),
        BankAccount(id: 2, bankName: "Other Bank", accountName: "Savings Account"),
    ]
    
    // MARK: - Holdings
    
    /// Holdings with known quantities for predictable value calculations
    static let holdings: [Holding] = [
        // 269.57 units of JPMorgan USD Fund
        // At $50.56 USD, total USD value = 269.57 * 50.56 = $13,629.26 USD
        // At 0.85 EUR/USD, EUR value = 13,629.26 * 0.85 = €11,584.87 EUR
        Holding(id: 1, accountId: 1, isin: "LU0169518387", quantity: 269.57,
                purchaseDate: "2024-01-15", purchasePrice: 42.00, lastUpdated: "2026-01-29"),
        
        // 160.59 units of CM-AM Gold Fund (EUR)
        // At €112.20 EUR, total = 160.59 * 112.20 = €18,018.20 EUR (no conversion needed)
        Holding(id: 2, accountId: 1, isin: "FR0007390174", quantity: 160.59,
                purchaseDate: "2024-02-20", purchasePrice: 95.00, lastUpdated: "2026-01-29"),
        
        // 100 units of EUR Stock
        // At €58.42 EUR, total = 100 * 58.42 = €5,842.00 EUR
        Holding(id: 3, accountId: 2, isin: "FR0000120271", quantity: 100.0,
                purchaseDate: "2024-06-01", purchasePrice: 50.00, lastUpdated: "2026-01-29"),
    ]
    
    // MARK: - Quadrants
    
    static let quadrants: [Quadrant] = [
        Quadrant(id: 1, name: "Growth"),
        Quadrant(id: 2, name: "Commodities"),
        Quadrant(id: 3, name: "Defensive"),
    ]
    
    // MARK: - Expected Calculated Values (for Test Assertions)
    
    struct ExpectedValues {
        // JPMorgan Fund (USD)
        static let jpMorganLatestPriceUSD: Double = 50.56
        static let jpMorganQuantity: Double = 269.57
        static let jpMorganValueUSD: Double = jpMorganQuantity * jpMorganLatestPriceUSD // ~13,629.26
        static let jpMorganValueEUR: Double = jpMorganValueUSD * usdToEurRate // ~11,584.87
        
        // CM-AM Gold Fund (EUR - no conversion)
        static let cmAmGoldLatestPriceEUR: Double = 112.20
        static let cmAmGoldQuantity: Double = 160.59
        static let cmAmGoldValueEUR: Double = cmAmGoldQuantity * cmAmGoldLatestPriceEUR // ~18,018.20
        
        // EUR Stock
        static let eurStockLatestPriceEUR: Double = 58.42
        static let eurStockQuantity: Double = 100.0
        static let eurStockValueEUR: Double = eurStockQuantity * eurStockLatestPriceEUR // ~5,842.00
        
        // Total Portfolio Value in EUR
        static var totalPortfolioValueEUR: Double {
            return jpMorganValueEUR + cmAmGoldValueEUR + eurStockValueEUR
            // ~11,584.87 + ~18,018.20 + ~5,842.00 = ~35,445.07
        }
        
        // Account 1 Total (JPMorgan + CM-AM Gold)
        static var account1TotalEUR: Double {
            return jpMorganValueEUR + cmAmGoldValueEUR
            // ~11,584.87 + ~18,018.20 = ~29,603.07
        }
        
        // Account 2 Total (EUR Stock only)
        static var account2TotalEUR: Double {
            return eurStockValueEUR // ~5,842.00
        }
    }
}
