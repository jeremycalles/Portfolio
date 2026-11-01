#if os(iOS)
import SwiftUI

/// Setup lives in the first-use screen; no blocking tour or prerequisites.
struct iOSWalkthroughView: View {
    let onAdd: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(L10n.designWelcomeTitle).font(.largeTitle.bold())
            Text(L10n.designWelcomeMessage).foregroundStyle(.secondary)
            Button(action: onAdd) {
                Label(L10n.designFirstHolding, systemImage: "plus")
                    .foregroundStyle(AppTheme.onSelection)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.borderedProminent).tint(AppTheme.selection)
            Button(action: onRestore) {
                Label(L10n.designRestoreBackup, systemImage: "archivebox")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.bordered)
            Label(L10n.designStoredLocally, systemImage: "internaldrive")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).padding(.vertical, 24)
        .frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
    }
}
#endif
