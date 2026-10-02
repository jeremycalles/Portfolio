import Foundation

struct HoldingLedgerSummary: Equatable {
    let quantity: Double
    let averageCost: Double?
    let totalCost: Double
    let realizedProfitLoss: Double

    func unrealizedProfitLoss(currentUnitPrice: Double?) -> Double? {
        guard let currentUnitPrice, quantity > 0 else { return nil }
        return quantity * currentUnitPrice - totalCost
    }
}

enum HoldingLedgerValidationError: Error, Equatable {
    case invalidQuantity
    case futureDate
    case insufficientQuantity(available: Double)
}

enum HoldingLedger {
    static let estimatedOpeningNote = "estimated-opening"
    static let epsilon = 1e-9

    static func quantity(
        on date: String? = nil,
        transactions: [HoldingTransaction],
        excludingID: Int? = nil
    ) -> Double {
        transactions.reduce(0) { total, transaction in
            if let excludingID, transaction.id == excludingID { return total }
            guard date == nil || transaction.date <= date! else { return total }
            return total + transaction.quantityDelta
        }
    }

    static func validate(
        kind: HoldingTransactionKind,
        quantity: Double,
        date: String,
        today: String,
        existing: [HoldingTransaction],
        excludingID: Int? = nil
    ) throws {
        guard quantity.isFinite, quantity > epsilon else {
            throw HoldingLedgerValidationError.invalidQuantity
        }
        guard date <= today else {
            throw HoldingLedgerValidationError.futureDate
        }
        if kind == .sell {
            let available = self.quantity(on: date, transactions: existing, excludingID: excludingID)
            guard quantity <= available + epsilon else {
                throw HoldingLedgerValidationError.insufficientQuantity(available: max(0, available))
            }
        }
    }

    /// A ledger is valid only when every dated operation leaves a non-negative
    /// quantity. This catches edits/deletions that would invalidate later sales.
    static func validateSequence(_ transactions: [HoldingTransaction]) throws {
        let ordered = transactions.sorted {
            if $0.date == $1.date { return ($0.id ?? 0) < ($1.id ?? 0) }
            return $0.date < $1.date
        }
        var runningQuantity = 0.0
        for transaction in ordered {
            runningQuantity += transaction.quantityDelta
            if runningQuantity < -epsilon {
                throw HoldingLedgerValidationError.insufficientQuantity(
                    available: max(0, runningQuantity - transaction.quantityDelta)
                )
            }
        }
    }

    static func signedQuantity(kind: HoldingTransactionKind, quantity: Double) -> Double {
        kind == .sell ? -abs(quantity) : abs(quantity)
    }

    /// Average-cost accounting. Fees increase acquisition cost and reduce sale proceeds.
    static func summary(transactions: [HoldingTransaction]) -> HoldingLedgerSummary {
        let ordered = transactions.sorted {
            if $0.date == $1.date { return ($0.id ?? 0) < ($1.id ?? 0) }
            return $0.date < $1.date
        }
        var quantity = 0.0
        var totalCost = 0.0
        var realized = 0.0

        for transaction in ordered {
            let delta = transaction.quantityDelta
            let fees = max(0, transaction.fees ?? 0)
            if delta > epsilon {
                let currentAverage = quantity > epsilon ? totalCost / quantity : 0
                let unitCost = transaction.unitPrice ?? currentAverage
                quantity += delta
                totalCost += delta * unitCost + fees
            } else if delta < -epsilon {
                let sold = min(-delta, max(0, quantity))
                guard sold > epsilon else { continue }
                let average = quantity > epsilon ? totalCost / quantity : 0
                let removedCost = sold * average
                if transaction.kind == .sell, let price = transaction.unitPrice {
                    realized += sold * price - removedCost - fees
                }
                quantity -= sold
                totalCost -= removedCost
                if quantity <= epsilon {
                    quantity = 0
                    totalCost = 0
                }
            }
        }

        return HoldingLedgerSummary(
            quantity: quantity,
            averageCost: quantity > epsilon ? totalCost / quantity : nil,
            totalCost: totalCost,
            realizedProfitLoss: realized
        )
    }

    static func backfillParameters(oldestDate: String, today: Date = Date()) -> (period: String, interval: String) {
        guard let date = AppDateFormatter.yearMonthDay.date(from: oldestDate) else {
            return ("1y", "1d")
        }
        let days = Calendar.current.dateComponents([.day], from: date, to: today).day ?? 365
        switch days {
        case ...45: return ("3mo", "1d")
        case ...400: return ("1y", "1d")
        case ...800: return ("2y", "1d")
        case ...1_900: return ("5y", "1wk")
        default: return ("max", "1wk")
        }
    }
}
