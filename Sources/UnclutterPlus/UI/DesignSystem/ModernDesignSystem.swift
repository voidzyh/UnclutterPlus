import SwiftUI

// MARK: - 现代化设计系统 (v2.0)

/// 现代化设计系统 - 提供统一的视觉语言、动画和交互规范
/// Design Philosophy: "Crystal & Canvas"
@MainActor
final class ModernDesignSystem: ObservableObject, @unchecked Sendable {
    @MainActor
    static let shared = ModernDesignSystem()
    
    // MARK: - 主题状态
    
    @Published var currentTheme: AppTheme = .system
    @Published var colorScheme: ColorScheme = .light
    @Published var tintColor: Color = .blue
    
    private init() {
        setupThemeObserver()
    }
    
    // MARK: - 动画系统 (Motion)
    
    enum Motion {
        /// 极快 - 用于微交互 (Hover, Click)
        static let snap = Animation.spring(response: 0.2, dampingFraction: 0.7, blendDuration: 0)
        /// 快速 - 用于一般状态变化
        static let fast = Animation.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0.1)
        /// 平滑 - 用于布局变化和页面切换
        static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.15)
        /// 弹性 - 用于强调性动画
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.2)
    }
    
    // MARK: - 间距系统 (Spacing)
    
    enum Spacing {
        /// 4px - 紧凑间距
        static let xs: CGFloat = 4
        /// 8px - 组件内间距
        static let sm: CGFloat = 8
        /// 12px - 标准元素间距
        static let md: CGFloat = 12
        /// 16px - 容器内边距
        static let lg: CGFloat = 16
        /// 24px - 区块间距
        static let xl: CGFloat = 24
        /// 32px - 主要布局分割
        static let xxl: CGFloat = 32
        
        /// 侧边栏宽度
        static let sidebarWidth: CGFloat = 68
        /// 扩展侧边栏宽度
        static let sidebarWidthExpanded: CGFloat = 200
        /// 顶部工具栏高度
        static let toolbarHeight: CGFloat = 44
    }
    
    // MARK: - 圆角系统 (Radius)
    
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }
    
    // MARK: - 颜色系统 (Semantic)
    
    /// 获取当前主题下的语义颜色
    func color(_ token: ColorToken) -> Color {
        // 这里可以根据 currentTheme 扩展更多逻辑
        return token.color
    }
    
    // MARK: - 主题切换逻辑
    
    func switchTheme(_ theme: AppTheme) {
        withAnimation(Motion.smooth) {
            currentTheme = theme
            applyTheme(theme)
        }
    }
    
    private func setupThemeObserver() {
        // 监听系统外观变化
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSystemThemeChange()
            }
        }
    }
    
    private func handleSystemThemeChange() {
        if currentTheme == .system {
            updateSystemTheme()
        }
    }
    
    private func updateSystemTheme() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        colorScheme = isDark ? .dark : .light
    }
    
    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system: updateSystemTheme()
        case .light: colorScheme = .light
        case .dark: colorScheme = .dark
        case .colorful: 
            colorScheme = .light
            tintColor = .purple
        }
    }
}

// MARK: - 颜色令牌 (Color Tokens)

enum ColorToken {
    case bgCanvas
    case bgSurface
    case bgSurfaceHover
    case textPrimary
    case textSecondary
    case textTertiary
    case borderSubtle
    case borderFocus
    
    var color: Color {
        switch self {
        case .bgCanvas:
            return Color(nsColor: .windowBackgroundColor)
        case .bgSurface:
            return Color("SurfaceColor") // 需要在 Assets 能够回退，这里暂时使用系统色
        case .bgSurfaceHover:
            return Color.primary.opacity(0.05)
        case .textPrimary:
            return Color.primary
        case .textSecondary:
            return Color.secondary
        case .textTertiary:
            return Color(nsColor: .tertiaryLabelColor)
        case .borderSubtle:
            return Color.primary.opacity(0.1)
        case .borderFocus:
            return Color.accentColor.opacity(0.5)
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// 这里的 'designSystem' 访问可能会有些问题，建议直接使用 static 常量或者环境对象
    /// 为方便起见，我们使用 extension 方法
    
    /// 玻璃拟态背景 (Crystal Effect)
    func glassEffect(_ material: Material = .ultraThinMaterial, cornerRadius: CGFloat = ModernDesignSystem.Radius.lg) -> some View {
        self.background(material)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    /// 卡片样式 (Canvas Card)
    func cardStyle(hover: Bool = false) -> some View {
        self.background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(ModernDesignSystem.Radius.md)
            .shadow(color: Color.black.opacity(hover ? 0.12 : 0.06), radius: hover ? 8 : 4, x: 0, y: hover ? 4 : 2)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.md)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
    
    /// 悬停缩放效果
    func hoverScaleEffect(scale: CGFloat = 1.02) -> some View {
        self.modifier(HoverScaleModifier(scale: scale))
    }
    
    /// 点击涟漪效果 (简单版)
    func pressEffect() -> some View {
        self.buttonStyle(PlainButtonStyle()) // Reset styling
            .modifier(PressEffectModifier())
    }
}

// MARK: - Modifiers Implementation

struct HoverScaleModifier: ViewModifier {
    let scale: CGFloat
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(ModernDesignSystem.Motion.snap, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(ModernDesignSystem.Motion.snap, value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

// MARK: - Typography Extension

extension Font {
    static let display = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 16, weight: .semibold, design: .default)
    static let body = Font.system(size: 14, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
    static let code = Font.system(size: 13, weight: .regular, design: .monospaced)
}

// MARK: - Enums & Support Structures

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case colorful = "Colorful"
    
    var icon: String {
        switch self {
        case .system: return "gearshape.2"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .colorful: return "paintbrush.fill"
        }
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}
