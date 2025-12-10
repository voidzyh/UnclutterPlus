import SwiftUI

// MARK: - Liquid Glass Button Style
// SwiftUI 2025: Liquid Glass Button Styles

/// Liquid Glass 按钮样式 - SwiftUI 2025 风格
struct LiquidGlassButtonStyle: ButtonStyle {
    let scaleOnPress: Bool

    init(scaleOnPress: Bool = true) {
        self.scaleOnPress = scaleOnPress
    }

    func makeBody(configuration: Configuration) -> some View {
        let foregroundColor = configuration.isPressed ? Color.primary.opacity(0.8) : Color.primary

        return configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .shadow(
                        color: configuration.isPressed ? Color.black.opacity(0.1) : Color.black.opacity(0.05),
                        radius: configuration.isPressed ? 2 : 5,
                        x: 0,
                        y: configuration.isPressed ? 1 : 2
                    )
            )
            .scaleEffect(configuration.isPressed && scaleOnPress ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Liquid Glass 按钮样式扩展
extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }

    static var liquidGlassNoScale: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(scaleOnPress: false)
    }
}

// MARK: - Liquid Glass Background
/// Liquid Glass 背景样式
struct LiquidGlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double

    init(cornerRadius: CGFloat = 20, opacity: Double = 0.1) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(opacity),
                                Color.white.opacity(opacity * 0.5),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(opacity * 2),
                                        Color.white.opacity(opacity),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 20,
                        x: 0,
                        y: 5
                    )
            )
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20, opacity: Double = 0.1) -> some View {
        self.modifier(LiquidGlassBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Liquid Glass Container
/// Liquid Glass 容器
struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .padding(spacing)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 3
                )
        )
    }
}

// MARK: - Glass Effect ID (Namespace-based transitions)
/// Glass Effect ID 修饰符 - 用于 Liquid Glass 过渡动画
struct GlassEffectIDModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: id, in: namespace)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: id)
    }
}

extension View {
    func glassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
        self.modifier(GlassEffectIDModifier(id: id, namespace: namespace))
    }
}

// MARK: - Modern Search Bar
/// 现代化搜索栏
struct ModernSearchBar: View {
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFocused ? .primary : .secondary)

            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .onReceive(NotificationCenter.default.publisher(for: NSTextField.textDidBeginEditingNotification)) { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isFocused = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSTextField.textDidEndEditingNotification)) { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isFocused = false
                    }
                }

            if !text.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.liquidGlassNoScale)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isFocused ? 0.3 : 0.15),
                            Color.white.opacity(isFocused ? 0.2 : 0.08),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isFocused ? 0.5 : 0.3),
                                    Color.white.opacity(isFocused ? 0.3 : 0.15),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: isFocused ? Color.black.opacity(0.1) : Color.black.opacity(0.05),
            radius: isFocused ? 5 : 3,
            x: 0,
            y: isFocused ? 2 : 1
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - Modern Action Button
/// 现代化操作按钮
struct ModernActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let style: LiquidGlassButtonStyle

    init(
        title: String,
        systemImage: String,
        style: LiquidGlassButtonStyle = .liquidGlass,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .buttonStyle(style)
    }
}

// MARK: - Liquid Glass Panel
/// Liquid Glass 面板容器
struct LiquidGlassPanel<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let title = title {
                headerView(title: title)
                Divider()
                    .background(Color.clear.opacity(0.3))
            }

            content
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(cornerRadius: 20, opacity: 0.15)
    }

    @ViewBuilder
    private func headerView(title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            Button("Close") {
                // 关闭操作
            }
            .buttonStyle(.liquidGlassNoScale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}
