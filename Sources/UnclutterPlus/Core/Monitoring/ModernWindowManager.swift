import Foundation
import AppKit
import SwiftUI
import Combine

/// 现代化窗口管理器 - 优化的窗口显示和手势识别
@MainActor
final class ModernWindowManager: ObservableObject {
    static let shared = ModernWindowManager()
    
    // MARK: - 发布属性
    
    @Published var isWindowVisible = false
    @Published var windowPosition: CGPoint = .zero
    @Published var windowSize: CGSize = CGSize(width: 900, height: 600)
    @Published var currentScreen: NSScreen?
    @Published var isAnimating = false
    
    // 手势状态
    @Published var isEdgeTracking = false
    @Published var gestureState: GestureState = .idle
    
    // MARK: - 私有属性
    
    private var window: ModernFloatingWindow?
    private var edgeTracker: ModernEdgeMouseTracker?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // 动画配置
    private let animationDuration: TimeInterval = 0.3
    private let springDamping: CGFloat = 0.8
    private let springVelocity: CGFloat = 0.5
    
    // 窗口配置
    private let windowPadding: CGFloat = 20
    private let minWindowWidth: CGFloat = 600
    private let minWindowHeight: CGFloat = 400
    private let maxWindowWidth: CGFloat = 1400
    private let maxWindowHeight: CGFloat = 900
    
    // 边缘检测配置
    private let edgeThreshold: CGFloat = 5.0
    private let gestureThreshold: CGFloat = 10.0
    
    // MARK: - 初始化
    
    private init() {
        setupWindow()
        setupEdgeTracking()
        setupNotifications()
        setupBindings()
    }
    
    // MARK: - 公共方法
    
    func showWindow() {
        guard !isAnimating else { return }
        
        isAnimating = true
        
        // 更新当前屏幕
        updateCurrentScreen()
        
        // 计算窗口位置
        let targetPosition = calculateOptimalWindowPosition()
        
        // 创建或更新窗口
        if window == nil {
            createWindow(at: targetPosition)
        } else {
            updateWindowPosition(targetPosition)
        }
        
        // 显示动画
        animateWindowIn()
    }
    
    func hideWindow() {
        guard !isAnimating else { return }
        
        isAnimating = true
        animateWindowOut()
    }
    
    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    func updateWindowSize(_ size: CGSize) {
        let clampedSize = clampWindowSize(size)
        windowSize = clampedSize
        
        if let window = window {
            window.setContentSize(clampedSize)
            let newPosition = calculateOptimalWindowPosition()
            window.setFrameOrigin(NSPoint(x: newPosition.x, y: newPosition.y))
        }
    }
    
    func setWindowPosition(_ position: CGPoint) {
        windowPosition = position
        
        if let window = window {
            window.setFrameOrigin(NSPoint(x: position.x, y: position.y))
        }
    }
    
    func enableEdgeTracking() {
        edgeTracker?.startTracking()
        isEdgeTracking = true
    }
    
    func disableEdgeTracking() {
        edgeTracker?.stopTracking()
        isEdgeTracking = false
    }
    
    // MARK: - 私有方法
    
    private func setupWindow() {
        // 初始化窗口配置
        updateCurrentScreen()
        
        if currentScreen != nil {
            windowPosition = calculateOptimalWindowPosition()
        }
    }
    
    private func setupEdgeTracking() {
        edgeTracker = ModernEdgeMouseTracker(
            edgeThreshold: edgeThreshold,
            gestureThreshold: gestureThreshold
        )
        
        edgeTracker?.onEdgeTriggered = { [weak self] direction in
            self?.handleEdgeTrigger(direction: direction)
        }
        
        edgeTracker?.onGestureDetected = { [weak self] gesture in
            self?.handleGesture(gesture: gesture)
        }
    }
    
    private func setupNotifications() {
        // 监听屏幕配置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // 监听应用激活状态
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }
    
    private func setupBindings() {
        // 监听窗口可见性变化
        $isWindowVisible
            .sink { [weak self] visible in
                if visible {
                    self?.window?.orderFront(nil)
                } else {
                    self?.window?.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 窗口创建和管理
    
    private func createWindow(at position: CGPoint) {
        let window = ModernFloatingWindow(
            contentRect: NSRect(x: position.x, y: position.y, width: windowSize.width, height: windowSize.height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.center()
        
        // 设置窗口内容
        let contentView = ModernMainContentView()
        window.contentView = NSHostingView(rootView: contentView)
        
        // 设置窗口级别和属性
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // 添加事件监听
        setupWindowEventMonitors(for: window)
        
        self.window = window
    }
    
    private func updateWindowPosition(_ position: CGPoint) {
        window?.setFrameOrigin(NSPoint(x: position.x, y: position.y))
    }
    
    private func setupWindowEventMonitors(for window: ModernFloatingWindow) {
        // 监听窗口失去焦点事件
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self,
                  let window = self.window else { return event }
            
            let location = event.locationInWindow
            let windowFrame = window.frame
            
            // 检查点击是否在窗口外部
            if !windowFrame.contains(location) {
                // 延迟隐藏，允许点击事件传递
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.isWindowVisible {
                        self.hideWindow()
                    }
                }
            }
            
            return event
        }
        
        // 监听全局键盘事件
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            // ESC 键隐藏窗口
            if event.keyCode == 53 { // ESC key
                if self.isWindowVisible {
                    self.hideWindow()
                }
            }
        }
    }
    
    // MARK: - 动画方法
    
    private func animateWindowIn() {
        guard let window = window else {
            isAnimating = false
            return
        }
        
        // 初始状态
        window.alphaValue = 0.0
        // 使用 transform 替代 scaleUnitSquare
        window.contentView?.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        isWindowVisible = true
        
        // 执行动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            window.animator().alphaValue = 1.0
            // 使用 transform 替代 scaleUnitSquare
            window.contentView?.layer?.transform = CATransform3DMakeScale(1.25, 1.25, 1.0)
        } completionHandler: { [weak self] in
            // 恢复原始大小
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self?.animationDuration ?? 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                // 使用 transform 替代 scaleUnitSquare
                window.contentView?.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
            } completionHandler: { [weak self] in
                self?.isAnimating = false
            }
        }
    }
    
    private func animateWindowOut() {
        guard let window = window else {
            isAnimating = false
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            window.animator().alphaValue = 0.0
            // 使用 transform 替代 scaleUnitSquare
            window.contentView?.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.isWindowVisible = false
            self?.isAnimating = false
        }
    }
    
    // MARK: - 位置和大小计算
    
    private func calculateOptimalWindowPosition() -> CGPoint {
        guard let screen = currentScreen else {
            return CGPoint(x: 100, y: 100)
        }
        
        let screenFrame = screen.frame
        let windowFrame = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        
        // 计算居中位置
        var x = (screenFrame.width - windowFrame.width) / 2
        var y = screenFrame.height - windowFrame.height - windowPadding
        
        // 多屏幕适配
        if let screen = currentScreen {
            x += screen.frame.origin.x
            y += screen.frame.origin.y
        }
        
        return CGPoint(x: x, y: y)
    }
    
    private func clampWindowSize(_ size: CGSize) -> CGSize {
        let width = min(max(size.width, minWindowWidth), maxWindowWidth)
        let height = min(max(size.height, minWindowHeight), maxWindowHeight)
        return CGSize(width: width, height: height)
    }
    
    private func updateCurrentScreen() {
        currentScreen = NSScreen.main
    }
    
    // MARK: - 事件处理
    
    private func handleEdgeTrigger(direction: EdgeDirection) {
        guard !isWindowVisible && !isAnimating else { return }
        
        // 延迟触发，避免误触
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.isEdgeTracking {
                self.showWindow()
            }
        }
    }
    
    private func handleGesture(gesture: GestureType) {
        switch gesture {
        case .swipeDown:
            if isWindowVisible {
                hideWindow()
            }
        case .scrollDown:
            if !isWindowVisible {
                showWindow()
            }
        default:
            break
        }
    }
    
    @objc private func handleScreenConfigurationChanged() {
        // 延迟更新，等待屏幕配置稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateCurrentScreen()
            if self?.isWindowVisible == true {
                let newPosition = self?.calculateOptimalWindowPosition() ?? .zero
                self?.setWindowPosition(newPosition)
            }
        }
    }
    
    @objc private func handleApplicationDidBecomeActive() {
        // 应用激活时重新启用边缘跟踪
        if !isEdgeTracking {
            enableEdgeTracking()
        }
    }
    
    @objc private func handleApplicationDidResignActive() {
        // 应用失活时隐藏窗口并禁用边缘跟踪
        if isWindowVisible {
            hideWindow()
        }
        disableEdgeTracking()
    }
    
    // MARK: - 清理
    
    deinit {
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        
        edgeTracker?.stopTracking()
    }
}

// MARK: - 现代化浮动窗口

class ModernFloatingWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: `defer`)
        
        // 配置窗口属性
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    override func keyDown(with event: NSEvent) {
        // 处理 ESC 键
        if event.keyCode == 53 { // ESC key
            self.orderOut(nil)
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - 现代化边缘鼠标跟踪器

class ModernEdgeMouseTracker: ObservableObject {
    private var eventMonitor: Any?
    private var timer: Timer?
    private var lastMouseLocation: CGPoint = .zero
    private var edgeTriggerCount: Int = 0
    private var lastTriggerTime: Date = .init()
    
    let edgeThreshold: CGFloat
    let gestureThreshold: CGFloat
    
    var onEdgeTriggered: ((EdgeDirection) -> Void)?
    var onGestureDetected: ((GestureType) -> Void)?
    
    private let triggerDelay: TimeInterval = 0.1
    private let maxTriggerCount = 3
    private let resetInterval: TimeInterval = 1.0
    
    init(edgeThreshold: CGFloat, gestureThreshold: CGFloat) {
        self.edgeThreshold = edgeThreshold
        self.gestureThreshold = gestureThreshold
    }
    
    func startTracking() {
        stopTracking() // 确保先停止之前的跟踪
        
        // 设置鼠标事件监听
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .scrollWheel]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        // 设置定时器用于重置触发计数
        timer = Timer.scheduledTimer(withTimeInterval: resetInterval, repeats: true) { [weak self] _ in
            self?.resetTriggerCount()
        }
    }
    
    func stopTracking() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        timer?.invalidate()
        timer = nil
        
        edgeTriggerCount = 0
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        let currentLocation = event.locationInWindow
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        // 检测边缘触发
        checkEdgeTrigger(currentLocation, screenFrame: screenFrame)
        
        // 检测手势
        checkGesture(event, currentLocation: currentLocation)
        
        lastMouseLocation = currentLocation
    }
    
    private func checkEdgeTrigger(_ location: CGPoint, screenFrame: NSRect) {
        let currentTime = Date()
        
        // 防止频繁触发
        guard currentTime.timeIntervalSince(lastTriggerTime) > triggerDelay else { return }
        
        var triggeredDirection: EdgeDirection?
        
        // 检测顶部边缘
        if location.y >= screenFrame.maxY - edgeThreshold {
            triggeredDirection = .top
        }
        
        // 检测底部边缘
        if location.y <= screenFrame.minY + edgeThreshold {
            triggeredDirection = .bottom
        }
        
        // 检测左侧边缘
        if location.x <= screenFrame.minX + edgeThreshold {
            triggeredDirection = .left
        }
        
        // 检测右侧边缘
        if location.x >= screenFrame.maxX - edgeThreshold {
            triggeredDirection = .right
        }
        
        if let direction = triggeredDirection {
            edgeTriggerCount += 1
            lastTriggerTime = currentTime
            
            if edgeTriggerCount >= maxTriggerCount {
                onEdgeTriggered?(direction)
                edgeTriggerCount = 0
            }
        }
    }
    
    private func checkGesture(_ event: NSEvent, currentLocation: CGPoint) {
        // 检测滚动手势
        if event.type == .scrollWheel {
            let deltaY = event.deltaY
            
            if abs(deltaY) > gestureThreshold {
                if deltaY < 0 {
                    onGestureDetected?(.scrollDown)
                } else {
                    onGestureDetected?(.scrollUp)
                }
            }
        }
        
        // 检测滑动手势（基于鼠标移动速度）
        let deltaX = currentLocation.x - lastMouseLocation.x
        let deltaY = currentLocation.y - lastMouseLocation.y
        let speed = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        if speed > gestureThreshold * 2 {
            if abs(deltaY) > abs(deltaX) && deltaY > 0 {
                onGestureDetected?(.swipeUp)
            } else if abs(deltaY) > abs(deltaX) && deltaY < 0 {
                onGestureDetected?(.swipeDown)
            } else if abs(deltaX) > abs(deltaY) && deltaX > 0 {
                onGestureDetected?(.swipeRight)
            } else if abs(deltaX) > abs(deltaY) && deltaX < 0 {
                onGestureDetected?(.swipeLeft)
            }
        }
    }
    
    private func resetTriggerCount() {
        edgeTriggerCount = 0
    }
    
    deinit {
        stopTracking()
    }
}

// MARK: - 枚举定义

enum EdgeDirection {
    case top
    case bottom
    case left
    case right
}

enum GestureType {
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
    case scrollUp
    case scrollDown
}

enum GestureState {
    case idle
    case tracking
    case triggered
}

// MARK: - 扩展

extension View {
    func onDoubleTap(perform action: @escaping () -> Void) -> some View {
        self.onTapGesture(count: 2, perform: action)
    }
}

// MARK: - 预览

#Preview {
    Text("Modern Window Manager")
        .frame(width: 400, height: 300)
}