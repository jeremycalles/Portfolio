import SwiftUI

struct HoldingDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    let accountId: Int
    let isin: String
    var privacyMode = false
    @AppStorage("privacyMode") private var storedPrivacy = false
    private var hideValues: Bool { storedPrivacy || viewModel.demoMode.isDemoModeEnabled }
    @State private var cashflows: [PortfolioCashflow] = []
    @State private var hasCompleteCashflows = true
    @State private var events: [PortfolioChartEvent] = []
    @State private var deletingTransaction: HoldingTransaction?

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

    private var hasKnownCosts: Bool { transactions.filter { $0.quantityDelta > 0 }.allSatisfy { $0.unitPrice != nil } }
    private var hasKnownProceeds: Bool { transactions.filter { $0.kind == .sell }.allSatisfy { $0.unitPrice != nil } }

    private var ledger: HoldingLedgerSummary {
        HoldingLedger.summary(transactions: transactions)
    }

    private var currentValue: Double? {
        viewModel.cachedHoldingDetailsByAccount[accountId]?.first { $0.isin == isin }?.currentValueEUR
    }

    var body: some View {
        List {
            Section {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                layout {
                    Text(account?.displayName ?? "")
                    if !typeSize.isAccessibilitySize { Spacer() }
                    Text(isin)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                metricRow(L10n.designCurrentValue, value: currentValue.map { formatCurrency($0, currency: "EUR") })
                metricRow(L10n.designInvestmentReturn, value: viewModel.cachedPositionTWR["\(accountId)-\(isin)"].map { formatPercentChange($0) })
                PeriodChips(selectedPeriod: $viewModel.selectedPeriod)
            }
            Section {
                PortfolioTrendChart(
                    history: history,
                    transactionEvents: events,
                    compact: false,
                    interactive: true,
                    privacyMode: hideValues,
                    cashflows: cashflows,
                    startsWithReturn: true,
                    hasCompleteCashflows: hasCompleteCashflows
                )
                .frame(minHeight: 250)
                .listRowInsets(EdgeInsets())
            }

            Section {
                metricRow(L10n.holdingsQuantity, value: formatQuantity(ledger.quantity))
                metricRow(
                    L10n.holdingsAverageCost,
                    value: hasKnownCosts ? ledger.averageCost.map { formatCurrency($0, currency: instrument?.currency ?? "EUR") } : nil
                )
                metricRow(
                    L10n.holdingsUnrealizedPnL,
                    value: hasKnownCosts ? ledger.unrealizedProfitLoss(currentUnitPrice: latestPrice?.value)
                        .map { formatCurrency($0, currency: instrument?.currency ?? "EUR") } : nil
                )
                metricRow(
                    L10n.holdingsRealizedPnL,
                    value: hasKnownCosts && hasKnownProceeds ? formatCurrency(ledger.realizedProfitLoss, currency: instrument?.currency ?? "EUR") : nil
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
                        .disabled(hideValues)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingTransaction = transaction
                            } label: {
                                Label(L10n.generalDelete, systemImage: "trash")
                            }.disabled(hideValues)
                        }
                    }
                }
            }

            Section {
                Button(L10n.holdingsClosePosition, role: .destructive) {
                    showingCloseConfirmation = true
                }.disabled(hideValues || ledger.quantity <= 0)
                Button(L10n.holdingsDeleteWithHistory, role: .destructive) {
                    showingDeleteHistoryConfirmation = true
                }.disabled(hideValues)
            }
        }
        .navigationTitle(instrument?.displayName ?? isin)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTransaction = true
                } label: {
                    Label(L10n.holdingsAddTransaction, systemImage: "plus")
                }.disabled(viewModel.demoMode.isDemoModeEnabled)
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
                    viewModel.dismissError()
                    await viewModel.deleteHoldingWithHistory(accountId: accountId, isin: isin)
                    if viewModel.errorMessage == nil { dismiss() }
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
                    viewModel.dismissError()
                    await viewModel.deleteHolding(accountId: accountId, isin: isin)
                    if viewModel.errorMessage == nil { dismiss() }
                }
            }
        }
        .confirmationDialog(L10n.designDeleteTransactionWarning,
            isPresented: Binding(get: { deletingTransaction != nil }, set: { if !$0 { deletingTransaction = nil } }),
            titleVisibility: .visible) {
            if let transaction = deletingTransaction {
                Button(L10n.generalDelete, role: .destructive) {
                    Task {
                        await viewModel.deleteTransaction(transaction)
                        deletingTransaction = nil
                        await load()
                    }
                }
            }
        }
        .task(id: viewModel.selectedPeriod) { await load() }
    }

    @ViewBuilder
    private func metricRow(_ title: String, value: String?) -> some View {
        LabeledContent(title) {
            Text(hideValues ? L10n.privacyHiddenLong : (value ?? L10n.generalNA))
                .monospacedDigit()
        }
    }

    private func transactionRow(_ transaction: HoldingTransaction) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
        return layout {
            Image(systemName: transaction.quantityDelta >= 0 ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                .foregroundStyle(transaction.quantityDelta >= 0 ? AppTheme.gain : AppTheme.loss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.kind.localizedName)
                    .font(.headline)
                Text(AppDateFormatter.displayDate(transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !typeSize.isAccessibilitySize { Spacer() }
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                Text(hideValues ? L10n.privacyHiddenLong : "\(transaction.quantityDelta >= 0 ? "+" : "−")\(formatQuantity(abs(transaction.quantityDelta)))")
                    .monospacedDigit()
                if !hideValues, let price = transaction.unitPrice {
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
        async let loadedPrice = viewModel.latestPriceInInstrumentCurrency(forIsin: isin)
        transactions = await loadedTransactions
        history = await loadedHistory
        latestPrice = await loadedPrice
        let data = await viewModel.cashflowData(transactions: transactions)
        cashflows = data.cashflows
        events = data.events
        hasCompleteCashflows = await viewModel.hasCompletePeriodCashflows(transactions)
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
    @State private var isSaving = false
    @State private var saveError: String?
    @AppStorage("privacyMode") private var privacyMode = false
    private var currency: String { viewModel.instruments.first { $0.isin == isin }?.currency ?? "EUR" }
    private var resultingQuantity: Double {
        let current = viewModel.holdings.first { $0.accountId == accountId && $0.isin == isin }?.quantity ?? 0
        let delta = (parseDecimal(quantityText) ?? 0) * (kind == .sell ? -1 : kind == .adjustment ? adjustmentDirection : 1)
        return current - (transaction?.quantityDelta ?? 0) + delta
    }
    private func validOptionalNumber(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseDecimal(text).map { $0.isFinite && $0 >= 0 } == true
    }
    private var isValid: Bool {
        parseDecimal(quantityText).map { $0.isFinite && $0 > 0 } == true && validOptionalNumber(priceText) && validOptionalNumber(feesText) && resultingQuantity >= -HoldingLedger.epsilon
    }

    var body: some View {
        NavigationStack {
            PrivacyProtectedEditor {
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
                PortfolioDecimalField(title: L10n.holdingsQuantity, text: $quantityText)
                PortfolioDecimalField(title: "\(L10n.designUnitPriceOptional) · \(currency)", text: $priceText)
                if kind != .adjustment {
                    PortfolioDecimalField(title: "\(L10n.holdingsFees) · \(currency)", text: $feesText)
                }
                TextField(L10n.holdingsNote, text: $note)
                Section {
                    LabeledContent(L10n.designNewBalance, value: formatQuantity(resultingQuantity))
                } footer: { Text(kind == .adjustment ? L10n.designCorrectionDeltaHint : L10n.designOptionalPriceHint) }
                if !quantityText.isEmpty && !isValid { Text(L10n.designInvalidNumber).foregroundStyle(.red) }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .disabled(isSaving || viewModel.demoMode.isDemoModeEnabled)
            }
            .navigationTitle(transaction == nil ? L10n.holdingsAddTransaction : L10n.generalEdit)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.generalCancel) { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? L10n.designSaving : L10n.generalSave) {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving || privacyMode || viewModel.demoMode.isDemoModeEnabled)
                }
            }
            .onAppear(perform: populate)
            .interactiveDismissDisabled(isSaving)
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
        guard isValid, !isSaving, let quantity = parseDecimal(quantityText) else { return }
        isSaving = true
        defer { isSaving = false }
        viewModel.dismissError()
        saveError = nil
        let dateString = AppDateFormatter.yearMonthDay.string(from: date)
        let price = parseDecimal(priceText)
        let fees = kind == .adjustment ? nil : parseDecimal(feesText)
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
        saveError = viewModel.errorMessage
        if saveError == nil { dismiss() }
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
