import Cocoa
import Combine

/// 菜单栏滚动触发器 - 在菜单栏空白区域滚动鼠标触发窗口显示/隐藏
class MenuBarScrollTracker: ObservableObject {
    static let shared = MenuBarScrollTracker()

    // MARK: - 主线程操作
    private let queue = DispatchQueue.main

    // MARK: - 配置属性
    @Published var isTracking = false
    @Published var lastScrollDirection: ScrollDirection = .unknown

    // 触发配置
    private let scrollThreshold: CGFloat = 1.5  // 滚动阈值
    private let cooldownInterval: TimeInterval = 0.8  // 冷却时间
    private let menuBarHeight: CGFloat = 24  // macOS 菜单栏高度
    private let detectionBuffer: CGFloat = 10  // 检测缓冲区

    // 菜单栏区域配置（可动态调整）
    private var leftMargin: CGFloat = 100     // 左侧应用图标区域（动态计算）
    private var systemMenuArea: CGFloat = 200  // 右侧系统菜单区域（动态计算）

    // 状态管理
    private var eventMonitor: Any?
    private var lastTriggerTime: Date = .distantPast
    private var lastScrollLocation: CGPoint = .zero
    private var isScrolling = false

    // 回调函数
    private var onScrollTrigger: ((ScrollDirection) -> Void)?
    private var onMenuBarClick: (() -> Void)?

    // MARK: - 枚举定义
    enum ScrollDirection {
        case up, down, unknown

        var description: String {
            switch self {
            case .up: return "向上滚动"
            case .down: return "向下滚动"
            case .unknown: return "未知方向"
            }
        }
    }

    private init() {
        calculateMenuBarAreas()
    }

    // 计算菜单栏区域
    private func calculateMenuBarAreas() {
        // 获取屏幕宽度
        guard let screen = NSScreen.main else {
            leftMargin = 100
            systemMenuArea = 200
            return
        }

        let screenWidth = screen.frame.width

        // 计算运行中的应用数量作为左侧区域的基础
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let estimatedAppCount = min(runningApps.count, 10)  // 最多10个应用图标

        // 每个应用图标大约 30-40px 宽，间距 5px
        leftMargin = CGFloat(estimatedAppCount) * 45 + 20  // 添加额外缓冲

        // 系统菜单区域大小与屏幕宽度成正比
        // 小屏幕（< 1400px）：150px
        // 大屏幕（>= 1400px）：200px
        systemMenuArea = screenWidth >= 1400 ? 220 : 180

        logger.debug("菜单栏区域计算完成 - 左边距: \(leftMargin)px, 系统菜单: \(systemMenuArea)px", category: "MenuBarScrollTracker")
    }

    // MARK: - 公共方法
    func startTracking(onScroll: @escaping (ScrollDirection) -> Void, onClick: (() -> Void)? = nil) {
        queue.async { [weak self] in
            self?.stopTrackingInternal()

            self?.onScrollTrigger = onScroll
            self?.onMenuBarClick = onClick

            logger.debug("开始监控菜单栏滚动事件", category: "MenuBarScrollTracker")

            // 监听全局鼠标事件（包括滚轮和点击）
            self?.eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .leftMouseUp, .rightMouseUp]) { event in
                self?.queue.async { [weak self] in
                    self?.handleGlobalEvent(event)
                }
            }

            self?.isTracking = true
        }
    }

    func stopTracking() {
        queue.async { [weak self] in
            self?.stopTrackingInternal()
        }
    }

    private func stopTrackingInternal() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            logger.debug("停止菜单栏滚动监控", category: "MenuBarScrollTracker")
        }
        isTracking = false
    }

    // MARK: - 私有方法
    private func handleGlobalEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero

        // 检查鼠标是否在菜单栏区域
        guard isInMenuBar(mouseLocation: mouseLocation, screenFrame: screenFrame) else {
            // 如果离开菜单栏，重置滚动状态
            isScrolling = false
            lastScrollLocation = .zero
            return
        }

        switch event.type {
        case .scrollWheel:
            handleScrollEvent(event, at: mouseLocation)
        case .leftMouseUp, .rightMouseUp:
            handleClickEvent(at: mouseLocation)
        default:
            break
        }
    }

    private func handleScrollEvent(_ event: NSEvent, at location: CGPoint) {
        let currentTime = Date()

        // 检查冷却时间
        guard currentTime.timeIntervalSince(lastTriggerTime) > cooldownInterval else {
            return
        }

        let deltaY = event.scrollingDeltaY
        let deltaX = event.scrollingDeltaX

        // 检测滚动阈值
        guard abs(deltaY) > scrollThreshold || abs(deltaX) > scrollThreshold else {
            return
        }

        // 判断滚动方向（主要考虑Y轴）
        let direction: ScrollDirection
        if abs(deltaY) > abs(deltaX) {
            direction = deltaY > 0 ? .up : .down
        } else {
            // 如果主要是水平滚动，忽略
            return
        }

        // 检查是否在菜单栏空白区域（不是应用图标或系统图标区域）
        guard isInMenuBarEmptyArea(location: location, screenFrame: NSScreen.main?.frame ?? .zero) else {
            return
        }

        // 更新状态
        lastScrollDirection = direction
        lastTriggerTime = currentTime
        isScrolling = true

        logger.debug("菜单栏滚动触发: \(direction.description) 位置: (\(Int(location.x)), \(Int(location.y)))", category: "MenuBarScrollTracker")

        // 触发回调
        onScrollTrigger?(direction)

        // 防止连续触发
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownInterval) { [weak self] in
            self?.isScrolling = false
        }
    }

    private func handleClickEvent(at location: CGPoint) {
        // 检查是否在菜单栏空白区域点击
        guard isInMenuBarEmptyArea(location: location, screenFrame: NSScreen.main?.frame ?? .zero) else {
            return
        }

        logger.debug("菜单栏空白区域点击", category: "MenuBarScrollTracker")
        onMenuBarClick?()
    }

    private func isInMenuBar(mouseLocation: CGPoint, screenFrame: NSRect) -> Bool {
        return mouseLocation.y >= screenFrame.maxY - menuBarHeight - detectionBuffer &&
               mouseLocation.y <= screenFrame.maxY &&
               mouseLocation.x >= screenFrame.minX &&
               mouseLocation.x <= screenFrame.maxX
    }

    private func isInMenuBarEmptyArea(location: CGPoint, screenFrame: NSRect) -> Bool {
        // 菜单栏的空白区域检测：避开系统图标的右侧区域和左上角
        // 使用动态计算的边距值
        return location.y >= screenFrame.maxY - menuBarHeight &&
               location.x > leftMargin &&
               location.x < screenFrame.maxX - systemMenuArea
    }

    // MARK: - 调试方法
    func printMenuBarInfo() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        logger.debug("菜单栏信息:", category: "MenuBarScrollTracker")
        logger.debug("  屏幕尺寸: \(frame.width) x \(frame.height)", category: "MenuBarScrollTracker")
        logger.debug("  菜单栏高度: \(menuBarHeight)", category: "MenuBarScrollTracker")
        logger.debug("  菜单栏Y范围: \(frame.maxY - menuBarHeight - detectionBuffer) - \(frame.maxY)", category: "MenuBarScrollTracker")
        logger.debug("  空白区域X: \(leftMargin) - \(frame.maxX - systemMenuArea)", category: "MenuBarScrollTracker")
        logger.debug("  当前鼠标位置: \(NSEvent.mouseLocation)", category: "MenuBarScrollTracker")

        // 重新计算并显示详细信息
        calculateMenuBarAreas()
    }

    // 重新计算菜单栏区域（当应用状态变化时调用）
    func recalculateMenuBarAreas() {
        calculateMenuBarAreas()
    }

    deinit {
        stopTracking()
    }
}