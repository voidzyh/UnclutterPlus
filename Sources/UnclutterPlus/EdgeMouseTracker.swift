import Cocoa

class EdgeMouseTracker {
    private var scrollEventMonitor: Any?
    private var gestureEventMonitor: Any?
    private let onEdgeTriggered: () -> Void
    
    // 配置参数
    private let edgeThreshold: CGFloat = 50.0  // 边缘检测区域
    private let scrollThreshold: CGFloat = 0.5  // 滚轮触发阈值
    private let gestureThreshold: CGFloat = 0.15  // 降低触摸板手势触发阈值，提高响应
    
    // 冷却时间控制
    private var lastTriggerTime: Date = Date.distantPast
    private let cooldownInterval: TimeInterval = 1.0  // 减少冷却时间
    
    // 调试输出控制
    private var lastLogTime: Date = Date.distantPast
    private let logCooldownInterval: TimeInterval = 5.0
    
    // 配置选项
    enum ScrollDirection: CaseIterable {
        case up, down, both
        
        var description: String {
            switch self {
            case .up: return "向上滚动"
            case .down: return "向下滚动" 
            case .both: return "双向滚动"
            }
        }
    }
    
    enum GestureType: CaseIterable {
        case twoFingerDown
        
        var description: String {
            return "双指向下滑动"
        }
    }
    
    private var enabledScrollDirection: ScrollDirection = .both
    private var enabledGestureType: GestureType = .twoFingerDown
    
    init(onEdgeTriggered: @escaping () -> Void, 
         scrollDirection: ScrollDirection = .both,
         gestureType: GestureType = .twoFingerDown) {
        self.onEdgeTriggered = onEdgeTriggered
        self.enabledScrollDirection = scrollDirection
        self.enabledGestureType = gestureType
        startTracking()
    }
    
    deinit {
        stopTracking()
    }
    
    private func startTracking() {
        print("Starting gesture and scroll tracking...")
        
        // 监听滚轮事件
        scrollEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }
        
        // 专注于双指滑动，使用scrollWheel事件获得最佳响应速度
        // swipe事件通常有延迟，scrollWheel事件更实时
        let gestureEventMask: NSEvent.EventTypeMask = [.swipe]
        gestureEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: gestureEventMask) { [weak self] event in
            self?.handleGestureEvent(event)
        }
        
        // 同时监听本地事件（当应用是前台时）- scrollWheel优先处理双指滑动
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            // 先尝试作为手势处理，如果不是手势再作为滚轮处理
            if event.hasPreciseScrollingDeltas && abs(event.scrollingDeltaY) > 0.1 {
                self?.handleGestureEvent(event)
            } else {
                self?.handleScrollEvent(event)
            }
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: gestureEventMask) { [weak self] event in
            self?.handleGestureEvent(event)
            return event
        }
        
        if scrollEventMonitor != nil {
            print("手势和滚轮追踪已启动")
            print("触发配置: 滚轮[\(enabledScrollDirection.description)]，手势[\(enabledGestureType.description)]")
        } else {
            print("警告：手势追踪启动失败 - 可能需要辅助功能权限")
        }
    }
    
    private func stopTracking() {
        if let monitor = scrollEventMonitor {
            NSEvent.removeMonitor(monitor)
            scrollEventMonitor = nil
        }
        if let monitor = gestureEventMonitor {
            NSEvent.removeMonitor(monitor)
            gestureEventMonitor = nil
        }
        print("手势和滚轮追踪已停止")
    }
    
    // 处理滚轮事件
    private func handleScrollEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        
        // 检查鼠标是否在屏幕顶部边缘区域
        guard let currentScreen = findScreenForPoint(mouseLocation),
              isAtTopEdge(mouseLocation, screen: currentScreen) else {
            return
        }
        
        let scrollY = event.scrollingDeltaY
        let shouldTrigger: Bool
        
        switch enabledScrollDirection {
        case .up:
            shouldTrigger = scrollY > scrollThreshold
        case .down:
            shouldTrigger = scrollY < -scrollThreshold
        case .both:
            shouldTrigger = abs(scrollY) > scrollThreshold
        }
        
        if shouldTrigger {
            let now = Date()
            if now.timeIntervalSince(lastLogTime) > logCooldownInterval {
                lastLogTime = now
                print("滚轮触发: \(scrollY) at \(mouseLocation)")
            }
            
            attemptTrigger(source: "滚轮[\(scrollY > 0 ? "上" : "下")]")
        }
    }
    
    // 处理触摸板手势事件 - 只支持双指下滑
    private func handleGestureEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        
        // 检查鼠标是否在屏幕顶部边缘区域
        guard let currentScreen = findScreenForPoint(mouseLocation),
              isAtTopEdge(mouseLocation, screen: currentScreen) else {
            return
        }
        
        var shouldTrigger = false
        let gestureDescription = "双指向下滑动"
        
        switch event.type {
        case .scrollWheel:
            // 优先处理scrollWheel事件 - 这是最快的方式检测双指滑动
            // 触摸板双指滑动会产生hasPreciseScrollingDeltas = true的scrollWheel事件
            if event.hasPreciseScrollingDeltas {
                let deltaY = event.scrollingDeltaY
                // 向下滑动产生负的deltaY
                if deltaY < -gestureThreshold {
                    shouldTrigger = true
                }
            }
        case .swipe:
            // 备用：处理系统级的swipe手势
            let deltaY = event.deltaY
            if deltaY < -gestureThreshold {
                shouldTrigger = true
            }
        default:
            break
        }
        
        if shouldTrigger {
            // 减少日志输出的频率以降低延迟
            let now = Date()
            if now.timeIntervalSince(lastLogTime) > logCooldownInterval {
                lastLogTime = now
                print("手势触发: \(gestureDescription) at \(mouseLocation)")
            }
            
            // 立即触发，不添加额外的延迟
            attemptTrigger(source: gestureDescription)
        }
    }
    
    // 统一的触发尝试方法
    private func attemptTrigger(source: String) {
        let now = Date()
        if now.timeIntervalSince(lastTriggerTime) > cooldownInterval {
            lastTriggerTime = now
            print("✅ 触发成功! 来源: \(source)")
            DispatchQueue.main.async {
                self.onEdgeTriggered()
            }
        } else {
            let remainingTime = cooldownInterval - now.timeIntervalSince(lastTriggerTime)
            print("⏳ 冷却中，剩余 \(String(format: "%.1f", remainingTime))秒 - 来源: \(source)")
        }
    }
    
    // 检查是否在屏幕顶部边缘
    private func isAtTopEdge(_ point: CGPoint, screen: NSScreen) -> Bool {
        let frame = screen.frame
        return point.y >= frame.maxY - edgeThreshold &&
               point.x >= frame.minX &&
               point.x <= frame.maxX
    }
    
    // 多屏幕支持 - 查找鼠标所在的屏幕
    private func findScreenForPoint(_ point: CGPoint) -> NSScreen? {
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
        
        // 如果都找不到，返回主屏幕作为fallback
        return NSScreen.main
    }
    
    // 配置更新方法
    func updateScrollDirection(_ direction: ScrollDirection) {
        enabledScrollDirection = direction
        print("更新滚轮触发方向: \(direction.description)")
    }
    
    func updateGestureType(_ gestureType: GestureType) {
        enabledGestureType = gestureType
        print("更新手势触发类型: \(gestureType.description)")
    }
    
    // 获取当前配置
    func getCurrentConfig() -> (ScrollDirection, GestureType) {
        return (enabledScrollDirection, enabledGestureType)
    }
}