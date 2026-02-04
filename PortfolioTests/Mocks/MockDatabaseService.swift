import Foundation
@testable import Portfolio

/// A mock database service for testing that provides predictable, in-memory test data
/// without requiring an actual SQLite database connection.
class MockDatabaseService {
    
    // MARK: - Test Data Storage
    
    var instruments: [Instrument] = []
    var prices: [String: [Price]] = [:] // keyed by ISIN
    var exchangeRates: [ExchangeRate] = []
    var holdings: [Holding] = []
    var bankAccounts: [BankAccount] = []
    var quadrants: [Quadrant] = []
    
    // MARK: - Singleton for Testing
    
    static let shared = MockDatabaseService()
    
    private init() {}
    
    // MARK: - Setup Methods
    
    /// Reset all test data
    func reset() {
        instruments = []
        prices = [:]
        exchangeRates = []
        holdings = []
        bankAccounts = []
        quadrants = []
    }
    
    /// Load test fixtures
    func loadTestFixtures() {
        reset()
        
        // Load from TestFixtures
        instruments = TestFixtures.instruments
        prices = TestFixtures.pricesByISIN
        exchangeRates = TestFixtures.exchangeRates
        holdings = TestFixtures.holdings
        bankAccounts = TestFixtures.bankAccounts
        quadrants = TestFixtures.quadrants
    }
    
    // MARK: - Database Query Methods (Matching DatabaseService interface)
    
    func getInstruments() -> [Instrument] {
        return instruments
    }
    
    func getInstrument(byIsin isin: String) -> Instrument? {
        return instruments.first { $0.isin == isin }
    }
    
    func getLatestPrice(forIsin isin: String) -> Price? {
        return prices[isin]?.sorted { $0.date > $1.date }.first
    }
    
    func getPriceHistory(forIsin isin: String) -> [Price] {
        return prices[isin]?.sorted { $0.date > $1.date } ?? []
    }
    
    func getPrice(forIsin isin: String, date: String) -> Price? {
        return prices[isin]?.first { $0.date == date }
    }
    
    func getPriceOnOrBefore(forIsin isin: String, date: String) -> Price? {
        return prices[isin]?
            .filter { $0.date <= date }
            .sorted { $0.date > $1.date }
            .first
    }
    
    func getPriceBefore(forIsin isin: String, date: String) -> Price? {
        return prices[isin]?
            .filter { $0.date < date }
            .sorted { $0.date > $1.date }
            .first
    }
    
    func getLatestRate(from: String, to: String) -> ExchangeRate? {
        return exchangeRates
            .filter { $0.fromCurrency == from && $0.toCurrency == to }
            .sorted { $0.date > $1.date }
            .first
    }
    
    func getRateOnOrBefore(from: String, to: String, date: String) -> ExchangeRate? {
        return exchangeRates
            .filter { $0.fromCurrency == from && $0.toCurrency == to && $0.date <= date }
            .sorted { $0.date > $1.date }
            .first
    }
    
    func getHoldings() -> [Holding] {
        return holdings
    }
    
    func getHoldings(forAccount accountId: Int) -> [Holding] {
        return holdings.filter { $0.accountId == accountId }
    }
    
    func getBankAccounts() -> [BankAccount] {
        return bankAccounts
    }
    
    func getQuadrants() -> [Quadrant] {
        return quadrants
    }
}
