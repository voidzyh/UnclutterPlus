import SwiftUI

/// UnclutterPlus 统一设计系统
/// 定义应用级别的视觉规范，确保 UI 一致性
enum DesignSystem {

    // MARK: - 颜色系统
    enum Colors {
        /// 主色调
        static let accent = Color.accentColor

        /// 背景色
        static let background = Color(nsColor: .windowBackgroundColor)
        static let cardBackground = Color(nsColor: .controlBackgroundColor)

        /// 文字颜色
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary

        /// 状态色
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        /// 遮罩色
        static let overlay = Color.black.opacity(0.1)
        static let overlayLight = Color.black.opacity(0.05)

        /// 分隔线
        static let divider = Color.secondary.opacity(0.2)
    }

    // MARK: - 间距系统
    enum Spacing {
        /// 超小间距 4pt
        static let xs: CGFloat = 4
        /// 小间距 8pt
        static let sm: CGFloat = 8
        /// 中等间距 12pt
        static let md: CGFloat = 12
        /// 大间距 16pt
        static let lg: CGFloat = 16
        /// 超大间距 20pt
        static let xl: CGFloat = 20
        /// 巨大间距 24pt
        static let xxl: CGFloat = 24
    }

    // MARK: - 圆角系统
    enum CornerRadius {
        /// 小圆角 4pt
        static let small: CGFloat = 4
        /// 中等圆角 8pt
        static let medium: CGFloat = 8
        /// 大圆角 12pt
        static let large: CGFloat = 12
        /// 超大圆角 16pt
        static let xlarge: CGFloat = 16
    }

    // MARK: - 阴影系统
    enum Shadow {
        /// 轻微阴影
        static func light() -> some View {
            Color.clear.shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }

        /// 标准阴影
        static func medium() -> some View {
            Color.clear.shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }

        /// 强阴影
        static func strong() -> some View {
            Color.clear.shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        }

        /// 悬浮阴影（悬停时）
        static func elevated() -> some View {
            Color.clear.shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - 字体系统
    enum Typography {
        /// 大标题 20pt
        static let largeTitle = Font.system(size: 20, weight: .bold)
        /// 标题 17pt
        static let title = Font.system(size: 17, weight: .semibold)
        /// 标题2 15pt
        static let title2 = Font.system(size: 15, weight: .semibold)
        /// 标题3 14pt
        static let title3 = Font.system(size: 14, weight: .medium)
        /// 正文 14pt
        static let body = Font.system(size: 14, weight: .regular)
        /// 说明文字 12pt
        static let caption = Font.system(size: 12, weight: .regular)
        /// 小说明文字 10pt
        static let caption2 = Font.system(size: 10, weight: .regular)
    }

    // MARK: - 动画系统
    enum Animation {
        /// 快速动画 0.15s
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        /// 标准动画 0.25s
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        /// 慢速动画 0.35s
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.35)
        /// 弹簧动画
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        /// 柔和弹簧动画
        static let softSpring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
    }

    // MARK: - 尺寸系统
    enum Size {
        /// 图标尺寸
        static let iconSmall: CGFloat = 14
        static let iconMedium: CGFloat = 16
        static let iconLarge: CGFloat = 20
        static let iconXLarge: CGFloat = 24

        /// 按钮尺寸
        static let buttonHeight: CGFloat = 32
        static let buttonHeightLarge: CGFloat = 40

        /// 工具栏高度
        static let toolbarHeight: CGFloat = 44

        /// 卡片最小宽度
        static let cardMinWidth: CGFloat = 100
        /// 卡片最小高度
        static let cardMinHeight: CGFloat = 120
    }
}

// MARK: - 设计系统扩展

extension View {
    /// 应用卡片样式
    func cardStyle(isHovered: Bool = false, isSelected: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? DesignSystem.Colors.accent : (isHovered ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
    }

    /// 应用工具栏样式
    func toolbarStyle() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(.regularMaterial)
    }

    /// 应用搜索框样式
    func searchFieldStyle() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(.regularMaterial)
            )
    }

    /// 应用按钮样式
    func iconButtonStyle(isActive: Bool = false, isHovered: Bool = false) -> some View {
        self
            .foregroundColor(isActive ? .white : (isHovered ? .primary : .secondary))
            .frame(width: DesignSystem.Size.buttonHeight, height: DesignSystem.Size.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(isActive ? DesignSystem.Colors.accent : (isHovered ? DesignSystem.Colors.overlay : Color.clear))
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
    }

    /// 应用标签样式
    func tagStyle(color: Color) -> some View {
        self
            .font(DesignSystem.Typography.caption2)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(color.opacity(0.15))
            )
            .foregroundColor(color)
    }
}
