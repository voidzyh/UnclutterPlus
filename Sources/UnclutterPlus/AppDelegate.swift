import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowManager: WindowManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application launched!")
        setupStatusBar()
        setupWindowManager()
        setupGlobalHotkey()
    }
    
    private func setupGlobalHotkey() {
        // 添加全局键盘快捷键 Command+Shift+U
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "u" {
                print("检测到快捷键 Cmd+Shift+U")
                DispatchQueue.main.async {
                    self?.windowManager?.showWindow()
                }
            }
        }
        print("已设置全局快捷键 Command+Shift+U")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "tray.2", accessibilityDescription: "UnclutterPlus")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }
    
    private func setupWindowManager() {
        windowManager = WindowManager()
        print("WindowManager 已初始化")
    }
    
    @objc private func statusBarButtonClicked() {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: "Open UnclutterPlus", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc private func openMainWindow() {
        print("点击了 Open UnclutterPlus 按钮")
        windowManager?.showWindow()
    }
    
    @objc private func openPreferences() {
        // TODO: 实现偏好设置窗口
        print("Open preferences")
    }
}