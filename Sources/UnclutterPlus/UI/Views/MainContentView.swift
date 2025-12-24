import SwiftUI
import Cocoa

struct MainContentView: View {
    @StateObject private var viewModel = MainContentViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var windowManager = WindowManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 自动隐藏倒计时进度条（仅在即将隐藏时显示）
            if windowManager.autoHideProgress > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.clear)

                        Rectangle()
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: geometry.size.width * windowManager.autoHideProgress)
                    }
                    .frame(height: 2)
                }
                .frame(height: 2)
                .transition(.opacity)
            }

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
                            ModernClipboardView()
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
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: isSelected ? 16 : 14, weight: .semibold))
                    .scaleEffect(isPressed ? 0.92 : 1.0)

                Text(title)
                    .font(.system(size: isSelected ? 15 : 13, weight: .semibold))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, isSelected ? 20 : 16)
            .padding(.vertical, isSelected ? 10 : 8)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(backgroundColor)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }

    // MARK: - 简化的样式计算

    private var textColor: Color {
        isSelected ? .white : DesignSystem.Colors.secondaryText.opacity(isHovered ? 0.8 : 0.6)
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.accent
        } else {
            return isHovered ? DesignSystem.Colors.primaryText.opacity(0.08) : .clear
        }
    }

    private var shadowColor: Color {
        isSelected ? DesignSystem.Colors.accent.opacity(0.4) : .clear
    }

    private var shadowRadius: CGFloat {
        isSelected ? 6 : 0
    }
}

struct SettingsButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(textColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("button.preferences".localized)
    }

    // MARK: - 简化的样式计算

    private var textColor: Color {
        DesignSystem.Colors.secondaryText.opacity(isHovered ? 0.7 : 0.5)
    }

    private var backgroundColor: Color {
        isHovered ? DesignSystem.Colors.primaryText.opacity(0.05) : .clear
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
