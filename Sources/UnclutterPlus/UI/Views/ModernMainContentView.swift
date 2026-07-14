import SwiftUI
import Combine

/// 现代化主内容视图 - 采用 "Crystal & Canvas" 设计语言
/// 侧边栏导航 + 内容区域布局
struct ModernMainContentView: View {
    @StateObject private var viewModel = ModernMainContentViewModel()
    @ObservedObject private var designSystem = ModernDesignSystem.shared
    @Namespace private var animationNamespace
    
    // 状态管理
    @State private var selectedTab: String = "files"
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
        .frame(width: 800, height: 600) // Default size for preview/window
        .background(ModernDesignSystem.shared.color(.bgCanvas))
    }
    
    // MARK: - 侧边栏
    
    private var sidebarNavigation: some View {
        VStack(spacing: 0) {
            // App Logo
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, ModernDesignSystem.Spacing.xl)
                .padding(.bottom, ModernDesignSystem.Spacing.xxl)
                .opacity(0.9)
            
            // 导航按钮组
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                ForEach(viewModel.enabledTabs, id: \.self) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: animationNamespace
                    ) {
                        withAnimation(ModernDesignSystem.Motion.smooth) {
                            selectedTab = tab
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
                    .font(.system(size: 18))
                    .foregroundColor(isSettingsHovered ? .primary : .secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSettingsHovered ? Color.primary.opacity(0.1) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, ModernDesignSystem.Spacing.lg)
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
                .fill(Color.white.opacity(0.1))
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
            // 使用 ZStack + Opacity 实现淡入淡出切换，避免 Frame 变化
            ZStack {
                if selectedTab == "files" {
                    ModernFilesView()
                        .transition(.opacity)
                }
                
                if selectedTab == "clipboard" {
                    ModernClipboardView()
                        .transition(.opacity)
                }
                
                if selectedTab == "notes" {
                    ModernNotesView()
                        .transition(.opacity)
                }

                if selectedTab == "screenshots" {
                    ScreenshotsView()
                        .transition(.opacity)
                }
            }
            .animation(ModernDesignSystem.Motion.smooth, value: selectedTab)
        }
    }
    
    // MARK: - 空状态
    
    private var emptyStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("Ready to Unclutter")
                .font(.title)
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
            
            Button("Open Settings") {
                viewModel.showPreferences()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - 组件：侧边栏按钮

struct SidebarTabButton: View {
    let tab: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 选中态背景 (Pill shape)
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.15))
                        .matchedGeometryEffect(id: "tabBackground", in: namespace)
                        .frame(width: 44, height: 44)
                }
                
                // 悬停态背景
                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 44, height: 44)
                }
                
                // 图标
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(iconColor)
                    .symbolEffect(.bounce, value: isSelected) // iOS 17/macOS 14+ animation
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Motion.snap) {
                isHovered = hovering
            }
        }
        .help(tab.capitalized)
    }
    
    private var iconColor: Color {
        if isSelected {
            return .accentColor
        }
        return isHovered ? .primary : .secondary
    }
    
    private var iconName: String {
        switch tab {
        case "files": return "folder"
        case "clipboard": return "doc.on.clipboard"
        case "notes": return "note.text"
        case "screenshots": return "camera.viewfinder"
        default: return "square"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ModernMainContentViewModel: ObservableObject {
    @Published var enabledTabs: [String] = ["files", "clipboard", "notes", "screenshots"]
    @Published var selectedTab: String = "files"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    func showPreferences() {
        NotificationCenter.default.post(name: .showPreferences, object: nil)
    }
    
    private func setupBindings() {
        NotificationCenter.default.publisher(for: .configurationChanged)
            .sink { [weak self] _ in
                self?.updateEnabledTabs()
            }
            .store(in: &cancellables)
    }
    
    private func updateEnabledTabs() {
        // Reload from config if needed
    }
}

extension Notification.Name {
    static let showPreferences = Notification.Name("showPreferences")
    static let configurationChanged = Notification.Name("configurationChanged")
}
