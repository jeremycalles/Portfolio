import SwiftUI

// MARK: - Storage Logs View (iOS & macOS)
struct StorageLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dbService = DatabaseService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if dbService.storageLogEntries.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(L10n.settingsNoLogsAvailable)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(L10n.settingsStorageLogsDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(Array(dbService.storageLogEntries.reversed())) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: entry.isError ? "xmark.circle.fill" : (entry.isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"))
                                    .foregroundColor(entry.isError ? .red : (entry.isWarning ? .orange : .green))
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.message)
                                        .font(.system(size: 13, design: .monospaced))
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(L10n.settingsStorageLogs)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
