import Cocoa
import SwiftUI
import Combine

// 使用 NSPanel 以更好地支持浮动窗口的键盘输入
class KeyboardSupportPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeKey() {
        super.becomeKey()
        logger.debug("Panel became key window", category: "WindowManager")
        // 确保窗口内容获得焦点
        if let contentView = self.contentView {
            self.makeFirstResponder(contentView)
        }
    }
    
    override func resignKey() {
        super.resignKey()
        logger.debug("Panel resigned key window", category: "WindowManager")
        
        // 检查是否应该自动隐藏（直接使用单例，避免依赖具体 AppDelegate 类型）
        let windowManager = WindowManager.shared
        // 当窗口失去 key 状态时，确保编辑状态被清除，避免阻止自动隐藏
        windowManager.setEditingNote(false)
        windowManager.checkAutoHideOnLostFocus()
    }
}

// 定义自动隐藏的操作类型
enum AutoHideAction {
    case fileOpened          // File opened
    case fileShowInFinder    // Show in Finder
    case clipboardCopied     // Copied to clipboard
    case settingsOpened      // Settings opened
}

class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()

    var window: NSPanel?  // 改为 internal 以便 AppDelegate 可以访问
    private var autoHideTimer: Timer?
    private var isEditingNote: Bool = false
    private var isDraggingFile: Bool = false
    private var hasModalWindow: Bool = false

    /// Esc 键本地监听（面板可见时按下 Esc 隐藏面板）
    private var escKeyMonitor: Any?

    // 自动隐藏倒计时进度（0.0 - 1.0）
    @Published private(set) var autoHideProgress: Double = 0.0
    private var autoHideProgressTimer: Timer?
    private var autoHideStartTime: Date?
    private let autoHideDuration: Double = 0.5  // 与 hideDelay 一致

    // MARK: - 公共访问器
    var isWindowVisible: Bool {
        return window?.isVisible ?? false
    }
    
    /// 面板内容视图工厂（由 App 层注入，避免 Core 层直接实例化 UI 视图）
    var contentFactory: (() -> AnyView)?
    
    override init() {
        super.init()
        // 窗口延迟创建：等待 App 层注入 contentFactory 后调用 prepareWindow()
    }
    
    /// 在 contentFactory 就绪后创建窗口（幂等）
    func prepareWindow() {
        guard window == nil, let content = contentFactory?() else { return }
        setupWindow(content: content)
    }
    
    private func setupWindow(content: AnyView) {
        window = KeyboardSupportPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 520),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        let hostingView = NSHostingView(rootView: content)
        window?.contentView = hostingView
        window?.level = .floating
        window?.isFloatingPanel = true  // 设置为浮动面板
        window?.hidesOnDeactivate = false  // 手动控制失去焦点时的行为
        window?.becomesKeyOnlyIfNeeded = false  // 总是可以成为 key window
        window?.worksWhenModal = true  // 在模态窗口时也工作
        
        // 现代浮动卡片外观：隐藏标题栏与交通灯按钮、圆角、透明底
        window?.titleVisibility = .hidden
        window?.titlebarAppearsTransparent = true
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.hasShadow = true
        window?.ignoresMouseEvents = false
        window?.acceptsMouseMovedEvents = true
        
        // 圆角裁剪
        window?.contentView?.wantsLayer = true
        window?.contentView?.layer?.cornerRadius = ModernDesignSystem.Radius.lg
        window?.contentView?.layer?.masksToBounds = true
        
        logger.debug("Window created successfully", category: "WindowManager")
        
        // 设置窗口初始位置在屏幕顶部中央
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let windowFrame = window?.frame ?? NSRect.zero
            let x = (screenFrame.width - windowFrame.width) / 2
            let y = screenFrame.maxY - windowFrame.height
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 初始隐藏窗口
        window?.orderOut(nil)

        // 监听应用和窗口的焦点变化，增强自动隐藏的可靠性
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAutoHideOnLostFocus()
        }

        if let window = window {
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                // 窗口丢失 key 时，同样尝试自动隐藏
                self?.setEditingNote(false)
                self?.checkAutoHideOnLostFocus()
            }
        }

        setupEscapeKeyMonitor()
    }

    /// 面板可见时按下 Esc 隐藏面板（键盘优先操作流，P0 收尾项）
    private func setupEscapeKeyMonitor() {
        guard escKeyMonitor == nil else { return }

        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // keyCode 53 = Esc；仅在面板可见时消费事件
            if event.keyCode == 53, self.isWindowVisible {
                logger.debug("Esc 键隐藏面板", category: "WindowManager")
                self.hideWindow()
                return nil
            }
            return event
        }
    }
    
    func showWindow() {
        if window == nil {
            prepareWindow()
        }
        guard let window = window else {
            logger.debug("Error: Window is nil", category: "WindowManager")
            return
        }

        logger.debug("Showing window - current visibility: \(window.isVisible)", category: "WindowManager")

        // 停止自动隐藏进度
        stopAutoHideProgress()

        if !window.isVisible {
            // 在显示前，先定位到鼠标当前所在的屏幕
            positionWindowOnCurrentScreen()

            // 先让窗口显示，但不激活
            window.orderFront(nil)

            // 执行动画，并在动画完成后激活窗口
            // 在 showWindow 方法的动画完成回调中
            animateWindowIn {
                window.makeKey()
                NSApp.activate(ignoringOtherApps: true)

                // floating窗口需要更多时间和特殊处理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 强制激活应用程序和窗口
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKey()

                    if let hostingView = window.contentView as? NSHostingView<AnyView> {
                        window.makeFirstResponder(hostingView)
                        logger.debug("Floating window setup complete", category: "WindowManager")
                    }
                }

                logger.debug("Window is now key and active", category: "WindowManager")
            }
            logger.debug("Window should now be visible", category: "WindowManager")
        } else {
            // 已可见时不再隐藏（幂等显示），仅确保获得焦点
            logger.debug("Window is already visible, bringing to front", category: "WindowManager")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    /// 切换面板显示状态（用于点击/快捷键等"切换"语义的场景）
    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    func hideWindow() {
        guard let window = window else { return }
        
        animateWindowOut {
            window.orderOut(nil)
        }
    }
    
    private func animateWindowIn(completion: (() -> Void)? = nil) {
        guard let window = window else { return }
        
        let currentScreen = findScreenForPoint(NSEvent.mouseLocation) ?? NSScreen.main
        guard let screen = currentScreen else { return }
        
        let screenFrame = screen.frame
        let windowFrame = window.frame
        
        // 动画起点：屏幕上方边缘外
        let startY = screenFrame.maxY + 20
        // 最终位置：考虑多屏布局
        let margin: CGFloat = 10
        let allScreens = NSScreen.screens
        let hasScreenAbove = allScreens.contains { otherScreen in
            let otherFrame = otherScreen.frame
            return otherFrame != screenFrame && 
                   otherFrame.minY > screenFrame.maxY &&
                   otherFrame.intersects(CGRect(x: screenFrame.minX - 100, 
                                               y: screenFrame.maxY, 
                                               width: screenFrame.width + 200, 
                                               height: 1))
        }
        
        let endY = hasScreenAbove ? 
            screenFrame.maxY - windowFrame.height - margin * 3 :
            screenFrame.maxY - windowFrame.height - margin
        
        // 设置起始位置和透明度
        window.setFrameOrigin(NSPoint(x: windowFrame.origin.x, y: startY))
        window.alphaValue = 0.0
        
        // 执行流畅的滑入动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25  // 稍微快一点，更响应
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)  // 自定义贝塞尔曲线，更自然
            context.allowsImplicitAnimation = true
            
            window.animator().setFrameOrigin(NSPoint(x: windowFrame.origin.x, y: endY))
            window.animator().alphaValue = 1.0
        } completionHandler: {
            completion?()
        }
    }
    
    private func animateWindowOut(completion: @escaping () -> Void) {
        guard let window = window else {
            completion()
            return
        }
        
        let currentScreen = findScreenForPoint(NSEvent.mouseLocation) ?? NSScreen.main
        guard let screen = currentScreen else {
            completion()
            return
        }
        
        let screenFrame = screen.frame
        let windowFrame = window.frame
        
        // 滑出目标：屏幕上方边缘外，比滑入时更远一些
        let endY = screenFrame.maxY + 30
        
        // 执行快速且流畅的滑出动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18  // 比滑入稍快，感觉更响应
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1.0)  // 快速开始，平滑结束
            context.allowsImplicitAnimation = true
            
            window.animator().setFrameOrigin(NSPoint(x: windowFrame.origin.x, y: endY))
            window.animator().alphaValue = 0.8  // 淡出但不完全透明，保持可见性直到隐藏
        } completionHandler: {
            // 确保窗口完全隐藏后再回调
            window.alphaValue = 1.0  // 重置透明度为下次显示做准备
            completion()
        }
    }
    
    private func positionWindowOnCurrentScreen() {
        guard let window = window else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = findScreenForPoint(mouseLocation) ?? NSScreen.main
        guard let screen = currentScreen else { return }
        
        let screenFrame = screen.frame
        let windowFrame = window.frame
        
        // 分析多屏布局：检查是否有上下屏幕关系
        let allScreens = NSScreen.screens
        let hasScreenAbove = allScreens.contains { otherScreen in
            let otherFrame = otherScreen.frame
            // 检查是否有屏幕在当前屏幕上方（Y坐标更大）
            return otherFrame != screenFrame && 
                   otherFrame.minY > screenFrame.maxY &&
                   otherFrame.intersects(CGRect(x: screenFrame.minX - 100, 
                                               y: screenFrame.maxY, 
                                               width: screenFrame.width + 200, 
                                               height: 1))
        }
        
        let hasScreenBelow = allScreens.contains { otherScreen in
            let otherFrame = otherScreen.frame
            // 检查是否有屏幕在当前屏幕下方（Y坐标更小）
            return otherFrame != screenFrame && 
                   otherFrame.maxY < screenFrame.minY &&
                   otherFrame.intersects(CGRect(x: screenFrame.minX - 100, 
                                               y: screenFrame.minY - 1, 
                                               width: screenFrame.width + 200, 
                                               height: 1))
        }
        
        // 计算窗口位置
        let margin: CGFloat = 10
        let maxX = screenFrame.maxX - windowFrame.width - margin
        let minX = screenFrame.minX + margin
        let x = max(minX, min(maxX, screenFrame.midX - (windowFrame.width / 2)))
        
        // 根据屏幕布局调整Y位置
        let y: CGFloat
        if hasScreenAbove {
            // 如果上方有屏幕，窗口从当前屏幕顶部向下一些显示，避免遮挡上方屏幕
            y = screenFrame.maxY - windowFrame.height - margin * 3
            logger.debug("多屏布局：上方有屏幕，调整窗口位置避免遮挡", category: "WindowManager")
        } else {
            // 标准位置：紧贴屏幕顶部
            y = screenFrame.maxY - windowFrame.height - margin
        }
        
        let newOrigin = NSPoint(x: x, y: y)
        window.setFrameOrigin(newOrigin)
        
        logger.debug("窗口定位: \(newOrigin)", category: "WindowManager")
        logger.debug("屏幕信息: \(screenFrame)", category: "WindowManager")
        logger.debug("布局分析: 上方有屏幕=\(hasScreenAbove), 下方有屏幕=\(hasScreenBelow)", category: "WindowManager")
    }
    
    private func findScreenForPoint(_ point: CGPoint) -> NSScreen? {
        // 先检查主屏幕
        if let mainScreen = NSScreen.main {
            let frame = mainScreen.frame
            if point.x >= frame.minX && point.x <= frame.maxX &&
               point.y >= frame.minY && point.y <= frame.maxY {
                return mainScreen
            }
        }
        
        // 再检查其他屏幕
        for screen in NSScreen.screens {
            let frame = screen.frame
            if point.x >= frame.minX && point.x <= frame.maxX &&
               point.y >= frame.minY && point.y <= frame.maxY {
                return screen
            }
        }
        
        return NSScreen.main
    }
    
    // MARK: - Auto Hide Management
    
    func hideWindowAfterAction(_ action: AutoHideAction, delay: TimeInterval = 0.5) {
        let config = ConfigurationManager.shared
        
        // 检查是否启用了自动隐藏
        guard config.autoHideAfterAction else { return }
        
        // 检查该操作是否应该触发自动隐藏
        guard shouldAutoHide(after: action) else { return }
        
        // 取消之前的定时器
        autoHideTimer?.invalidate()
        
        // 设置延迟隐藏
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hideWindow()
        }
    }
    
    private func shouldAutoHide(after action: AutoHideAction) -> Bool {
        switch action {
        case .fileOpened, .fileShowInFinder, .clipboardCopied:
            return true
        case .settingsOpened:
            return false // 设置窗口打开时不自动隐藏
        }
    }
    
    func checkAutoHideOnLostFocus() {
        let config = ConfigurationManager.shared

        // 检查是否启用了失去焦点时自动隐藏
        guard config.hideOnLostFocus else {
            // 如果未启用，确保清除进度
            autoHideProgress = 0.0
            autoHideProgressTimer?.invalidate()
            return
        }

        // 检查是否有阻止自动隐藏的条件
        guard !shouldPreventAutoHide() else {
            autoHideProgress = 0.0
            autoHideProgressTimer?.invalidate()
            return
        }

        // 延迟检查，给用户一点时间，使用配置的延迟时间
        let delay = config.hideDelay

        // 启动倒计时进度
        startAutoHideProgress(duration: delay)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            // 停止进度计时器
            self.stopAutoHideProgress()

            // 检查窗口是否仍然不是 key window
            if let window = self.window, !window.isKeyWindow {
                // 再次检查是否有阻止自动隐藏的条件
                if !self.shouldPreventAutoHide() {
                    logger.debug("Auto-hiding window due to lost focus", category: "WindowManager")
                    self.hideWindow()
                } else {
                    logger.debug("Preventing auto-hide due to active operations", category: "WindowManager")
                }
            }
        }
    }

    /// 启动自动隐藏倒计时进度
    private func startAutoHideProgress(duration: TimeInterval) {
        autoHideStartTime = Date()
        autoHideProgress = 0.0

        // 每 0.05 秒更新一次进度（20fps）
        autoHideProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.autoHideStartTime else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)

            self.autoHideProgress = progress
        }
    }

    /// 停止自动隐藏倒计时进度
    private func stopAutoHideProgress() {
        autoHideProgressTimer?.invalidate()
        autoHideProgressTimer = nil
        autoHideProgress = 0.0
        autoHideStartTime = nil
    }
    
    private func shouldPreventAutoHide() -> Bool {
        // 检查是否有正在进行的操作阻止自动隐藏
        let shouldPrevent = isEditingNote || isDraggingFile || hasModalWindow
        
        if shouldPrevent {
            logger.debug("Preventing auto-hide: editingNote=\(isEditingNote), draggingFile=\(isDraggingFile), hasModalWindow=\(hasModalWindow)", category: "WindowManager")
        }
        
        return shouldPrevent
    }
    
    func setEditingNote(_ editing: Bool) {
        isEditingNote = editing
        if editing {
            // 正在编辑时取消自动隐藏定时器
            autoHideTimer?.invalidate()
        }
    }
    
    func setDraggingFile(_ dragging: Bool) {
        isDraggingFile = dragging
        if dragging {
            // 拖拽时取消自动隐藏定时器
            autoHideTimer?.invalidate()
        }
    }
    
    func setModalWindow(_ hasModal: Bool) {
        hasModalWindow = hasModal
        if hasModal {
            // 有模态窗口时取消自动隐藏定时器
            autoHideTimer?.invalidate()
        }
    }
    
    func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil

        // 同时停止倒计时进度
        stopAutoHideProgress()
    }
}