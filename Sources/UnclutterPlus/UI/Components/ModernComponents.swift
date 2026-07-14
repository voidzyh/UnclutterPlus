import SwiftUI

// MARK: - Modern Shared Components (v2.0)

/// 统一的头部组件，包含标题/搜索和操作区
struct ModernHeader<Actions: View>: View {
    let title: String
    var subtitle: String? = nil
    @Binding var searchText: String
    let searchPlaceholder: String
    let actions: Actions
    
    init(
        title: String,
        subtitle: String? = nil,
        searchText: Binding<String>,
        searchPlaceholder: String = "Search...",
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self._searchText = searchText
        self.searchPlaceholder = searchPlaceholder
        self.actions = actions()
    }
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Title Area (Optional, usually we use the sidebar for context, but good to have)
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title)
                        .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
                    }
                }
            }
            
            // Search Bar
            CrystalSearchBar(text: $searchText, placeholder: searchPlaceholder)
                .frame(maxWidth: 300)
            
            Spacer()
            
            // Actions
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                actions
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.vertical, ModernDesignSystem.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

/// 水晶质感搜索栏
struct CrystalSearchBar: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .accentColor : .secondary)
                .font(.system(size: 14))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .animation(ModernDesignSystem.Motion.snap, value: isFocused)
    }
}

/// 统计卡片 (Chip Style)
struct ModernStatChip: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .accentColor
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
            
            Text(label)
                .font(.caption)
                .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

/// 标准操作按钮
struct ModernActionButton: View {
    let icon: String
    let label: String?
    let action: () -> Void
    var isProminent: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                if let label = label {
                    Text(label)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, label != nil ? 12 : 8)
            .padding(.vertical, 6)
            .foregroundColor(isProminent ? .white : .primary)
            .background(
                Group {
                    if isProminent {
                        Color.accentColor
                    } else {
                        Color.black.opacity(0.05)
                    }
                }
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .hoverScaleEffect()
    }
}
