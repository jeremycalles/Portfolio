import SwiftUI

// MARK: - Settings View (in-window)
// On macOS, settings are consolidated in the application menu (Portfolio → Settings).
// This view is no longer used by the macOS sidebar; it remains for possible reuse (e.g. iOS or other entry points).
struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var demoMode = DemoModeManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Demo Mode Settings
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "eye.slash")
                                .font(.title2)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsDemoMode)
                                    .font(.headline)
                                Text(L10n.settingsDemoModeDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Toggle(L10n.settingsDemoModeEnable, isOn: $demoMode.isDemoModeEnabled)
                            .toggleStyle(.switch)
                        
                        if demoMode.isDemoModeEnabled {
                            HStack {
                                Text(L10n.settingsDemoModeActive)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Button {
                                    demoMode.regenerateSeed()
                                    viewModel.refreshAll()
                                } label: {
                                    Label(L10n.settingsDemoModeRandomize, systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                } label: {
                    Text(L10n.settingsDemoMode)
                }
                
                // Language Settings
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsLanguage)
                                    .font(.headline)
                                Text(L10n.settingsLanguageDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Picker("", selection: $languageManager.currentLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding()
                } label: {
                    Text(L10n.settingsLanguage)
                }
                
                // Data Management
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsDataManagement)
                                    .font(.headline)
                                Text(L10n.settingsUpdatePricesDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    await viewModel.updateAllPrices()
                                }
                            } label: {
                                Label(L10n.actionUpdatePrices, systemImage: "arrow.clockwise")
                            }
                            .disabled(viewModel.isLoading)
                            
                            Menu {
                                Button(L10n.actionBackfill1Year) {
                                    Task {
                                        await viewModel.backfillHistorical(period: "1y", interval: "1mo")
                                    }
                                }
                                Button(L10n.actionBackfill2Years) {
                                    Task {
                                        await viewModel.backfillHistorical(period: "2y", interval: "1mo")
                                    }
                                }
                                Button(L10n.actionBackfill5Years) {
                                    Task {
                                        await viewModel.backfillHistorical(period: "5y", interval: "1mo")
                                    }
                                }
                                Divider()
                                Button(L10n.actionBackfill1Month) {
                                    Task {
                                        await viewModel.backfillHistorical(period: "1mo", interval: "1d")
                                    }
                                }
                            } label: {
                                Label(L10n.settingsBackfillData, systemImage: "clock.arrow.circlepath")
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                    .padding()
                } label: {
                    Text(L10n.settingsDataManagement)
                }
                
                #if os(macOS)
                // Touch ID Protection
                MacOSTouchIDSettingSection()
                #endif
                
                // About
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsAbout)
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        
                        HStack {
                            Text(L10n.settingsVersion)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        }
                        
                        HStack {
                            Text(L10n.generalBuild)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        }
                    }
                    .padding()
                } label: {
                    Text(L10n.settingsAbout)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(L10n.settingsTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager.shared)
}
