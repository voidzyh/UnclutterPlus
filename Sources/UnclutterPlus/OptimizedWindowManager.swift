import Cocoa
import SwiftUI

// MARK: - Optimized Window Manager
// 优化版本：职责分离 + 事件驱动 + 性能优化

/// 窗口事件协议
protocol WindowEventObserver: AnyObject {
    func handle(_ event: WindowEvent)
}

/// 窗口事件枚举
enum WindowEvent {
    case willShow
    case didShow
    case willHide
    case didHide
    case lostFocus
    case autoHideTriggered
    case screenChanged
}

/// 窗口状态协议
protocol WindowStateProtocol: ObservableObject {
    var isVisible: Bool { get }
    var isKeyWindow: Bool { get }
    var currentScreen: NSScreen? { get }
}

/// 窗口动画协议
protocol WindowAnimating {
    func animateIn(completion: (() -> Void)?)
    func animateOut(completion: (() -> Void)?)
}

/// 优化的窗口管理器
class OptimizedWindowManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isVisible: Bool = false
    @Published var isKeyWindow: Bool = false

    // MARK: - Properties

    private var window: NSPanel?
    private var hostingView: NSHostingView<MainContentView>?
    private var screenManager: ScreenManager
    private var windowAnimator: WindowAnimator
    private var autoHideManager: AutoHideManager
    private var eventObservers: [WeakWindowEventObserver] = []

    // 状态
    private var isAnimating = false
    private var isDraggingFile = false
    private var isEditingNote = false

    // MARK: - Initialization

    override init() {
        self.screenManager = ScreenManager()
        self.windowAnimator = WindowAnimator()
        self.autoHideManager = AutoHideManager()

        super.init()

        setupWindow()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    func showWindow() {
        guard !isAnimating, let window = window else { return }

        notifyObservers(.willShow)

        isAnimating = true

        // 定位到当前屏幕
        positionWindowOnCurrentScreen()

        window.orderFront(nil)
        window.makeKey()

        // 执行动画
        windowAnimator.animateIn(window: window) { [weak self] in
            guard let self = self else { return }

            self.isAnimating = false
            self.isVisible = true
            self.isKeyWindow = window.isKeyWindow

            self.notifyObservers(.didShow)

            // 激活应用
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hideWindow() {
        guard !isAnimating, let window = window, isVisible else { return }

        notifyObservers(.willHide)

        isAnimating = true

        windowAnimator.animateOut(window: window) { [weak self] in
            guard let self = self else { return }

            self.isAnimating = false
            self.isVisible = false
            self.isKeyWindow = false

            window.orderOut(nil)

            self.notifyObservers(.didHide)
        }
    }

    func toggleWindow() {
        if isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func setDraggingFile(_ dragging: Bool) {
        isDraggingFile = dragging
        if dragging {
            autoHideManager.cancel()
        }
    }

    func setEditingNote(_ editing: Bool) {
        isEditingNote = editing
        if editing {
            autoHideManager.cancel()
        }
    }

    func registerObserver(_ observer: WindowEventObserver) {
        let weakObserver = WeakWindowEventObserver(observer)
        eventObservers.append(weakObserver)
        cleanupObservers()
    }

    func unregisterObserver(_ observer: WindowEventObserver) {
        eventObservers.removeAll { $0.observer === observer }
    }

    // MARK: - Private Methods

    private func setupWindow() {
        let contentView = MainContentView()

        window = KeyboardSupportPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 300),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        guard let window = window else { return }

        hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        configureWindowAppearance(window)
        positionWindowOnCurrentScreen()

        // 初始隐藏
        window.orderOut(nil)
    }

    private func configureWindowAppearance(_ window: NSPanel) {
        window.level = .floating
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = false
        window.worksWhenModal = true
        window.isOpaque = true
        window.backgroundColor = NSColor.controlBackgroundColor
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.title = "window.main.title".localized
        window.acceptsMouseMovedEvents = true
        window.isMovableByWindowBackground = true
    }

    private func setupNotifications() {
        // 应用激活/失活
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // 窗口焦点变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )

        // 屏幕变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func positionWindowOnCurrentScreen() {
        guard let window = window else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screen = screenManager.findScreen(for: mouseLocation)
        let position = screenManager.calculateOptimalPosition(for: window, on: screen)

        window.setFrameOrigin(position)
    }

    private func notifyObservers(_ event: WindowEvent) {
        cleanupObservers()
        eventObservers.forEach { $0.observer?.handle(event) }
    }

    private func cleanupObservers() {
        eventObservers.removeAll { $0.observer == nil }
    }

    // MARK: - Event Handlers

    @objc private func applicationDidResignActive() {
        if !isEditingNote && !isDraggingFile {
            autoHideManager.schedule(delay: 0.3) { [weak self] in
                self?.hideWindow()
            }
        }
        notifyObservers(.lostFocus)
    }

    @objc private func windowDidResignKey() {
        if !isEditingNote && !isDraggingFile {
            autoHideManager.schedule(delay: 0.5) { [weak self] in
                self?.hideWindow()
            }
        }
        isKeyWindow = false
    }

    @objc private func displaysDidChange() {
        notifyObservers(.screenChanged)
        if isVisible {
            positionWindowOnCurrentScreen()
        }
    }
}

// MARK: - Supporting Classes

class ScreenManager {
    private var screenCache: [NSScreen: ScreenInfo] = [:]

    func findScreen(for point: CGPoint) -> NSScreen {
        // 检查缓存
        for (screen, info) in screenCache {
            if info.frame.contains(point) {
                return screen
            }
        }

        // 查找屏幕
        let screen = findScreenInternal(point)

        // 缓存结果
        screenCache[screen] = ScreenInfo(frame: screen.frame)

        return screen
    }

    private func findScreenInternal(_ point: CGPoint) -> NSScreen {
        // 优先检查主屏幕
        if let mainScreen = NSScreen.main {
            let frame = mainScreen.frame
            if point.x >= frame.minX && point.x <= frame.maxX &&
               point.y >= frame.minY && point.y <= frame.maxY {
                return mainScreen
            }
        }

        // 检查所有屏幕
        for screen in NSScreen.screens {
            let frame = screen.frame
            if point.x >= frame.minX && point.x <= frame.maxX &&
               point.y >= frame.minY && point.y <= frame.maxY {
                return screen
            }
        }

        return NSScreen.main ?? NSScreen.screens.first!
    }

    func calculateOptimalPosition(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        let screenFrame = screen.frame
        let windowFrame = window.frame
        let margin: CGFloat = 10

        let maxX = screenFrame.maxX - windowFrame.width - margin
        let minX = screenFrame.minX + margin
        let x = max(minX, min(maxX, screenFrame.midX - (windowFrame.width / 2)))

        // 检查是否有屏幕在上方
        let hasScreenAbove = NSScreen.screens.contains { otherScreen in
            let otherFrame = otherScreen.frame
            return otherFrame != screenFrame &&
                   otherFrame.minY > screenFrame.maxY &&
                   otherFrame.intersects(CGRect(
                    x: screenFrame.minX - 100,
                    y: screenFrame.maxY,
                    width: screenFrame.width + 200,
                    height: 1
                   ))
        }

        let y = hasScreenAbove ?
            screenFrame.maxY - windowFrame.height - margin * 3 :
            screenFrame.maxY - windowFrame.height - margin

        return CGPoint(x: x, y: y)
    }

    func clearCache() {
        screenCache.removeAll()
    }
}

class ScreenInfo {
    let frame: CGRect
    let hasScreenAbove: Bool
    let hasScreenBelow: Bool

    init(frame: CGRect) {
        self.frame = frame
        self.hasScreenAbove = checkScreenPosition(.above, frame: frame)
        self.hasScreenBelow = checkScreenPosition(.below, frame: frame)
    }

    private func checkScreenPosition(_ position: ScreenPosition, frame: CGRect) -> Bool {
        for screen in NSScreen.screens {
            let otherFrame = screen.frame
            if otherFrame == frame { continue }

            switch position {
            case .above:
                return otherFrame.minY > frame.maxY &&
                       otherFrame.intersects(CGRect(
                        x: frame.minX - 100,
                        y: frame.maxY,
                        width: frame.width + 200,
                        height: 1
                       ))
            case .below:
                return otherFrame.maxY < frame.minY &&
                       otherFrame.intersects(CGRect(
                        x: frame.minX - 100,
                        y: frame.minY - 1,
                        width: frame.width + 200,
                        height: 1
                       ))
            }
        }
        return false
    }
}

enum ScreenPosition {
    case above, below
}

class WindowAnimator {
    func animateIn(window: NSWindow, completion: (() -> Void)?) {
        let currentScreen = NSScreen.main
        guard let screen = currentScreen else {
            completion?()
            return
        }

        let screenFrame = screen.frame
        let windowFrame = window.frame

        let startY = screenFrame.maxY + 20
        let endY = screenFrame.maxY - windowFrame.height - 10

        // 设置起始位置
        window.setFrameOrigin(CGPoint(x: windowFrame.origin.x, y: startY))
        window.alphaValue = 0.0

        // 执行动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            context.allowsImplicitAnimation = true

            window.animator().setFrameOrigin(CGPoint(x: windowFrame.origin.x, y: endY))
            window.animator().alphaValue = 1.0
        } completionHandler: {
            completion?()
        }
    }

    func animateOut(window: NSWindow, completion: (() -> Void)?) {
        let currentScreen = NSScreen.main
        guard let screen = currentScreen else {
            completion?()
            return
        }

        let screenFrame = screen.frame
        let windowFrame = window.frame

        let endY = screenFrame.maxY + 30

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1.0)
            context.allowsImplicitAnimation = true

            window.animator().setFrameOrigin(CGPoint(x: windowFrame.origin.x, y: endY))
            window.animator().alphaValue = 0.8
        } completionHandler: {
            window.alphaValue = 1.0
            completion?()
        }
    }
}

class AutoHideManager {
    private var timer: Timer?

    func schedule(delay: TimeInterval, action: @escaping () -> Void) {
        cancel()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            action()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}

class WeakWindowEventObserver {
    weak var observer: WindowEventObserver?

    init(_ observer: WindowEventObserver) {
        self.observer = observer
    }
}
