import Cocoa
import SwiftUI

class CustomWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // 添加这些方法来确保键盘事件正确处理
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeKey() {
        super.becomeKey()
        // 确保内容视图可以接收键盘事件
        self.makeFirstResponder(self.contentView)
    }
    
    // 确保键盘事件能够传递到 SwiftUI 视图
    override func keyDown(with event: NSEvent) {
        // 让 SwiftUI 处理键盘事件
        if let contentView = self.contentView {
            contentView.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }
}

class WindowManager: NSObject {
    private var window: NSWindow?
    private var mouseTracker: EdgeMouseTracker?
    
    override init() {
        super.init()
        setupWindow()
        setupEdgeTracking()
    }
    
    private func setupWindow() {
        let contentView = MainContentView()
        
        window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
        window?.level = .floating
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
                
                // 添加短暂延迟确保焦点正确设置
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    window.makeFirstResponder(window.contentView)
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
        let x = screenFrame.midX - (windowFrame.width / 2)
        let y = screenFrame.maxY - windowFrame.height - 10
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
        print("Window positioned on screen: \(screenFrame)")
    }
    
    private func findScreenForPoint(_ point: CGPoint) -> NSScreen? {
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