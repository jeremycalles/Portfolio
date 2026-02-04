import Foundation

/// Synthetic ISIN for S&P 500 index levels stored in the prices table (benchmark comparison).
let SP500IndexIsin = "INDEX:SP500"
/// Synthetic ISIN for Gold index levels (benchmark comparison).
let GoldIndexIsin = "INDEX:GOLD"
/// Synthetic ISIN for MSCI World index levels (benchmark comparison).
let MSCIWorldIndexIsin = "INDEX:MSCI_WORLD"

// MARK: - Instrument
struct Instrument: Identifiable, Codable, Hashable {
    var id: String { isin }
    let isin: String
    var ticker: String?
    var name: String?
    var type: String?
    var currency: String?
    var quadrantId: Int?
    
    var displayName: String {
        name ?? ticker ?? isin
    }
}

// MARK: - Price
struct Price: Identifiable, Codable {
    var id: Int?
    let isin: String
    let date: String
    let value: Double
    let currency: String?
}

// MARK: - Exchange Rate
struct ExchangeRate: Identifiable, Codable {
    var id: Int?
    let date: String
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
}

// MARK: - Quadrant
struct Quadrant: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
}

// MARK: - Bank Account
struct BankAccount: Identifiable, Codable, Hashable {
    let id: Int
    let bankName: String
    let accountName: String
    
    var displayName: String {
        "\(bankName) - \(accountName)"
    }
}

// MARK: - Holding
struct Holding: Identifiable, Codable {
    var id: Int?
    let accountId: Int
    let isin: String
    var quantity: Double
    var purchaseDate: String?
    var purchasePrice: Double?
    var lastUpdated: String?
}

// MARK: - Holding with Details (for display)
struct HoldingDetail: Identifiable {
    var id: String { "\(accountId)-\(isin)" }
    let accountId: Int
    let isin: String
    let instrumentName: String
    let instrumentCurrency: String?
    let ticker: String?
    let quantity: Double
    let currentPrice: Double?
    let previousPrice: Double?
    let priceDate: String?
    
    // EUR-converted values (pre-calculated)
    let currentValueEUR: Double?
    let previousValueEUR: Double?
    
    var currentValue: Double? {
        guard let price = currentPrice else { return nil }
        return quantity * price
    }
    
    var changePercent: Double? {
        guard let current = currentPrice, let previous = previousPrice, previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
    
    var changePercentEUR: Double? {
        guard let current = currentValueEUR, let previous = previousValueEUR, previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
}

// MARK: - Market Data Result
struct MarketDataResult {
    let isin: String
    var ticker: String?
    var name: String?
    var value: Double?
    var currency: String?
    var date: String
}

// MARK: - Report Period
enum ReportPeriod: String, CaseIterable, Identifiable {
    case oneDay = "1Day"
    case oneWeek = "1Week"
    case oneMonth = "1Month"
    case oneYear = "1Year"
    case yearToDate = "1Jan"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .oneDay: return L10n.period1Day
        case .oneWeek: return L10n.period1Week
        case .oneMonth: return L10n.period1Month
        case .oneYear: return L10n.period1Year
        case .yearToDate: return L10n.periodYearToDate
        }
    }
    
    var comparisonDate: Date {
        let today = Date()
        let calendar = Calendar.current
        
        switch self {
        case .oneDay:
            return calendar.date(byAdding: .day, value: -1, to: today) ?? today
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: today) ?? today
        case .oneMonth:
            return calendar.date(byAdding: .day, value: -30, to: today) ?? today
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: today) ?? today
        case .yearToDate:
            return calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1)) ?? today
        }
    }
}

// MARK: - Quadrant Report Item
struct QuadrantReportItem: Identifiable {
    let id = UUID()
    let quadrant: Quadrant?
    let holdings: [HoldingDetail]
    
    // Legacy: totals grouped by currency (kept for backwards compatibility)
    var totalValue: [String: Double] {
        var totals: [String: Double] = [:]
        for holding in holdings {
            if let value = holding.currentValue, let currency = holding.instrumentCurrency {
                totals[currency, default: 0] += value
            }
        }
        return totals
    }
    
    var totalPreviousValue: [String: Double] {
        var totals: [String: Double] = [:]
        for holding in holdings {
            if let price = holding.previousPrice, let currency = holding.instrumentCurrency {
                totals[currency, default: 0] += holding.quantity * price
            }
        }
        return totals
    }
    
    func changePercent(for currency: String) -> Double? {
        guard let current = totalValue[currency], let previous = totalPreviousValue[currency], previous > 0 else {
            return nil
        }
        return ((current - previous) / previous) * 100
    }
    
    // EUR totals (all values converted to EUR)
    var totalValueEUR: Double {
        holdings.compactMap { $0.currentValueEUR }.reduce(0, +)
    }
    
    var totalPreviousValueEUR: Double {
        holdings.compactMap { $0.previousValueEUR }.reduce(0, +)
    }
    
    var changePercentEUR: Double? {
        guard totalPreviousValueEUR > 0 else { return nil }
        return ((totalValueEUR - totalPreviousValueEUR) / totalPreviousValueEUR) * 100
    }
}
