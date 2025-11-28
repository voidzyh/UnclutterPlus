import SwiftUI
import Combine

// MARK: - 现代化动画库

/// 现代化动画系统 - 提供丰富的动画和过渡效果
enum ModernAnimations {
    
    // MARK: - 基础动画
    
    /// 弹簧动画 - 用于交互响应
    static var spring: Animation {
        .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1)
    }
    
    /// 流畅动画 - 用于平滑过渡
    static var smooth: Animation {
        .smooth(duration: 0.3, extraBounce: 0.1)
    }
    
    /// 轻快动画 - 用于快速响应
    static var snappy: Animation {
        .snappy(duration: 0.2, extraBounce: 0.05)
    }
    
    /// 流体动画 - 用于自然运动 - 修复 Swift 5.10 兼容性
    static var fluid: Animation {
        .spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.1)
    }
    
    /// 弹性动画 - 用于弹跳效果
    static var bouncy: Animation {
        .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.2)
    }
    
    /// 温和动画 - 用于微妙变化
    static var gentle: Animation {
        .easeInOut(duration: 0.4)
    }
    
    // MARK: - 高级动画
    
    /// 卡片进入动画
    static var cardEnter: Animation {
        .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.1)
    }
    
    /// 卡片退出动画
    static var cardExit: Animation {
        .easeIn(duration: 0.2)
    }
    
    /// 模态出现动画
    static var modalAppear: Animation {
        .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)
    }
    
    /// 模态消失动画
    static var modalDisappear: Animation {
        .easeOut(duration: 0.25)
    }
    
    /// 列表项动画
    static var listItem: Animation {
        .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)
    }
    
    /// 标签切换动画
    static var tabSwitch: Animation {
        .spring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.05)
    }
    
    /// 内容切换动画
    static var contentSwitch: Animation {
        .smooth(duration: 0.35, extraBounce: 0.05)
    }
    
    // MARK: - 特殊效果动画
    
    /// 脉冲动画
    static func pulse(duration: Double = 1.0) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
    
    /// 呼吸动画
    static func breathe(duration: Double = 2.0) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
    
    /// 旋转动画
    static func rotate(duration: Double = 1.0) -> Animation {
        .linear(duration: duration).repeatForever(autoreverses: false)
    }
    
    /// 弹跳动画
    static func bounce(height: CGFloat = 10) -> Animation {
        .interpolatingSpring(stiffness: 300, damping: 15)
    }
    
    /// 抖动动画
    static func shake(intensity: CGFloat = 5) -> Animation {
        .easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)
    }
}

// MARK: - 现代化过渡效果

extension AnyTransition {
    
    /// 卡片进入过渡
    static var cardEnter: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.2).combined(with: .opacity)
        )
    }
    
    /// 卡片退出过渡
    static var cardExit: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 1.1).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }
    
    /// 模态出现过渡
    static var modalAppear: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    /// 模态消失过渡
    static var modalDisappear: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    /// 列表项进入过渡
    static var listItemEnter: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
    
    /// 列表项退出过渡
    static var listItemExit: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    /// 标签切换过渡
    static var tabSwitch: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    /// 内容切换过渡
    static var contentSwitch: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 1.05).combined(with: .opacity)
        )
    }
    
    /// 滑动过渡
    static func slide(from edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .move(edge: edge).combined(with: .opacity)
        )
    }
    
    /// 缩放过渡
    static func scale(from: CGFloat, to: CGFloat) -> AnyTransition {
        .asymmetric(
            insertion: .scale(scale: from).combined(with: .opacity),
            removal: .scale(scale: to).combined(with: .opacity)
        )
    }
    
    /// 旋转过渡
    static func rotate(angle: Double = 90) -> AnyTransition {
        .modifier(
            active: RotationModifier(angle: angle),
            identity: RotationModifier(angle: 0)
        )
    }
    
    /// 模糊过渡
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 10),
            identity: BlurModifier(radius: 0)
        )
    }
    
    /// 亮度过渡
    static var brightness: AnyTransition {
        .modifier(
            active: BrightnessModifier(brightness: -0.3),
            identity: BrightnessModifier(brightness: 0)
        )
    }
}

// MARK: - 动画修饰符

struct RotationModifier: ViewModifier {
    let angle: Double
    
    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(angle))
    }
}

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

struct BrightnessModifier: ViewModifier {
    let brightness: Double
    
    func body(content: Content) -> some View {
        content.brightness(brightness)
    }
}

// MARK: - 动画辅助视图

/// 动画容器视图
struct AnimatedContainer<Content: View>: View {
    let animation: Animation
    let transition: AnyTransition?
    let content: Content
    @State private var isVisible = false
    
    init(
        animation: Animation = ModernAnimations.spring,
        transition: AnyTransition? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.animation = animation
        self.transition = transition
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isVisible {
                content
                    .transition(transition ?? .identity)
            }
        }
        .animation(animation, value: isVisible)
        .onAppear {
            withAnimation(animation) {
                isVisible = true
            }
        }
    }
}

/// 脉冲动画视图
struct PulseAnimationView<Content: View>: View {
    let content: Content
    let duration: Double
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    init(duration: Double = 1.0, @ViewBuilder content: () -> Content) {
        self.duration = duration
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(ModernAnimations.pulse(duration: duration)) {
                    scale = 1.1
                    opacity = 0.7
                }
            }
    }
}

/// 呼吸动画视图
struct BreatheAnimationView<Content: View>: View {
    let content: Content
    let duration: Double
    @State private var scale: CGFloat = 1.0
    
    init(duration: Double = 2.0, @ViewBuilder content: () -> Content) {
        self.duration = duration
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(ModernAnimations.breathe(duration: duration)) {
                    scale = 1.05
                }
            }
    }
}

/// 旋转动画视图
struct RotateAnimationView<Content: View>: View {
    let content: Content
    let duration: Double
    @State private var rotation: Double = 0
    
    init(duration: Double = 1.0, @ViewBuilder content: () -> Content) {
        self.duration = duration
        self.content = content()
    }
    
    var body: some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(ModernAnimations.rotate(duration: duration)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - 动画扩展 - 修复 Swift 5.10 兼容性问题

extension View {
    /// 应用脉冲动画
    func pulseAnimation(duration: Double = 1.0) -> some View {
        self.overlay(
            PulseAnimationView(duration: duration) { self }
        )
    }
    
    /// 应用呼吸动画
    func breatheAnimation(duration: Double = 2.0) -> some View {
        self.overlay(
            BreatheAnimationView(duration: duration) { self }
        )
    }
    
    /// 应用旋转动画
    func rotateAnimation(duration: Double = 1.0) -> some View {
        self.overlay(
            RotateAnimationView(duration: duration) { self }
        )
    }
    
    /// 应用弹跳动画
    func bounceAnimation(height: CGFloat = 10) -> some View {
        self.animation(ModernAnimations.bounce(height: height), value: height)
    }
    
    /// 应用抖动动画
    func shakeAnimation(intensity: CGFloat = 5) -> some View {
        self.animation(ModernAnimations.shake(intensity: intensity), value: intensity)
    }
    
    /// 应用卡片进入动画
    func cardEnterAnimation() -> some View {
        self.transition(.cardEnter)
            .animation(ModernAnimations.cardEnter, value: "cardEnter")
    }
    
    /// 应用卡片退出动画
    func cardExitAnimation() -> some View {
        self.transition(.cardExit)
            .animation(ModernAnimations.cardExit, value: "cardExit")
    }
    
    /// 应用模态出现动画
    func modalAppearAnimation() -> some View {
        self.transition(.modalAppear)
            .animation(ModernAnimations.modalAppear, value: "modalAppear")
    }
    
    /// 应用模态消失动画
    func modalDisappearAnimation() -> some View {
        self.transition(.modalDisappear)
            .animation(ModernAnimations.modalDisappear, value: "modalDisappear")
    }
    
    /// 应用列表项动画
    func listItemAnimation() -> some View {
        self.transition(.listItemEnter)
            .animation(ModernAnimations.listItem, value: "listItem")
    }
    
    /// 应用标签切换动画
    func tabSwitchAnimation() -> some View {
        self.transition(.tabSwitch)
            .animation(ModernAnimations.tabSwitch, value: "tabSwitch")
    }
    
    /// 应用内容切换动画
    func contentSwitchAnimation() -> some View {
        self.transition(.contentSwitch)
            .animation(ModernAnimations.contentSwitch, value: "contentSwitch")
    }
    
    /// 应用滑动动画
    func slideAnimation(from edge: Edge) -> some View {
        self.transition(.slide(from: edge))
            .animation(ModernAnimations.smooth, value: edge)
    }
    
    /// 应用缩放动画
    func scaleAnimation(from: CGFloat, to: CGFloat) -> some View {
        self.transition(.scale(from: from, to: to))
            .animation(ModernAnimations.spring, value: from)
    }
    
    /// 应用旋转动画
    func rotateAnimation(angle: Double = 90) -> some View {
        self.transition(.rotate(angle: angle))
            .animation(ModernAnimations.spring, value: angle)
    }
    
    /// 应用模糊动画
    func blurAnimation() -> some View {
        self.transition(.blur)
            .animation(ModernAnimations.gentle, value: "blur")
    }
    
    /// 应用亮度动画
    func brightnessAnimation() -> some View {
        self.transition(.brightness)
            .animation(ModernAnimations.gentle, value: "brightness")
    }
}

// MARK: - 动画工具类

@MainActor
final class AnimationManager: ObservableObject {
    static let shared = AnimationManager()
    
    @Published var isAnimationEnabled = true
    @Published var animationSpeed: Double = 1.0
    
    private init() {
        loadSettings()
    }
    
    func disableAnimations() {
        isAnimationEnabled = false
        saveSettings()
    }
    
    func enableAnimations() {
        isAnimationEnabled = true
        saveSettings()
    }
    
    func setAnimationSpeed(_ speed: Double) {
        animationSpeed = max(0.1, min(2.0, speed))
        saveSettings()
    }
    
    func applyAnimation<T: View>(_ view: T, animation: Animation) -> some View {
        guard isAnimationEnabled else {
            return AnyView(view)
        }
        
        let adjustedAnimation = animation.speed(animationSpeed)
        return AnyView(view.animation(adjustedAnimation, value: isAnimationEnabled))
    }
    
    private func loadSettings() {
        // 从用户设置加载
        isAnimationEnabled = UserDefaults.standard.bool(forKey: "animationsEnabled")
        animationSpeed = UserDefaults.standard.double(forKey: "animationSpeed")
        
        if animationSpeed == 0 {
            animationSpeed = 1.0
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isAnimationEnabled, forKey: "animationsEnabled")
        UserDefaults.standard.set(animationSpeed, forKey: "animationSpeed")
    }
}



// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            Button("Optimize Memory") {
                PerformanceOptimizer.shared.optimizeMemory()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Clear Caches") {
                PerformanceOptimizer.shared.clearAllCaches()
            }
            .buttonStyle(.bordered)
        }
    }
    .padding()
}