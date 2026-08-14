import SwiftUI
import Combine

/// 现代化主内容视图 - 采用 "Crystal & Canvas" 设计语言
/// 侧边栏导航 + 内容区域布局
struct ModernMainContentView: View {
    @StateObject private var viewModel = ModernMainContentViewModel()
    @Namespace private var animationNamespace

    // 状态管理（selectedTab 唯一数据源在 viewModel，视图不再自持副本）
    @State private var isSettingsHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // 左侧水晶导航栏
            sidebarNavigation
                .frame(width: ModernDesignSystem.Spacing.sidebarWidth)
                .zIndex(10)

            // 右侧画布内容区
            ZStack {
                ModernDesignSystem.shared.color(.bgCanvas)
                    .ignoresSafeArea()

                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 圆角裁剪由 WindowManager 在 AppKit 层完成（Radius.lg），SwiftUI 层不再重复裁剪；
        // 根背景已被不透明内容区覆盖，仅保留自适应描边
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.lg, style: .continuous)
                .strokeBorder(ModernDesignSystem.shared.color(.strokeAdaptive), lineWidth: 1)
        )
    }

    // MARK: - 侧边栏

    private var sidebarNavigation: some View {
        VStack(spacing: 0) {
            // App 标识（紧凑）
            Image(systemName: "tray.full.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.shell, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .padding(.top, ModernDesignSystem.Spacing.lg)
                .padding(.bottom, ModernDesignSystem.Spacing.md)

            // 导航按钮组
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(viewModel.enabledTabs) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: viewModel.selectedTab == tab,
                        namespace: animationNamespace
                    ) {
                        withAnimation(ModernDesignSystem.Motion.smooth) {
                            viewModel.selectTab(tab)
                        }
                    }
                }
            }

            Spacer()

            // 底部设置按钮
            Button(action: {
                viewModel.showPreferences()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(isSettingsHovered ? .primary : .secondary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.shell, style: .continuous)
                            .fill(isSettingsHovered ? ModernDesignSystem.shared.color(.bgSurfaceHover) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, ModernDesignSystem.Spacing.md)
            .onHover { hovering in
                withAnimation(ModernDesignSystem.Motion.snap) {
                    isSettingsHovered = hovering
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(ModernDesignSystem.shared.color(.strokeAdaptive))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.enabledTabs.isEmpty {
            emptyStateView
        } else {
            // 常驻保活：已访问的 tab 视图保留在视图树中（隐藏不销毁），
            // 切换时仅调整透明度/层级，保留各自的滚动、搜索与选中状态
            ZStack {
                keepAliveTab(.files) { ModernFilesView() }
                keepAliveTab(.clipboard) { ModernClipboardView() }
                keepAliveTab(.notes) { ModernNotesView() }
                keepAliveTab(.screenshots) { ScreenshotsView() }
            }
            .animation(ModernDesignSystem.Motion.smooth, value: viewModel.selectedTab)
        }
    }

    /// 单个 tab 的常驻容器：首次切换到才创建（首启懒加载），激活时淡入 + 10px 滑入（spec §5）
    @ViewBuilder
    private func keepAliveTab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        if viewModel.visitedTabs.contains(tab) {
            let isActive = viewModel.selectedTab == tab
            content()
                .opacity(isActive ? 1 : 0)
                .offset(x: isActive ? 0 : 10)
                .allowsHitTesting(isActive)
                .zIndex(isActive ? 1 : 0)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("app.empty.title".localized)
                .font(.title)
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))

            Button("app.empty.open_settings".localized) {
                viewModel.showPreferences()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - 组件：侧边栏按钮

struct SidebarTabButton: View {
    let tab: AppTab
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // 选中态背景 (Pill shape)
                if isSelected {
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.shell, style: .continuous)
                        .fill(ModernDesignSystem.shared.color(.accentSoft))
                        .matchedGeometryEffect(id: "tabBackground", in: namespace)
                        .frame(width: 40, height: 40)
                }

                // 悬停态背景
                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.shell, style: .continuous)
                        .fill(ModernDesignSystem.shared.color(.bgSurfaceHover))
                        .frame(width: 40, height: 40)
                }

                // 图标（hover 时轻微放大 + 主题色辉光，spec §4）
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(iconColor)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .shadow(color: isHovered ? tab.color.opacity(0.5) : .clear, radius: 4)
                    .symbolEffect(.bounce, value: isSelected) // iOS 17/macOS 14+ animation
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Motion.snap) {
                isHovered = hovering
            }
        }
        .help(tab.title)
    }

    private var iconColor: Color {
        if isSelected {
            return .accentColor
        }
        return isHovered ? .primary : .secondary
    }
}

// MARK: - ViewModel

@MainActor
final class ModernMainContentViewModel: ObservableObject {
    /// 当前启用的 tab（顺序与开关来自 ConfigurationManager 的用户配置）
    @Published private(set) var enabledTabs: [AppTab] = []
    /// 当前选中 tab（唯一数据源）
    @Published private(set) var selectedTab: AppTab = .files
    /// 已访问过的 tab：首次切换到才创建对应视图（懒加载），之后常驻保活
    @Published private(set) var visitedTabs: Set<AppTab> = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 启动时优先落在用户配置的默认标签页
        if let defaultTab = AppTab(rawValue: ConfigurationManager.shared.defaultTab) {
            selectedTab = defaultTab
        }
        updateEnabledTabs()
        setupBindings()
    }

    func selectTab(_ tab: AppTab) {
        selectedTab = tab
        visitedTabs.insert(tab)
    }

    func showPreferences() {
        NotificationCenter.default.post(name: .showPreferences, object: nil)
    }

    private func setupBindings() {
        // 配置变更（tab 开关/顺序/默认标签）时刷新
        NotificationCenter.default.publisher(for: .configurationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateEnabledTabs()
            }
            .store(in: &cancellables)
    }

    /// 从 ConfigurationManager 读取启用开关 / 顺序 / 默认标签，刷新 tab 列表并校正选中项
    private func updateEnabledTabs() {
        let config = ConfigurationManager.shared
        let tabs = config.enabledTabsOrder.compactMap { AppTab(rawValue: $0) }
        enabledTabs = tabs

        // 选中项被关闭时回退到默认标签（默认也不可用时取第一个）
        if !tabs.contains(selectedTab) {
            let fallback = AppTab(rawValue: config.defaultTab) ?? .files
            selectedTab = tabs.contains(fallback) ? fallback : (tabs.first ?? .files)
        }
        visitedTabs.insert(selectedTab)
    }
}

extension Notification.Name {
    static let showPreferences = Notification.Name("showPreferences")
    static let configurationChanged = Notification.Name("configurationChanged")
}
