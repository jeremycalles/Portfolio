import SwiftUI

// MARK: - Shared Backfill Logs Sheet
struct BackfillLogsSheet: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                        if log.isEmpty {
                            Spacer().frame(height: 12)
                        } else {
                            Text(log)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(logColor(for: log))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Backfill Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #else
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Backfill Logs")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Logs content
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                        if log.isEmpty {
                            Spacer().frame(height: 8)
                        } else {
                            Text(log)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(logColor(for: log))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 400)
        #endif
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("✓") || log.contains("complete") {
            return .green
        } else if log.contains("⚠️") || log.contains("Skipped") || log.contains("No data returned") {
            return .orange
        } else if log.contains("Error") || log.contains("error") {
            return .red
        } else if log.starts(with: "  •") {
            return .secondary
        }
        return .primary
    }
}
