import SwiftUI
import Cocoa

// 单例模式的设置窗口管理器
class PreferencesWindowManager {
    static let shared = PreferencesWindowManager()
    
    private var windowController: NSWindowController?
    
    private init() {}
    
    func showPreferences() {
        print("PreferencesWindowManager: showPreferences called")
        
        DispatchQueue.main.async {
            // 如果窗口已经存在且显示中，直接激活它
            if let windowController = self.windowController,
               let window = windowController.window {
                if window.isVisible {
                    // 窗口已经显示，只需要激活它
                    print("Preferences window already visible, activating it")
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
            
            // 创建新窗口或显示已存在的窗口
            if self.windowController == nil {
                print("Creating new preferences window")
                let hosting = NSHostingController(rootView: PreferencesView())
                let window = NSWindow(contentViewController: hosting)
                window.title = "preferences.title".localized
                window.styleMask = [.titled, .closable, .miniaturizable]
                window.isReleasedWhenClosed = false
                window.setFrameAutosaveName("UnclutterPlusPreferencesWindow")
                window.setContentSize(NSSize(width: 520, height: 500))
                window.center()
                self.windowController = NSWindowController(window: window)
                
                // 监听窗口关闭通知
                NotificationCenter.default.addObserver(
                    forName: NSWindow.willCloseNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    print("Preferences window closed")
                    WindowManager.shared.setModalWindow(false)
                    // 不要将 windowController 设为 nil，保持窗口实例以便重用
                }
            }
            
            guard let windowController = self.windowController,
                  let window = windowController.window else { return }
            
            print("Showing preferences window")
            NSApp.activate(ignoringOtherApps: true)
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            windowController.showWindow(nil)
            
            // 设置模态窗口状态
            WindowManager.shared.setModalWindow(true)
        }
    }
}