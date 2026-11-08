import SwiftUI

struct AddHoldingSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("privacyMode") private var privacyMode = false
    @State private var selectedAccountId: Int?
    @State private var selectedIsin: String?
    @State private var quantityText = ""
    @State private var priceText = ""
    @State private var date = Date()
    @State private var correctBalance = false
    @State private var isSaving = false
    @State private var showingAccount = false
    @State private var showingInstrument = false
    @State private var knownAccountIDs: Set<Int> = []

    private var existingQuantity: Double {
        viewModel.holdings.first { $0.accountId == selectedAccountId && $0.isin == selectedIsin }?.quantity ?? 0
    }
    private var quantity: Double? { parseDecimal(quantityText) }
    private var priceValid: Bool {
        priceText.trimmingCharacters(in: .whitespaces).isEmpty || parseDecimal(priceText).map { $0.isFinite && $0 >= 0 } == true
    }
    private var isValid: Bool {
        selectedAccountId != nil && selectedIsin != nil && quantity.map { $0.isFinite && $0 > 0 } == true && priceValid
    }
    private var currency: String { viewModel.instruments.first { $0.isin == selectedIsin }?.currency ?? "EUR" }

    var body: some View {
        NavigationStack {
            PrivacyProtectedEditor {
                Form {
                    if viewModel.demoMode.isDemoModeEnabled {
                        Text(L10n.designDemoEditHint)
                    } else {
                        Section(L10n.holdingsInstrument) {
                            Picker(L10n.holdingsSelectInstrument, selection: $selectedIsin) {
                                Text(L10n.designChoose).tag(nil as String?)
                                ForEach(viewModel.instruments) { Text($0.displayName).tag(Optional($0.isin)) }
                            }
                            Button(L10n.designNewInstrument) { showingInstrument = true }
                        }
                        Section(L10n.accountsTitle) {
                            Picker(L10n.accountsSelectAccount, selection: $selectedAccountId) {
                                Text(L10n.designChoose).tag(nil as Int?)
                                ForEach(viewModel.bankAccounts) { Text($0.displayName).tag(Optional($0.id)) }
                            }
                            #if os(iOS)
                            Button(L10n.designNewAccount) {
                                knownAccountIDs = Set(viewModel.bankAccounts.map(\.id))
                                showingAccount = true
                            }
                            #endif
                        }
                        Section {
                            if existingQuantity > 0 {
                                Picker(L10n.holdingsTransactions, selection: $correctBalance) {
                                    Text(L10n.designBuyMore).tag(false)
                                    Text(L10n.designSetBalance).tag(true)
                                }
                            }
                            DatePicker(L10n.designTransactionDate, selection: $date, in: ...Date(), displayedComponents: .date)
                                .disabled(correctBalance)
                            PortfolioDecimalField(title: L10n.holdingsQuantity, text: $quantityText)
                            PortfolioDecimalField(title: "\(L10n.designUnitPrice) · \(currency)", text: $priceText, placeholder: L10n.designOptional)
                        } footer: { Text(L10n.designOptionalPriceHint) }
                        if let quantity, quantity > 0 {
                            Section {
                                LabeledContent(L10n.designNewBalance, value: "\(formatQuantity(existingQuantity)) → \(formatQuantity(correctBalance ? quantity : existingQuantity + quantity))")
                            } footer: { Text(correctBalance ? L10n.designBalanceExplanation : L10n.designBuyExplanation) }
                        }
                        if (!quantityText.isEmpty && quantity.map { $0.isFinite && $0 > 0 } != true) || !priceValid {
                            Text(L10n.designInvalidNumber).font(.caption).foregroundStyle(.red)
                        }
                        if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle(L10n.holdingsAddHolding)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.generalCancel) { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? L10n.designSaving : L10n.generalSave) { Task { await save() } }
                        .disabled(!isValid || isSaving || privacyMode || viewModel.demoMode.isDemoModeEnabled)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                if viewModel.bankAccounts.count == 1 { selectedAccountId = viewModel.bankAccounts.first?.id }
                if viewModel.instruments.count == 1 { selectedIsin = viewModel.instruments.first?.isin }
            }
            .onChange(of: selectedAccountId) { _, _ in correctBalance = false }
            .onChange(of: selectedIsin) { _, _ in correctBalance = false }
            .sheet(isPresented: $showingInstrument) {
                InstrumentSetupSheet { selectedIsin = $0.isin }
            }
            #if os(iOS)
            .sheet(isPresented: $showingAccount, onDismiss: {
                selectedAccountId = viewModel.bankAccounts.first { !knownAccountIDs.contains($0.id) }?.id ?? selectedAccountId
            }) { AddBankAccountSheet() }
            #else
            .frame(minWidth: 460, minHeight: 480)
            #endif
        }
    }

    private func save() async {
        guard isValid, let account = selectedAccountId, let isin = selectedIsin, let quantity else { return }
        isSaving = true
        defer { isSaving = false }
        viewModel.dismissError()
        if correctBalance {
            await viewModel.recordAdjustment(accountId: account, isin: isin, quantityDelta: quantity - existingQuantity,
                date: AppDateFormatter.todayString, unitPrice: parseDecimal(priceText), note: nil)
        } else {
            await viewModel.addHolding(accountId: account, isin: isin, quantity: quantity,
                purchaseDate: AppDateFormatter.yearMonthDay.string(from: date), purchasePrice: parseDecimal(priceText))
        }
        if viewModel.errorMessage == nil { dismiss() }
    }
}

/// Lookup is a preview. Only the confirmed instrument is persisted; no holdings
/// or account information is sent to the existing public market providers.
struct InstrumentSetupSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    var onCreated: (Instrument) -> Void = { _ in }
    @State private var identifier = ""
    @State private var result: MarketDataResult?
    @State private var manual = false
    @State private var name = ""
    @State private var currency = "EUR"
    @State private var quadrant: Int?
    @State private var isBusy = false
    @State private var message: String?

    private var cleanIdentifier: String { identifier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var canSave: Bool { !cleanIdentifier.isEmpty && (result != nil || (manual && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.designIdentifier, text: $identifier)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .disabled(isBusy)
                        .onChange(of: identifier) { _, _ in result = nil; message = nil }
                    Button(L10n.designLookUp) { Task { await lookup() } }
                        .disabled(cleanIdentifier.isEmpty || isBusy)
                    if isBusy { ProgressView() }
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                } footer: { Text(L10n.designIdentifierHint) }
                if let result {
                    Section(L10n.holdingsInstrument) {
                        LabeledContent(L10n.instrumentsName, value: result.name ?? result.isin)
                        LabeledContent(L10n.designIdentifier, value: result.isin)
                        LabeledContent(L10n.instrumentsCurrency, value: result.currency ?? "EUR")
                        if let price = result.value {
                            LabeledContent(L10n.instrumentsCurrentPrice, value: formatCurrency(price, currency: result.currency ?? "EUR"))
                            LabeledContent(L10n.designPricesAsOf, value: AppDateFormatter.displayDate(result.date))
                        }
                    }
                } else {
                    Toggle(L10n.designManualInstrument, isOn: $manual)
                    if manual {
                        TextField(L10n.instrumentsName, text: $name)
                        Picker(L10n.instrumentsCurrency, selection: $currency) {
                            ForEach(["EUR", "USD", "GBP", "CHF", "JPY"], id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                if canSave {
                    Picker(L10n.designCategories, selection: $quadrant) {
                        Text(L10n.designUnassignedCategory).tag(nil as Int?)
                        ForEach(viewModel.quadrants) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
            }
            .navigationTitle(L10n.designNewInstrument)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            .frame(minWidth: 460, minHeight: 430)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.generalCancel) { dismiss() }.disabled(isBusy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalAdd) { Task { await save() } }
                        .accessibilityLabel(L10n.designConfirmInstrument)
                        .disabled(!canSave || isBusy || viewModel.demoMode.isDemoModeEnabled)
                }
            }.interactiveDismissDisabled(isBusy)
        }
    }

    private func lookup() async {
        isBusy = true; message = nil
        let fetched = await viewModel.marketData.fetchData(isin: cleanIdentifier)
        isBusy = false
        if fetched.name != nil || fetched.value != nil { result = fetched }
        else { message = L10n.designLookupFailed }
    }

    private func save() async {
        guard canSave else { return }
        isBusy = true
        defer { isBusy = false }
        let isin = result?.isin ?? cleanIdentifier
        // Selecting an existing instrument must not overwrite its metadata.
        if let existing = viewModel.instruments.first(where: { $0.isin == isin }) {
            onCreated(existing); dismiss(); return
        }
        let instrument = Instrument(isin: isin, ticker: result?.ticker, name: result?.name ?? name,
            currency: result?.currency ?? currency, quadrantId: quadrant)
        let price = result.flatMap { result in result.value.map { Price(id: nil, isin: isin, date: result.date, value: $0, currency: result.currency) } }
        guard await viewModel.db.createInstrument(instrument, price: price) else { message = L10n.errorSaveFailed; return }
        await viewModel.refreshInstruments()
        await viewModel.recomputeDashboardCache()
        guard viewModel.instruments.contains(where: { $0.isin == isin }) else { message = L10n.errorSaveFailed; return }
        onCreated(instrument); dismiss()
    }
}
