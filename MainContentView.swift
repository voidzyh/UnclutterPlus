import SwiftUI
import Combine

// MARK: - 优化的主内容视图

struct OptimizedMainContentView: View {
    // MARK: - State Management (优化版本)
    
    // 使用 @State 替代 @Published 用于局部状态
    @State private var selectedTab: Int = 0
    @State private var showingPreferences: Bool = false
    @State private var refreshToken: UUID = UUID()
    @State private var isLoading: Bool = false
    
    // 观察对象只在必要时使用
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // 服务层 - 使用依赖注入优化
    private let notesService: NotesService
    private var cancellables = Set<AnyCancellable>()
    
    // 缓存的计算属性
    private var cachedTabItems: [TabItem] = []
    private var cachedEnabledTabs: [String] = []
    
    // MARK: - Initialization
    
    init(notesService: NotesService = NotesService()) {
        self.notesService = notesService
        _selectedTab = State(initialValue: 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 优化的标签页选择器区域
            optimizedTabSelector
            
            Divider()
            
            // 优化的内容区域
            optimizedContentArea
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .padding(DesignSystem.Spacing.sm)
        .id(refreshToken) // 只在必要时强制刷新
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            handleAppActivation()
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
    }
    
    // MARK: - 优化的组件
    
    /// 优化的标签页选择器
    private var optimizedTabSelector: some View {
        ZStack {
            // 居中的标签页按钮（使用缓存）
            LazyHStack(spacing: 0) {
                ForEach(Array(getEnabledTabs().enumerated()), id: \.element) { index, tabId in
                    OptimizedTabButton(
                        title: getTabTitle(for: tabId),
                        systemImage: getTabIcon(for: tabId),
                        isSelected: selectedTab == index,
                        action: { selectTab(at: index) }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            
            // 右侧的设置按钮
            HStack {
                Spacer()
                OptimizedSettingsButton {
                    showingPreferences = true
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    /// 优化的内容区域
    private var optimizedContentArea: some View {
        Group {
            if !hasEnabledTabs {
                optimizedEmptyState
            } else {
                optimizedTabContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 优化的空状态显示
    private var optimizedEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("features.no_enabled.title".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("features.no_enabled.description".localized)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("features.open_settings".localized) {
                showingPreferences = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
    
    /// 优化的标签页内容
    private var optimizedTabContent: some View {
        Group {
            if let tabId = getEnabledTabs().safeValue(at: selectedTab) {
                TabContentView(
                    tabId: tabId,
                    notesService: notesService,
                    onAction: handleTabAction
                )
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - 辅助计算属性（缓存优化）
    
    private var hasEnabledTabs: Bool {
        !getEnabledTabs().isEmpty
    }
    
    private func getEnabledTabs() -> [String] {
        // 缓存启用的标签页
        if cachedEnabledTabs.isEmpty {
            cachedEnabledTabs = ConfigurationManager.shared.enabledTabsOrder
        }
        return cachedEnabledTabs
    }
    
    private func getTabTitle(for tabId: String) -> String {
        switch tabId {
        case "files": return "tab.files".localized
        case "clipboard": return "tab.clipboard".localized
        case "notes": return "tab.notes".localized
        default: return ""
        }
    }
    
    private func getTabIcon(for tabId: String) -> String {
        switch tabId {
        case "files": return "folder.fill"
        case "clipboard": return "doc.on.clipboard"
        case "notes": return "note.text"
        default: return ""
        }
    }
    
    // MARK: - 事件处理（性能优化）
    
    private func selectTab(at index: Int) {
        // 使用动画优化过渡
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = index
        }
    }
    
    private func refreshView() {
        // 清除缓存并刷新视图
        cachedEnabledTabs.removeAll()
        cachedTabItems.removeAll()
        refreshToken = UUID()
    }
    
    private func handleAppActivation() {
        // 延迟执行避免不必要的重绘
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 检查配置状态
            checkConfigurationState()
        }
    }
    
    private func handleTabAction(_ action: TabAction) {
        switch action {
        case .refresh:
            refreshView()
        case .showPreferences:
            showingPreferences = true
        }
    }
    
    private func checkConfigurationState() {
        // 轻量级配置检查
        let config = ConfigurationManager.shared
        let currentEnabledTabs = config.enabledTabsOrder
        
        // 如果标签页配置变化，更新视图
        if currentEnabledTabs != cachedEnabledTabs {
            cachedEnabledTabs = currentEnabledTabs
            // 验证当前选中的标签页是否仍然有效
            if selectedTab >= cachedEnabledTabs.count {
                selectedTab = 0
            }
            refreshToken = UUID()
        }
    }
}

// MARK: - 优化的标签页按钮

private struct OptimizedTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    // 使用 @State 优化局部状态
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    // 缓存计算属性以提高性能
    private let textColor: Color
    private let backgroundColor: Color
    private let shadowColor: Color
    
    init(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
        
        // 预计算样式属性
        self.textColor = isSelected ? .white : (isHovered ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
        self.backgroundColor = isSelected ? DesignSystem.Colors.accent : (isHovered ? DesignSystem.Colors.primaryText.opacity(0.1) : .clear)
        self.shadowColor = isSelected ? DesignSystem.Colors.accent.opacity(0.3) : (isHovered ? Color.black.opacity(0.1) : .clear)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(DesignSystem.Typography.body.weight(.medium))
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                
                Text(title)
                    .font(DesignSystem.Typography.body.weight(.medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, DesignSystem.Lg)
            .padding(.vertical, DesignSystem.Sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(isHovered && !isSelected ? DesignSystem.Colors.primaryText.opacity(0.3) : .clear, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: isSelected ? 4 : (isHovered ? 2 : 0), x: 0, y: isSelected || isHovered ? 1 : 0)
            )
            .scaleEffect(scaleEffect)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.fast, value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
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

// MARK: - 优化的设置按钮

private struct OptimizedSettingsButton: View {
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(DesignSystem.Typography.body.weight(.regular))
                .foregroundColor(isHovered ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovered ? DesignSystem.Colors.primaryText.opacity(0.1) : .clear)
                        .shadow(color: isHovered ? Color.black.opacity(0.1) : .clear, radius: 2, x: 0, y: 1)
                )
                .scaleEffect(scaleEffect)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .animation(.fast, value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .help("button.preferences".localized)
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

// MARK: - 标签页内容视图

private struct TabContentView: View {
    let tabId: String
    let notesService: NotesService
    let onAction: (TabAction) -> Void
    
    var body: some View {
        Group {
            switch tabId {
            case "files":
                OptimizedFilesView()
            case "clipboard":
                OptimizedClipboardView()
            case "notes":
                OptimizedNotesView(notesService: notesService)
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tabId)
    }
}

// MARK: - 优化占位视图

private struct OptimizedFilesView: View {
    var body: some View {
        VStack {
            Text("文件功能")
                .font(.title2)
            Text("优化版本")
                .foregroundColor(.secondary)
        }
    }
}

private struct OptimizedClipboardView: View {
    var body: some View {
        VStack {
            Text("剪贴板功能")
                .font(.title2)
            Text("优化版本")
                .foregroundColor(.secondary)
        }
    }
}

private struct OptimizedNotesView: View {
    let notesService: NotesService
    
    var body: some View {
        VStack {
            Text("笔记功能")
                .font(.title2)
            Text("服务集成版本")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 支持类型

private enum TabAction {
    case refresh
    case showPreferences
}

// MARK: - 扩展

private extension Array {
    func safeValue(at index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

private extension DesignSystem {
    // 优化常量，减少重复计算
    static let Lg: CGFloat = 16
    static let Sm: CGFloat = 8
}

// MARK: - 原始视图的兼容性包装

/// 兼容性包装器，允许渐进式迁移
struct MainContentViewWrapper: View {
    @StateObject private var viewModel = MainContentViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        OptimizedMainContentView()
            .environmentObject(viewModel)
            .environmentObject(localizationManager)
    }
}

// MARK: - 预览

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    OptimizedMainContentView()
        .frame(width: 800, height: 300)
}
#endif
