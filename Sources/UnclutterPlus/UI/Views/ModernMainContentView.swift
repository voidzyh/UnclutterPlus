import SwiftUI
import Combine

/// 现代化主内容视图 - 采用最新 SwiftUI 特性和流畅动画
struct ModernMainContentView: View {
    @StateObject private var viewModel = ModernMainContentViewModel()
    @ObservedObject private var designSystem = ModernDesignSystem.shared
    @Namespace private var animationNamespace
    
    // 状态管理
    @State private var selectedTab: String = "files"
    @State private var previousTab: String = "files"
    @State private var tabAnimationProgress: Double = 0
    @State private var isTransitioning = false
    
    // 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    // 动画状态
    @State private var contentOpacity: Double = 1.0
    @State private var contentScale: Double = 1.0
    
    var body: some View {
        ZStack {
            // 背景层
            backgroundLayer
            
            // 主要内容
            mainContent
                .opacity(contentOpacity)
                .scaleEffect(contentScale)
                .offset(dragOffset)
                .gesture(dragGesture)
                .onChange(of: selectedTab) { oldValue, newValue in
                    handleTabChange(from: oldValue, to: newValue)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(ModernDesignSystem.CornerRadius.xlarge)
        .modernShadow(ModernDesignSystem.Shadow.xlarge)
        .padding(ModernDesignSystem.Spacing.sm)
        .animation(designSystem.fluidAnimation, value: selectedTab)
    }
    
    // MARK: - 背景层
    
    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.xlarge)
            .fill(
                LinearGradient(
                    colors: [Color.gradientStart, Color.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.xlarge)
                    .strokeBorder(
                        Color.accentColor.opacity(0.2),
                        lineWidth: 1
                    )
            )
    }
    
    // MARK: - 主要内容
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // 现代化标签页栏
            modernTabBar
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.vertical, ModernDesignSystem.Spacing.md)
            
            Divider()
                .background(Color.accentColor.opacity(0.1))
            
            // 内容区域
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 现代化标签页栏
    
    private var modernTabBar: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xl) {
            // 标签页按钮
            ForEach(viewModel.enabledTabs, id: \.self) { tab in
                ModernTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animationNamespace
                ) {
                    withAnimation(designSystem.springAnimation) {
                        selectedTab = tab
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            Spacer()
            
            // 设置按钮
            ModernSettingsButton {
                viewModel.showPreferences()
            }
        }
    }
    
    // MARK: - 内容区域
    
    @ViewBuilder
    private var contentArea: some View {
        if viewModel.enabledTabs.isEmpty {
            emptyStateView
        } else {
            tabContent
        }
    }
    
    // MARK: - 标签页内容
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case "files":
            ModernFilesView()
                .transition(.modernTabTransition)
                .id("files-\(selectedTab)")
        
        case "clipboard":
            ModernClipboardView()
                .transition(.modernTabTransition)
                .id("clipboard-\(selectedTab)")
        
        case "notes":
            ModernNotesView()
                .transition(.modernTabTransition)
                .id("notes-\(selectedTab)")
        
        default:
            EmptyView()
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xxl) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
            
            Text("Welcome to UnclutterPlus")
                .font(.title1)
                .foregroundColor(.adaptiveForeground)
            
            Text("Enable features in preferences to get started")
                .font(.callout)
                .foregroundColor(.adaptiveSecondary)
                .multilineTextAlignment(.center)
            
            Button("Open Preferences") {
                viewModel.showPreferences()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 拖动手势
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
                
                // 根据拖动距离调整透明度和缩放
                let progress = min(abs(dragOffset.width) / 200, 1.0)
                contentOpacity = 1.0 - progress * 0.3
                contentScale = 1.0 - progress * 0.1
            }
            .onEnded { value in
                isDragging = false
                
                // 判断是否切换标签页
                let translation = value.translation.width
                let velocity = value.velocity.width
                let shouldSwitch = abs(translation) > 100 || abs(velocity) > 500
                
                if shouldSwitch {
                    let currentIndex = viewModel.enabledTabs.firstIndex(of: selectedTab) ?? 0
                    let newIndex: Int
                    
                    if translation > 0 && currentIndex > 0 {
                        newIndex = currentIndex - 1
                    } else if translation < 0 && currentIndex < viewModel.enabledTabs.count - 1 {
                        newIndex = currentIndex + 1
                    } else {
                        newIndex = currentIndex
                    }
                    
                    if newIndex != currentIndex {
                        selectedTab = viewModel.enabledTabs[newIndex]
                    }
                }
                
                // 重置动画状态
                withAnimation(designSystem.springAnimation) {
                    dragOffset = .zero
                    contentOpacity = 1.0
                    contentScale = 1.0
                }
            }
    }
    
    // MARK: - 事件处理
    
    private func handleTabChange(from oldValue: String, to newValue: String) {
        previousTab = oldValue
        isTransitioning = true
        
        // 执行切换动画
        withAnimation(designSystem.fluidAnimation) {
            tabAnimationProgress = 1.0
        }
        
        // 重置动画状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
            tabAnimationProgress = 0
        }
    }
}

// MARK: - 现代化标签页按钮

struct ModernTabButton: View {
    let tab: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @ObservedObject private var designSystem = ModernDesignSystem.shared
    
    var body: some View {
        Button(action: {
            withAnimation(designSystem.springAnimation) {
                action()
            }
        }) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                // 图标
                Image(systemName: iconName)
                    .font(.title3.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(
                        isSelected ? .pulse : .pulse,
                        options: .repeating
                    )
                
                // 文本
                Text(tabTitle)
                    .font(.headline)
                    .fontWeight(isSelected ? .semibold : .medium)
                
                // 选中指示器
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 20)
                        .matchedGeometryEffect(id: "selectedTab", in: namespace)
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                            .strokeBorder(strokeColor, lineWidth: borderWidth)
                    )
                    .modernShadow(isSelected ? ModernDesignSystem.Shadow.medium : ModernDesignSystem.Shadow.small)
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .brightness(isHovered ? 0.1 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(designSystem.snappyAnimation) {
                isHovered = hovering
            }
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
    
    // MARK: 计算属性
    
    private var tabTitle: String {
        switch tab {
        case "files": return "Files"
        case "clipboard": return "Clipboard"
        case "notes": return "Notes"
        default: return tab.capitalized
        }
    }
    
    private var iconName: String {
        switch tab {
        case "files": return "folder.fill"
        case "clipboard": return "doc.on.clipboard"
        case "notes": return "note.text"
        default: return "square.fill"
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var strokeColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color.accentColor.opacity(0.5)
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }
}

// MARK: - 现代化设置按钮

struct ModernSettingsButton: View {
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @ObservedObject private var designSystem = ModernDesignSystem.shared
    
    var body: some View {
        Button(action: {
            withAnimation(designSystem.springAnimation) {
                action()
            }
        }) {
            Image(systemName: "gear")
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .rotationEffect(.degrees(isHovered ? 180 : 0))
                .foregroundColor(foregroundColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .modernShadow(isHovered ? ModernDesignSystem.Shadow.medium : ModernDesignSystem.Shadow.small)
                )
                .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.1 : 1.0))
                .rotationEffect(.degrees(isHovered ? 30 : 0))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(designSystem.snappyAnimation) {
                isHovered = hovering
            }
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
    
    private var foregroundColor: Color {
        isHovered ? .accentColor : .adaptiveSecondary
    }
    
    private var backgroundColor: Color {
        if isHovered {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - 现代化 ViewModel

@MainActor
final class ModernMainContentViewModel: ObservableObject {
    @Published var enabledTabs: [String] = ["files", "clipboard", "notes"]
    @Published var selectedTab: String = "files"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    func showPreferences() {
        // 实现显示首选项的逻辑
        NotificationCenter.default.post(name: .showPreferences, object: nil)
    }
    
    private func setupBindings() {
        // 监听配置变化
        NotificationCenter.default.publisher(for: .configurationChanged)
            .sink { [weak self] _ in
                self?.updateEnabledTabs()
            }
            .store(in: &cancellables)
    }
    
    private func updateEnabledTabs() {
        // 根据配置更新启用的标签页
        withAnimation(ModernDesignSystem.shared.smoothAnimation) {
            // 这里应该根据实际配置更新 enabledTabs
        }
    }
}

// MARK: - 扩展和工具

extension Notification.Name {
    static let showPreferences = Notification.Name("showPreferences")
    static let configurationChanged = Notification.Name("configurationChanged")
}

extension AnyTransition {
    static var modernTabTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
}

// MARK: - 预览

#Preview {
    ModernMainContentView()
        .frame(width: 900, height: 600)
}