import SwiftUI

// MARK: - 现代化设计系统

/// 现代化设计系统 - 支持动态主题和流畅动画
@MainActor
final class ModernDesignSystem: ObservableObject {
    @MainActor
    static let shared = ModernDesignSystem()
    
    // MARK: - 主题管理
    
    @Published var currentTheme: AppTheme = .system
    @Published var colorScheme: ColorScheme = .light
    @Published var accentColor: Color = .blue
    
    // MARK: - 动画配置
    
    let springAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1)
    let smoothAnimation: Animation = .smooth(duration: 0.3, extraBounce: 0.1)
    let snappyAnimation: Animation = .snappy(duration: 0.2, extraBounce: 0.05)
    // 移除 fluidSpring，使用 spring 替代
    let fluidAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.1)
    
    // MARK: - 间距系统
    
    enum Spacing {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - 圆角系统
    
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
        static let circular: CGFloat = .infinity
    }
    
    // MARK: - 阴影系统
    
    enum Shadow {
        static let small = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let large = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let xlarge = ShadowStyle(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - 模糊效果
    
    enum Blur {
        static let light: CGFloat = 4
        static let medium: CGFloat = 8
        static let heavy: CGFloat = 16
        static let ultra: CGFloat = 32
    }
    
    private init() {
        setupThemeObserver()
    }
    
    // MARK: - 主题切换
    
    func switchTheme(_ theme: AppTheme) {
        withAnimation(smoothAnimation) {
            currentTheme = theme
            applyTheme(theme)
        }
    }
    
    func setAccentColor(_ color: Color) {
        withAnimation(springAnimation) {
            accentColor = color
        }
    }
    
    // MARK: - 私有方法
    
    private func setupThemeObserver() {
        // 监听系统主题变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemThemeChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func handleSystemThemeChange() {
        if currentTheme == .system {
            updateSystemTheme()
        }
    }
    
    private func updateSystemTheme() {
        // 根据系统设置更新主题 - 修复 Swift 5.10 兼容性问题
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        colorScheme = isDark ? .dark : .light
    }
    
    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system:
            updateSystemTheme()
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .colorful:
            // 彩色主题特殊处理
            colorScheme = .light
            accentColor = .purple
        }
    }
}

// MARK: - 主题定义

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case colorful = "Colorful"
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        case .colorful: return "paintpalette"
        }
    }
}

// MARK: - 阴影样式

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    func apply() -> some ViewModifier {
        ShadowModifier(style: self)
    }
}

struct ShadowModifier: ViewModifier {
    let style: ShadowStyle
    
    func body(content: Content) -> some View {
        content
            .shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - 现代化颜色系统

extension Color {
    // MARK: 品牌颜色
    static let brandPrimary = Color("BrandPrimary", bundle: .main)
    static let brandSecondary = Color("BrandSecondary", bundle: .main)
    
    // MARK: 动态颜色
    static let adaptiveBackground = Color(NSColor.controlBackgroundColor)
    static let adaptiveForeground = Color(NSColor.labelColor)
    static let adaptiveSecondary = Color(NSColor.secondaryLabelColor)
    static let adaptiveTertiary = Color(NSColor.tertiaryLabelColor)
    
    // MARK: 渐变颜色
    static let gradientStart = Color.blue.opacity(0.8)
    static let gradientEnd = Color.purple.opacity(0.6)
    
    // MARK: 语义颜色
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
}

// MARK: - 现代化字体系统

extension Font {
    // MARK: 标题字体
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    
    // MARK: 正文字体
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    
    // MARK: 辅助字体
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // MARK: 等宽字体
    static let monoLarge = Font.system(size: 17, weight: .regular, design: .monospaced)
    static let monoMedium = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)
}

// MARK: - 现代化动画修饰符

extension View {
    /// 应用弹簧动画
    @MainActor
    func springAnimation() -> some View {
        self.animation(ModernDesignSystem.shared.springAnimation, value: UUID())
    }
    
    /// 应用流畅动画
    @MainActor
    func smoothAnimation() -> some View {
        self.animation(ModernDesignSystem.shared.smoothAnimation, value: UUID())
    }
    
    /// 应用轻快动画
    @MainActor
    func snappyAnimation() -> some View {
        self.animation(ModernDesignSystem.shared.snappyAnimation, value: UUID())
    }
    
    /// 应用流体动画
    @MainActor
    func fluidAnimation() -> some View {
        self.animation(ModernDesignSystem.shared.fluidAnimation, value: UUID())
    }
    
    /// 应用现代化阴影
    func modernShadow(_ style: ShadowStyle) -> some View {
        self.modifier(ShadowModifier(style: style))
    }
    
    /// 应用条件修饰符
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// 应用悬停效果 - 修复 Swift 5.10 兼容性问题
    func customHoverEffect(scale: CGFloat = 1.05, opacity: Double = 0.8) -> some View {
        self.modifier(HoverEffectModifier(scale: scale, opacity: opacity))
    }
}

// MARK: - 悬停效果修饰符

struct HoverEffectModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .opacity(isHovered ? opacity : 1.0)
            .animation(ModernDesignSystem.shared.springAnimation, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: ModernDesignSystem.Spacing.lg) {
        Text("Modern Design System")
            .font(.title1)
            .foregroundColor(.adaptiveForeground)
        
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button(theme.rawValue) {
                    ModernDesignSystem.shared.switchTheme(theme)
                }
                .buttonStyle(.borderedProminent)
                .customHoverEffect() // 使用修复后的方法
            }
        }
        
        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
            .fill(Color.blue.gradient)
            .frame(width: 200, height: 100)
            .modernShadow(ModernDesignSystem.Shadow.medium)
            .customHoverEffect() // 使用修复后的方法
    }
    .padding()
    .frame(width: 400, height: 300)
}