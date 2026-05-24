import SwiftUI

// MARK: - iOS Quadrant Report View
struct iOSQuadrantReportView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        List {
            // Period Picker
            Section {
                Picker(L10n.generalComparisonPeriod, selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
            }
            
            let report = viewModel.cachedQuadrantReport
            ForEach(report) { item in
                Section(item.quadrant?.name ?? L10n.instrumentsUnassigned) {
                    ForEach(item.holdings) { holding in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(holding.instrumentName)
                                    .font(.headline)
                                Spacer()
                                if let change = holding.changePercentEUR {
                                    ChangeLabel(change: change)
                                }
                            }
                            
                            HStack {
                                Text(L10n.holdingsQuantityUnits(formatQuantity(holding.quantity)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !privacyMode, let value = holding.currentValueEUR {
                                    Text(formatCurrency(value, currency: "EUR"))
                                        .fontWeight(.medium)
                                } else if privacyMode {
                                    Text(L10n.privacyHiddenLong)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Section Total (EUR)
                    HStack {
                        Text(L10n.summaryTotalEur)
                            .fontWeight(.semibold)
                        Spacer()
                        if !privacyMode {
                            Text(formatCurrency(item.totalValueEUR, currency: "EUR"))
                                .fontWeight(.bold)
                        } else {
                            Text(L10n.privacyHiddenLong)
                                .foregroundColor(.secondary)
                        }
                        if let change = item.changePercentEUR {
                            ChangeLabel(change: change)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.startRefreshTask(showCompletionDelay: false).value
        }
    }
}

// MARK: - Previews

#Preview("iOSQuadrantReportView") {
    NavigationStack {
        iOSQuadrantReportView(privacyMode: false)
            .environmentObject(AppViewModel.preview)
    }
}
