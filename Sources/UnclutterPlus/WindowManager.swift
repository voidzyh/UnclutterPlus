import Cocoa
import SwiftUI

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
        print("Panel became key window")
        // 确保窗口内容获得焦点
        if let contentView = self.contentView {
            self.makeFirstResponder(contentView)
        }
    }
    
    override func resignKey() {
        super.resignKey()
        print("Panel resigned key window")
    }
}

class WindowManager: NSObject {
    private var window: NSPanel?
    private var mouseTracker: EdgeMouseTracker?
    
    override init() {
        super.init()
        setupWindow()
        setupEdgeTracking()
    }
    
    private func setupWindow() {
        let contentView = MainContentView()
        
        window = KeyboardSupportPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 300),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        window?.contentView = hostingView
        window?.level = .floating
        window?.isFloatingPanel = true  // 设置为浮动面板
        window?.hidesOnDeactivate = false  // 失去焦点时不隐藏
        window?.becomesKeyOnlyIfNeeded = false  // 总是可以成为 key window
        window?.worksWhenModal = true  // 在模态窗口时也工作
        window?.isOpaque = true
        window?.backgroundColor = NSColor.controlBackgroundColor
        window?.hasShadow = true
        window?.ignoresMouseEvents = false
        window?.title = "UnclutterPlus"
        window?.acceptsMouseMovedEvents = true
        
        print("Window created successfully")
        
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
    }
    
    private func setupEdgeTracking() {
        mouseTracker = EdgeMouseTracker(
            onEdgeTriggered: { [weak self] direction in
                self?.handleEdgeTrigger(direction: direction)
            },
            scrollDirection: .both,           // 支持双向滚轮触发
            gestureType: .twoFingerDown      // 只支持双指下滑
        )
    }
    
    private func handleEdgeTrigger(direction: EdgeMouseTracker.ScrollDirection) {
        guard let window = window else { return }
        
        switch direction {
        case .up:
            // 向上滚动隐藏窗口
            if window.isVisible {
                hideWindow()
            }
        case .down:
            // 向下滚动显示窗口
            if !window.isVisible {
                showWindow()
            }
        case .both:
            // 双向触发时切换显示状态
            showWindow()
        }
    }
    
    func showWindow() {
        guard let window = window else { 
            print("Error: Window is nil")
            return 
        }
        
        print("Showing window - current visibility: \(window.isVisible)")
        
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
                    
                    if let hostingView = window.contentView as? NSHostingView<MainContentView> {
                        window.makeFirstResponder(hostingView)
                        print("Floating window setup complete")
                    }
                }
                
                print("Window is now key and active")
            }
            print("Window should now be visible")
        } else {
            print("Window is already visible, hiding it")
            hideWindow()
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
            print("多屏布局：上方有屏幕，调整窗口位置避免遮挡")
        } else {
            // 标准位置：紧贴屏幕顶部
            y = screenFrame.maxY - windowFrame.height - margin
        }
        
        let newOrigin = NSPoint(x: x, y: y)
        window.setFrameOrigin(newOrigin)
        
        print("窗口定位: \(newOrigin)")
        print("屏幕信息: \(screenFrame)")
        print("布局分析: 上方有屏幕=\(hasScreenAbove), 下方有屏幕=\(hasScreenBelow)")
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
}