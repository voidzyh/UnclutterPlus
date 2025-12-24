import SwiftUI
import AppKit

/// 点击反馈视图 - 在点击位置显示涟漪动画效果
struct ClickFeedbackView: View {
    let location: CGPoint
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 涟漪圆圈
            Circle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: isAnimating ? 40 : 0, height: isAnimating ? 40 : 0)
                .scaleEffect(isAnimating ? 1.5 : 0)
                .opacity(isAnimating ? 0 : 1)
        }
        .frame(width: 60, height: 60)
        .position(x: location.x, y: location.y)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                isAnimating = true
            }
        }
    }
}

/// 菜单栏点击反馈窗口 - 用于显示点击涟漪效果
class MenuBarFeedbackWindow: NSWindow {
    init(location: CGPoint, screen: NSScreen) {
        super.init(
            contentRect: NSRect(origin: location, size: NSSize(width: 60, height: 60)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // 窗口配置
        self.level = .popUpMenu
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true

        // 添加 SwiftUI 视图
        let hostingView = NSHostingView(rootView: ClickFeedbackView(location: .zero))
        hostingView.frame = NSRect(x: 0, y: 0, width: 60, height: 60)
        self.contentView = hostingView

        // 显示窗口
        self.orderFront(nil)

        // 动画结束后自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.close()
        }
    }
}

/// 点击反馈管理器
class ClickFeedbackManager {
    static let shared = ClickFeedbackManager()

    private var feedbackWindow: NSWindow?

    private init() {}

    /// 显示点击反馈
    func showFeedback(at location: CGPoint) {
        // 确保在主线程上操作
        DispatchQueue.main.async { [weak self] in
            self?.showFeedbackInternal(at: location)
        }
    }

    private func showFeedbackInternal(at location: CGPoint) {
        // 关闭之前的反馈窗口
        feedbackWindow?.close()

        // 获取屏幕
        guard let screen = NSScreen.main else { return }

        // 创建新的反馈窗口
        feedbackWindow = MenuBarFeedbackWindow(location: location, screen: screen)
    }
}
