import Cocoa

class EdgeMouseTracker {
    private var eventMonitor: Any?
    private let onEdgeTriggered: () -> Void
    private let edgeThreshold: CGFloat = 5.0
    private var lastTriggerTime: Date = Date.distantPast
    private let cooldownInterval: TimeInterval = 1.0
    
    init(onEdgeTriggered: @escaping () -> Void) {
        self.onEdgeTriggered = onEdgeTriggered
        startTracking()
    }
    
    deinit {
        stopTracking()
    }
    
    private func startTracking() {
        print("Starting mouse tracking...")
        
        // 添加全局事件监听
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
        }
        
        // 也添加本地事件监听（作为备选）
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
            return event
        }
        
        if eventMonitor != nil {
            print("鼠标追踪已启动")
        } else {
            print("警告：鼠标追踪启动失败 - 可能需要辅助功能权限")
        }
    }
    
    private func stopTracking() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleMouseMove(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        
        // 找到鼠标当前所在的屏幕
        guard let currentScreen = findScreenForPoint(mouseLocation) else { return }
        let screenFrame = currentScreen.frame
        
        // 检查鼠标是否在当前屏幕的顶部边缘
        let isAtTopEdge = mouseLocation.y >= screenFrame.maxY - edgeThreshold &&
                         mouseLocation.x >= screenFrame.minX &&
                         mouseLocation.x <= screenFrame.maxX
        
        // 调试输出
        if isAtTopEdge {
            print("Mouse at top edge: \(mouseLocation), screen: \(screenFrame)")
        }
        
        if isAtTopEdge {
            let now = Date()
            if now.timeIntervalSince(lastTriggerTime) > cooldownInterval {
                lastTriggerTime = now
                print("触发边缘事件！")
                DispatchQueue.main.async {
                    self.onEdgeTriggered()
                }
            } else {
                print("在冷却时间内，忽略触发")
            }
        }
    }
    
    private func findScreenForPoint(_ point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            let frame = screen.frame
            if point.x >= frame.minX && point.x <= frame.maxX &&
               point.y >= frame.minY && point.y <= frame.maxY {
                return screen
            }
        }
        return NSScreen.main // 如果找不到，回退到主屏幕
    }
}