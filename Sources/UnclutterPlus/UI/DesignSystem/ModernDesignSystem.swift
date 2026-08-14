import SwiftUI

// MARK: - 现代化设计系统 (v2.0)

/// 现代化设计系统 - 提供统一的视觉语言、动画和交互规范
/// Design Philosophy: "Crystal & Canvas"
///
/// 纯常量与静态映射的命名空间，不含实例状态；
/// `shared` 仅为兼容历史调用点（`ModernDesignSystem.shared.color(_:)`）保留。
final class ModernDesignSystem {
    /// 兼容层：语义颜色的实例访问入口，内部为纯静态映射
    static let shared = ModernDesignSystem()

    private init() {}

    // MARK: - 动画系统 (Motion, spec §5)

    enum Motion {
        /// 微交互 (Hover, Click) - spring(response: 0.3, damping: 0.7)
        static let snap = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
        /// 平滑 - 用于布局变化和页面切换
        static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.15)
    }

    // MARK: - 间距系统 (Spacing, spec §3)

    enum Spacing {
        /// 4px - 紧凑分组
        static let xs: CGFloat = 4
        /// 8px - 组件内边距
        static let sm: CGFloat = 8
        /// 16px - 卡片内边距
        static let md: CGFloat = 16
        /// 24px - 区块分隔
        static let lg: CGFloat = 24
        /// 32px - 主要布局分割
        static let xl: CGFloat = 32
        /// 40px - 超大布局间距（沿 scale 顺延）
        static let xxl: CGFloat = 40

        /// 侧边栏宽度 (collapsed/icon-only)
        static let sidebarWidth: CGFloat = 68
    }

    // MARK: - 圆角系统 (Radius)

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        /// 10px - 主外壳/小组件容器圆角
        static let shell: CGFloat = 10
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - 颜色系统 (Semantic, spec §2)

    /// 获取语义颜色（纯静态映射，无主题状态）
    func color(_ token: ColorToken) -> Color {
        return token.color
    }

    /// bg.floating - 工具栏 / Popover 浮层材质
    static let bgFloating: Material = .regular
}

// MARK: - 颜色令牌 (Color Tokens, spec §2)

enum ColorToken {
    case bgCanvas
    case bgSurface
    case bgSurfaceHover
    case textPrimary
    case textSecondary
    case textTertiary
    case accentMain
    case accentSoft
    case strokeAdaptive
    case borderSubtle
    case borderFocus

    var color: Color {
        switch self {
        case .bgCanvas:
            // bg.canvas - 主背景
            return Color(nsColor: .windowBackgroundColor)
        case .bgSurface:
            // bg.surface - 卡片/弹层，动态系统色，深浅色自适应
            return Color(nsColor: .controlBackgroundColor)
        case .bgSurfaceHover:
            return Color.primary.opacity(0.05)
        case .textPrimary:
            // text.primary - 标题/主要数据
            return Color.primary
        case .textSecondary:
            // text.secondary - 元数据/副标题
            return Color.secondary
        case .textTertiary:
            return Color(nsColor: .tertiaryLabelColor)
        case .accentMain:
            // accent.main - 主操作色
            return Color.accentColor
        case .accentSoft:
            // accent.soft - 悬停/选中底色：light 10% / dark 20%
            return Color(nsColor: NSColor(name: nil) { appearance in
                NSColor.systemBlue.withAlphaComponent(appearance.isDarkAppearance ? 0.2 : 0.1)
            })
        case .strokeAdaptive:
            // 自适应描边：light 下黑 8% / dark 下白 15%，避免"双盲描边"
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDarkAppearance
                    ? NSColor.white.withAlphaComponent(0.15)
                    : NSColor.black.withAlphaComponent(0.08)
            })
        case .borderSubtle:
            return Color.primary.opacity(0.1)
        case .borderFocus:
            return Color.accentColor.opacity(0.5)
        }
    }
}

private extension NSAppearance {
    /// 当前外观是否为深色模式
    var isDarkAppearance: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - View Modifiers

extension View {
    /// 玻璃拟态背景 (Crystal Effect)
    func glassEffect(_ material: Material = .ultraThinMaterial, cornerRadius: CGFloat = ModernDesignSystem.Radius.lg) -> some View {
        self.background(material)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ModernDesignSystem.shared.color(.strokeAdaptive), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    /// 卡片样式 (Canvas Card, spec §5)
    /// bg.surface 背景 + 1px 自适应描边 + 投影；hover 时 scale(1.02)、投影半径加大
    /// - Parameter hover: 外部驱动的悬停态；内部同时自带 hover 检测
    func cardStyle(hover: Bool = false) -> some View {
        self.modifier(CardStyleModifier(externalHover: hover))
    }

    /// 悬停缩放效果
    func hoverScaleEffect(scale: CGFloat = 1.02) -> some View {
        self.modifier(HoverScaleModifier(scale: scale))
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

/// 卡片样式修饰：自带 hover 检测，externalHover 供调用方外部驱动
struct CardStyleModifier: ViewModifier {
    var externalHover: Bool = false
    @State private var isHovered = false

    /// 外部驱动与自身 hover 任一成立即视为高亮
    private var highlighted: Bool { externalHover || isHovered }

    func body(content: Content) -> some View {
        content
            .background(ModernDesignSystem.shared.color(.bgSurface))
            .cornerRadius(ModernDesignSystem.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.md)
                    .stroke(ModernDesignSystem.shared.color(.strokeAdaptive), lineWidth: 1)
            )
            .scaleEffect(highlighted ? 1.02 : 1.0)
            .shadow(color: Color.black.opacity(0.1), radius: highlighted ? 12 : 8, x: 0, y: 4)
            .animation(ModernDesignSystem.Motion.snap, value: highlighted)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Typography (spec §3)

extension Font {
    /// 圆体标题：基于系统 .title 动态字级，仅替换为圆体设计，不遮蔽系统动态字级
    static let roundedTitle = Font.system(.title, design: .rounded, weight: .semibold)
}
