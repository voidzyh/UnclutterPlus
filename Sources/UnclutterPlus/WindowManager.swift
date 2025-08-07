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
        mouseTracker = EdgeMouseTracker { [weak self] in
            self?.showWindow()
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
        let startY = screenFrame.maxY
        let endY = screenFrame.maxY - windowFrame.height - 10
        
        window.setFrameOrigin(NSPoint(x: windowFrame.origin.x, y: startY))
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrameOrigin(NSPoint(x: windowFrame.origin.x, y: endY))
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
        let endY = screenFrame.maxY
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrameOrigin(NSPoint(x: windowFrame.origin.x, y: endY))
        } completionHandler: {
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
        
        // 确保窗口在屏幕边界内
        let margin: CGFloat = 10
        let maxX = screenFrame.maxX - windowFrame.width - margin
        let minX = screenFrame.minX + margin
        let x = max(minX, min(maxX, screenFrame.midX - (windowFrame.width / 2)))
        let y = screenFrame.maxY - windowFrame.height - margin
        
        let newOrigin = NSPoint(x: x, y: y)
        window.setFrameOrigin(newOrigin)
        print("Window positioned at: \(newOrigin) on screen: \(screenFrame)")
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