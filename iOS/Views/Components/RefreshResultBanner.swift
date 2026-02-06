import SwiftUI

// MARK: - Refresh Result Banner
/// A toast-style banner that slides in from the top to show the outcome of a manual price refresh.
/// - Success: green with checkmark, auto-dismisses after 4 seconds
/// - Partial: orange with warning icon, stays until dismissed, expandable error list
/// - Failure: red with error icon, stays until dismissed, expandable error list
struct RefreshResultBanner: View {
    let result: RefreshResult
    let onDismiss: () -> Void
    @State private var showDetails = false
    
    private var accentColor: Color {
        if result.succeeded {
            return .green
        } else if result.successCount > 0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var icon: String {
        if result.succeeded {
            return "checkmark.circle.fill"
        } else if result.successCount > 0 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var titleText: String {
        if result.succeeded {
            return L10n.refreshSuccess
        } else if result.successCount > 0 {
            return L10n.refreshPartial
        } else {
            return L10n.refreshFailed
        }
    }
    
    private var subtitleText: String {
        if result.succeeded {
            return L10n.refreshSuccessDetail(result.totalCount)
        } else {
            return L10n.refreshResultDetail(result.successCount, result.totalCount)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !result.failedInstruments.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDetails.toggle()
                        }
                    } label: {
                        Image(systemName: showDetails ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.body)
                            .foregroundStyle(accentColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            // Expandable error details
            if showDetails && !result.failedInstruments.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.refreshFailedInstruments)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.failedInstruments, id: \.self) { name in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red.opacity(0.7))
                                        .frame(width: 5, height: 5)
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        .padding(.horizontal)
    }
}
