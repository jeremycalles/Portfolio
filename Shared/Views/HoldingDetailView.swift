import SwiftUI

struct HoldingDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let accountId: Int
    let isin: String
    var privacyMode = false

    @State private var transactions: [HoldingTransaction] = []
    @State private var history: [(date: Date, value: Double)] = []
    @State private var latestPrice: Price?
    @State private var showingNewTransaction = false
    @State private var editingTransaction: HoldingTransaction?
    @State private var showingCloseConfirmation = false
    @State private var showingDeleteHistoryConfirmation = false

    private var instrument: Instrument? {
        viewModel.instruments.first { $0.isin == isin }
    }

    private var account: BankAccount? {
        viewModel.bankAccounts.first { $0.id == accountId }
    }

    private var ledger: HoldingLedgerSummary {
        HoldingLedger.summary(transactions: transactions)
    }

    private var chartEvents: [PortfolioChartEvent] {
        transactions.map {
            PortfolioChartEvent(
                transaction: $0,
                amountEUR: $0.quantityDelta * ($0.unitPrice ?? 0)
            )
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(account?.displayName ?? "")
                    Spacer()
                    Text(isin)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                PortfolioTrendChart(
                    history: history,
                    transactionEvents: chartEvents,
                    compact: false,
                    interactive: true,
                    privacyMode: privacyMode
                )
                .frame(minHeight: 250)
                .listRowInsets(EdgeInsets())
            }

            Section {
                metricRow(L10n.holdingsQuantity, value: formatQuantity(ledger.quantity))
                metricRow(
                    L10n.holdingsAverageCost,
                    value: ledger.averageCost.map { formatCurrency($0, currency: instrument?.currency ?? "EUR") }
                )
                metricRow(
                    L10n.holdingsUnrealizedPnL,
                    value: ledger.unrealizedProfitLoss(currentUnitPrice: latestPrice?.value)
                        .map { formatCurrency($0, currency: instrument?.currency ?? "EUR") }
                )
                metricRow(
                    L10n.holdingsRealizedPnL,
                    value: formatCurrency(ledger.realizedProfitLoss, currency: instrument?.currency ?? "EUR")
                )
            }

            Section(L10n.holdingsTransactions) {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        L10n.holdingsNoTransactions,
                        systemImage: "arrow.left.arrow.right"
                    )
                } else {
                    ForEach(transactions.sorted(by: transactionSort)) { transaction in
                        Button {
                            editingTransaction = transaction
                        } label: {
                            transactionRow(transaction)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteTransaction(transaction)
                                    await load()
                                }
                            } label: {
                                Label(L10n.generalDelete, systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button(L10n.holdingsClosePosition, role: .destructive) {
                    showingCloseConfirmation = true
                }
                Button(L10n.holdingsDeleteWithHistory, role: .destructive) {
                    showingDeleteHistoryConfirmation = true
                }
            }
        }
        .navigationTitle(instrument?.displayName ?? isin)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTransaction = true
                } label: {
                    Label(L10n.holdingsAddTransaction, systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTransaction, onDismiss: reload) {
            TransactionEditorView(accountId: accountId, isin: isin)
                .environmentObject(viewModel)
        }
        .sheet(item: $editingTransaction, onDismiss: reload) { transaction in
            TransactionEditorView(accountId: accountId, isin: isin, transaction: transaction)
                .environmentObject(viewModel)
        }
        .confirmationDialog(
            L10n.holdingsDeleteHistoryConfirmation,
            isPresented: $showingDeleteHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.holdingsDeleteWithHistory, role: .destructive) {
                Task {
                    await viewModel.deleteHoldingWithHistory(accountId: accountId, isin: isin)
                    dismiss()
                }
            }
        }
        .confirmationDialog(
            L10n.holdingsCloseConfirmation,
            isPresented: $showingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.holdingsClosePosition, role: .destructive) {
                Task {
                    await viewModel.deleteHolding(accountId: accountId, isin: isin)
                    dismiss()
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func metricRow(_ title: String, value: String?) -> some View {
        LabeledContent(title) {
            Text(privacyMode ? L10n.privacyHiddenLong : (value ?? L10n.generalNA))
                .monospacedDigit()
        }
    }

    private func transactionRow(_ transaction: HoldingTransaction) -> some View {
        HStack {
            Image(systemName: transaction.quantityDelta >= 0 ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                .foregroundStyle(transaction.quantityDelta >= 0 ? AppTheme.gain : AppTheme.loss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.kind.localizedName)
                    .font(.headline)
                Text(transaction.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(transaction.quantityDelta >= 0 ? "+" : "−")\(formatQuantity(abs(transaction.quantityDelta)))")
                    .monospacedDigit()
                if let price = transaction.unitPrice {
                    Text(formatCurrency(price, currency: instrument?.currency ?? "EUR"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func transactionSort(_ lhs: HoldingTransaction, _ rhs: HoldingTransaction) -> Bool {
        if lhs.date == rhs.date { return (lhs.id ?? 0) > (rhs.id ?? 0) }
        return lhs.date > rhs.date
    }

    private func reload() {
        Task { await load() }
    }

    private func load() async {
        async let loadedTransactions = viewModel.db.getHoldingTransactions(accountId: accountId, isin: isin)
        async let loadedHistory = viewModel.getPositionValueHistory(accountId: accountId, isin: isin)
        async let loadedPrice = viewModel.db.getLatestPrice(forIsin: isin)
        transactions = await loadedTransactions
        history = await loadedHistory
        latestPrice = await loadedPrice
    }
}

private struct TransactionEditorView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let accountId: Int
    let isin: String
    var transaction: HoldingTransaction?

    @State private var kind: HoldingTransactionKind = .buy
    @State private var quantityText = ""
    @State private var priceText = ""
    @State private var feesText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var adjustmentDirection = 1.0

    private var isValid: Bool {
        (parseDecimal(quantityText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker(L10n.holdingsTransactions, selection: $kind) {
                    ForEach(editableKinds, id: \.self) { kind in
                        Text(kind.localizedName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if kind == .adjustment {
                    Picker(L10n.holdingsAdjustmentDirection, selection: $adjustmentDirection) {
                        Text(L10n.holdingsIncrease).tag(1.0)
                        Text(L10n.holdingsDecrease).tag(-1.0)
                    }
                    .pickerStyle(.segmented)
                }

                DatePicker(L10n.reportsDate, selection: $date, in: ...Date(), displayedComponents: .date)
                TextField(L10n.holdingsQuantity, text: $quantityText)
                TextField(L10n.holdingsUnitPrice, text: $priceText)
                TextField(L10n.holdingsFees, text: $feesText)
                TextField(L10n.holdingsNote, text: $note)
            }
            .navigationTitle(transaction == nil ? L10n.holdingsAddTransaction : L10n.generalEdit)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.generalCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalSave) {
                        Task { await save() }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear(perform: populate)
        }
        #if os(macOS)
        .frame(minWidth: 430, minHeight: 390)
        #endif
    }

    private var editableKinds: [HoldingTransactionKind] {
        transaction?.kind == .opening ? [.opening, .buy, .sell, .adjustment] : [.buy, .sell, .adjustment]
    }

    private func populate() {
        guard let transaction else { return }
        kind = transaction.kind
        adjustmentDirection = transaction.quantityDelta < 0 ? -1 : 1
        quantityText = String(format: "%.4f", abs(transaction.quantityDelta))
        if let price = transaction.unitPrice { priceText = String(format: "%.4f", price) }
        if let fees = transaction.fees { feesText = String(format: "%.2f", fees) }
        note = transaction.note == HoldingLedger.estimatedOpeningNote ? "" : (transaction.note ?? "")
        date = AppDateFormatter.yearMonthDay.date(from: transaction.date) ?? Date()
    }

    private func save() async {
        guard let quantity = parseDecimal(quantityText), quantity > 0 else { return }
        let dateString = AppDateFormatter.yearMonthDay.string(from: date)
        let price = parseDecimal(priceText)
        let fees = parseDecimal(feesText)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let transaction {
            let updated = HoldingTransaction(
                id: transaction.id,
                accountId: accountId,
                isin: isin,
                date: dateString,
                quantityDelta: kind == .adjustment
                    ? quantity * adjustmentDirection
                    : HoldingLedger.signedQuantity(kind: kind, quantity: quantity),
                unitPrice: price,
                createdAt: transaction.createdAt,
                kind: kind,
                fees: fees,
                note: cleanNote.isEmpty ? nil : cleanNote
            )
            await viewModel.updateTransaction(updated)
        } else if kind == .sell {
            await viewModel.recordSell(
                accountId: accountId,
                isin: isin,
                quantity: quantity,
                date: dateString,
                unitPrice: price,
                fees: fees,
                note: cleanNote.isEmpty ? nil : cleanNote
            )
        } else if kind == .adjustment {
            await viewModel.recordAdjustment(
                accountId: accountId,
                isin: isin,
                quantityDelta: quantity * adjustmentDirection,
                date: dateString,
                unitPrice: price,
                note: cleanNote.isEmpty ? nil : cleanNote
            )
        } else {
            await viewModel.recordBuy(
                accountId: accountId,
                isin: isin,
                quantity: quantity,
                date: dateString,
                unitPrice: price,
                fees: fees,
                note: cleanNote.isEmpty ? nil : cleanNote
            )
        }
        if viewModel.errorMessage == nil { dismiss() }
    }
}

private extension HoldingTransactionKind {
    var localizedName: String {
        switch self {
        case .buy: return L10n.holdingsBuy
        case .sell: return L10n.holdingsSell
        case .opening: return L10n.holdingsOpening
        case .adjustment: return L10n.holdingsAdjustment
        }
    }
}
