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
            
            // Quadrant Reports
            let report = viewModel.getQuadrantReport()
            ForEach(report) { item in
                Section(item.quadrant?.name ?? "Unassigned") {
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
                                Text("\(holding.quantity, specifier: "%.4f") units")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !privacyMode, let value = holding.currentValueEUR {
                                    Text(formatCurrency(value, currency: "EUR"))
                                        .fontWeight(.medium)
                                } else if privacyMode {
                                    Text("***")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Section Total (EUR)
                    HStack {
                        Text("Total (EUR)")
                            .fontWeight(.semibold)
                        Spacer()
                        if !privacyMode {
                            Text(formatCurrency(item.totalValueEUR, currency: "EUR"))
                                .fontWeight(.bold)
                        } else {
                            Text("***")
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
            await viewModel.updateAllPrices(showCompletionDelay: false)
        }
    }
}
