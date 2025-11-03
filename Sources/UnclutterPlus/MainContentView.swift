import SwiftUI
import Cocoa

struct MainContentView: View {
    @StateObject private var viewModel = MainContentViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器区域
            ZStack {
                // 居中的标签页按钮
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.enabledTabs.enumerated()), id: \.element) { index, tabId in
                        TabButton(
                            title: getTabTitle(for: tabId),
                            systemImage: getTabIcon(for: tabId),
                            isSelected: viewModel.selectedTab == index
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedTab = index
                            }
                        }
                    }
                }
                
                // 右侧的设置按钮
                HStack {
                    Spacer()
                    SettingsButton {
                        viewModel.showPreferences()
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            
            Divider()
            
            // 内容区域
            Group {
                if !viewModel.hasEnabledTabs {
                    // 没有启用任何功能时显示提示
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("features.no_enabled.title".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("features.no_enabled.description".localized)
                            .foregroundColor(.secondary)

                        Button("features.open_settings".localized) {
                            viewModel.showPreferences()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 根据启用的功能显示对应内容
                    if let tabId = viewModel.tabIdentifier(at: viewModel.selectedTab) {
                        switch tabId {
                        case "files":
                            FilesView()
                                .transition(.opacity)
                        case "clipboard":
                            ClipboardView()
                                .transition(.opacity)
                        case "notes":
                            NotesView()
                                .transition(.opacity)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTab)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .padding(DesignSystem.Spacing.sm)
        .id(viewModel.refreshToken) // 强制刷新视图
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            viewModel.forceRefreshForLocalizationChange()
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 应用激活时检查配置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.handleAppDidBecomeActive()
            }
        }
    }
    
    // 获取标签页标题
    private func getTabTitle(for tabId: String) -> String {
        switch tabId {
        case "files":
            return "tab.files".localized
        case "clipboard":
            return "tab.clipboard".localized
        case "notes":
            return "tab.notes".localized
        default:
            return ""
        }
    }
    
    // 获取标签页图标
    private func getTabIcon(for tabId: String) -> String {
        switch tabId {
        case "files":
            return "folder.fill"
        case "clipboard":
            return "doc.on.clipboard"
        case "notes":
            return "note.text"
        default:
            return ""
        }
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(DesignSystem.Typography.body.weight(.medium))
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .animation(DesignSystem.Animation.spring, value: isPressed)

                Text(title)
                    .font(DesignSystem.Typography.body.weight(.medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
            )
            .scaleEffect(scaleEffect)
            .animation(DesignSystem.Animation.spring, value: isHovered)
            .animation(DesignSystem.Animation.fast, value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }

    // MARK: - 计算属性：状态驱动的样式

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isHovered {
            return DesignSystem.Colors.primaryText
        } else {
            return DesignSystem.Colors.secondaryText
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.accent
        } else if isHovered {
            return DesignSystem.Colors.primaryText.opacity(0.1)
        } else {
            return .clear
        }
    }

    private var borderColor: Color {
        if isHovered && !isSelected {
            return DesignSystem.Colors.primaryText.opacity(0.3)
        } else {
            return .clear
        }
    }

    private var shadowColor: Color {
        if isSelected {
            return DesignSystem.Colors.accent.opacity(0.3)
        } else if isHovered {
            return Color.black.opacity(0.1)
        } else {
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        if isSelected {
            return 4
        } else if isHovered {
            return 2
        } else {
            return 0
        }
    }

    private var shadowOffset: CGFloat {
        if isSelected || isHovered {
            return 1
        } else {
            return 0
        }
    }

    private var scaleEffect: CGFloat {
        if isPressed {
            return 0.95
        } else if isHovered {
            return 1.03
        } else {
            return 1.0
        }
    }
}

struct SettingsButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(DesignSystem.Typography.body.weight(.regular))
                .foregroundColor(textColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 1)
                )
                .scaleEffect(scaleEffect)
                .animation(DesignSystem.Animation.spring, value: isHovered)
                .animation(DesignSystem.Animation.fast, value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
        .help("button.preferences".localized)
    }

    // MARK: - 计算属性：状态驱动的样式

    private var textColor: Color {
        isHovered ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText
    }

    private var backgroundColor: Color {
        isHovered ? DesignSystem.Colors.primaryText.opacity(0.1) : .clear
    }

    private var shadowColor: Color {
        isHovered ? Color.black.opacity(0.1) : .clear
    }

    private var shadowRadius: CGFloat {
        isHovered ? 2 : 0
    }

    private var scaleEffect: CGFloat {
        if isPressed {
            return 0.9
        } else if isHovered {
            return 1.1
        } else {
            return 1.0
        }
    }
}

// 扩展Button以支持按下事件
extension View {
    func pressEvents(onPress: @escaping () -> Void = {}, onRelease: @escaping () -> Void = {}) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    MainContentView()
        .frame(width: 800, height: 300)
}
#endif
