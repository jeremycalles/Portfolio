import SwiftUI

// MARK: - Premium Settings Helper Views

struct SettingsSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(color)
                .clipShape(Circle())
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .textCase(nil)
        }
        .padding(.vertical, 8)
    }
}

struct PremiumSettingsRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color?
    let content: Content
    
    init(title: String, subtitle: String? = nil, icon: String? = nil, iconColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor ?? .primary)
                    .frame(width: 30, height: 30)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer(minLength: 16)
            
            content
        }
        .padding(.vertical, 6)
    }
}
