import Foundation

/// Synthetic ISIN for S&P 500 index levels stored in the prices table (benchmark comparison).
public let SP500IndexIsin = "INDEX:SP500"
/// Synthetic ISIN for Gold index levels (benchmark comparison).
public let GoldIndexIsin = "INDEX:GOLD"
/// Synthetic ISIN for MSCI World index levels (benchmark comparison).
public let MSCIWorldIndexIsin = "INDEX:MSCI_WORLD"

// MARK: - Instrument
public struct Instrument: Identifiable, Codable, Hashable {
    public var id: String { isin }
    public let isin: String
    public var ticker: String?
    public var name: String?
    public var currency: String?
    public var quadrantId: Int?
    
    public init(isin: String, ticker: String? = nil, name: String? = nil, currency: String? = nil, quadrantId: Int? = nil) {
        self.isin = isin
        self.ticker = ticker
        self.name = name
        self.currency = currency
        self.quadrantId = quadrantId
    }
    
    public var displayName: String {
        let base = name ?? ticker ?? isin
        // Gecko no longer in AuCOFFRE; price is estimated from Vera Silver 1 once
        if isin == "COIN:GECKO_SILVER_1OZ" {
            return "\(base) (est. Vera Silver 1 oz)"
        }
        return base
    }
}

// MARK: - Price
public struct Price: Identifiable, Codable {
    public var id: Int?
    public let isin: String
    public let date: String
    public let value: Double
    public let currency: String?
    
    public init(id: Int? = nil, isin: String, date: String, value: Double, currency: String? = nil) {
        self.id = id
        self.isin = isin
        self.date = date
        self.value = value
        self.currency = currency
    }
}

// MARK: - Exchange Rate
public struct ExchangeRate: Identifiable, Codable {
    public var id: Int?
    public let date: String
    public let fromCurrency: String
    public let toCurrency: String
    public let rate: Double
    
    public init(id: Int? = nil, date: String, fromCurrency: String, toCurrency: String, rate: Double) {
        self.id = id
        self.date = date
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
        self.rate = rate
    }
}

// MARK: - Quadrant
public struct Quadrant: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Bank Account
public struct BankAccount: Identifiable, Codable, Hashable {
    public let id: Int
    public let bankName: String
    public let accountName: String
    
    public init(id: Int, bankName: String, accountName: String) {
        self.id = id
        self.bankName = bankName
        self.accountName = accountName
    }
    
    public var displayName: String {
        "\(bankName) - \(accountName)"
    }
}

/// Identifiable selection for opening the edit-holding sheet (macOS) or destination (iOS).
public struct HoldingEditItem: Identifiable {
    public let accountId: Int
    public let isin: String
    public var id: String { "\(accountId)-\(isin)" }
    
    public init(accountId: Int, isin: String) {
        self.accountId = accountId
        self.isin = isin
    }
}

// MARK: - Holding
public struct Holding: Identifiable, Codable {
    public var id: Int?
    public let accountId: Int
    public let isin: String
    public var quantity: Double
    public var purchaseDate: String?
    public var purchasePrice: Double?
    public var lastUpdated: String?
    
    public init(id: Int? = nil, accountId: Int, isin: String, quantity: Double, purchaseDate: String? = nil, purchasePrice: Double? = nil, lastUpdated: String? = nil) {
        self.id = id
        self.accountId = accountId
        self.isin = isin
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Holding with Details (for display)
public struct HoldingDetail: Identifiable {
    public var id: String { "\(accountId)-\(isin)" }
    public let accountId: Int
    public let isin: String
    public let instrumentName: String
    public let instrumentCurrency: String?
    public let ticker: String?
    public let quantity: Double
    public let currentPrice: Double?
    public let previousPrice: Double?
    public let priceDate: String?
    
    // EUR-converted values (pre-calculated)
    public let currentValueEUR: Double?
    public let previousValueEUR: Double?
    
    public init(accountId: Int, isin: String, instrumentName: String, instrumentCurrency: String? = nil, ticker: String? = nil, quantity: Double, currentPrice: Double? = nil, previousPrice: Double? = nil, priceDate: String? = nil, currentValueEUR: Double? = nil, previousValueEUR: Double? = nil) {
        self.accountId = accountId
        self.isin = isin
        self.instrumentName = instrumentName
        self.instrumentCurrency = instrumentCurrency
        self.ticker = ticker
        self.quantity = quantity
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
        self.priceDate = priceDate
        self.currentValueEUR = currentValueEUR
        self.previousValueEUR = previousValueEUR
    }
    
    public var currentValue: Double? {
        guard let price = currentPrice else { return nil }
        return quantity * price
    }
    
    public var changePercentEUR: Double? {
        guard let current = currentValueEUR, let previous = previousValueEUR, previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
}

// MARK: - Market Data Result
public struct MarketDataResult {
    public let isin: String
    public var ticker: String?
    public var name: String?
    public var value: Double?
    public var currency: String?
    public var date: String
    /// When value is nil, optional reason for debugging (e.g. "Yahoo: HTTP 403", "The request timed out.").
    public var failureReason: String? = nil
    
    public init(isin: String, ticker: String? = nil, name: String? = nil, value: Double? = nil, currency: String? = nil, date: String, failureReason: String? = nil) {
        self.isin = isin
        self.ticker = ticker
        self.name = name
        self.value = value
        self.currency = currency
        self.date = date
        self.failureReason = failureReason
    }
}

// MARK: - Report Period
public enum ReportPeriod: String, CaseIterable, Identifiable {
    case oneDay = "1Day"
    case oneWeek = "1Week"
    case oneMonth = "1Month"
    case oneYear = "1Year"
    case yearToDate = "1Jan"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .oneDay: return L10n.period1Day
        case .oneWeek: return L10n.period1Week
        case .oneMonth: return L10n.period1Month
        case .oneYear: return L10n.period1Year
        case .yearToDate: return L10n.periodYearToDate
        }
    }
    
    public var comparisonDate: Date {
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
public struct QuadrantReportItem: Identifiable {
    public let id = UUID()
    public let quadrant: Quadrant?
    public let holdings: [HoldingDetail]
    
    public init(quadrant: Quadrant?, holdings: [HoldingDetail]) {
        self.quadrant = quadrant
        self.holdings = holdings
    }
    
    // Legacy: totals grouped by currency (kept for backwards compatibility)
    public var totalValue: [String: Double] {
        var totals: [String: Double] = [:]
        for holding in holdings {
            if let value = holding.currentValue, let currency = holding.instrumentCurrency {
                totals[currency, default: 0] += value
            }
        }
        return totals
    }
    
    public var totalPreviousValue: [String: Double] {
        var totals: [String: Double] = [:]
        for holding in holdings {
            if let price = holding.previousPrice, let currency = holding.instrumentCurrency {
                totals[currency, default: 0] += holding.quantity * price
            }
        }
        return totals
    }
    
    // EUR totals (all values converted to EUR)
    public var totalValueEUR: Double {
        holdings.compactMap { $0.currentValueEUR }.reduce(0, +)
    }
    
    public var totalPreviousValueEUR: Double {
        holdings.compactMap { $0.previousValueEUR }.reduce(0, +)
    }
    
    public var changePercentEUR: Double? {
        guard totalPreviousValueEUR > 0 else { return nil }
        return ((totalValueEUR - totalPreviousValueEUR) / totalPreviousValueEUR) * 100
    }
}
