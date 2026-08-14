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
                        .font(.roundedTitle)
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
                .fill(ModernDesignSystem.shared.color(.strokeAdaptive))
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
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
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
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.sm)
                .fill(ModernDesignSystem.shared.color(.bgSurfaceHover))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.sm)
                .stroke(isFocused ? ModernDesignSystem.shared.color(.borderFocus) : Color.clear, lineWidth: 1)
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
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
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
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
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
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                if let label = label {
                    Text(label)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, label != nil ? ModernDesignSystem.Spacing.md : ModernDesignSystem.Spacing.sm)
            .padding(.vertical, ModernDesignSystem.Spacing.xs)
            .foregroundColor(isProminent ? .white : ModernDesignSystem.shared.color(.textPrimary))
            .background(
                Group {
                    if isProminent {
                        // 主按钮：accent 渐变 + 白字 (spec §5)
                        LinearGradient(
                            colors: [
                                ModernDesignSystem.shared.color(.accentMain),
                                ModernDesignSystem.shared.color(.accentMain).opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        ModernDesignSystem.shared.color(.bgSurfaceHover)
                    }
                }
            )
            .cornerRadius(ModernDesignSystem.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.sm)
                    .stroke(isProminent ? Color.clear : ModernDesignSystem.shared.color(.strokeAdaptive), lineWidth: 0.5)
            )
            .shadow(color: isProminent ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .hoverScaleEffect()
    }
}
