import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowManager: WindowManager?
    private var preferencesWindowController: NSWindowController?
    private var statusMenu: NSMenu?
    private var dockMenu: NSMenu?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application launched!")
        setupStatusBar()
        setupWindowManager()
        setupGlobalHotkey()
        setupDockMenu()
        setupNotificationObservers()
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
        // 只在需要显示时创建状态栏项目
        if Preferences.shared.showMenuBarIcon {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        } else {
            statusItem = nil
            return
        }
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "tray.2", accessibilityDescription: "UnclutterPlus")
        }

        // Build a persistent status menu
        let menu = NSMenu()
        // Open
        let openItem = NSMenuItem(title: "menu.open".localized, action: #selector(openMainWindow(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "menu.preferences".localized, action: #selector(openPreferences(_:)), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = [.command]
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "menu.quit".localized, action: #selector(NSApplication.terminate), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusMenu = menu
        statusItem?.menu = menu
    }
    
    private func setupWindowManager() {
        windowManager = WindowManager()
        print("WindowManager 已初始化")
    }
    
    @objc private func statusBarButtonClicked() { /* menu shown automatically by NSStatusItem */ }
    
    @objc private func openMainWindow(_ sender: Any?) {
        windowManager?.showWindow()
    }
    
    @objc public func openPreferences(_ sender: Any?) {
        print("openPreferences called")
        DispatchQueue.main.async {
            if self.preferencesWindowController == nil {
                let hosting = NSHostingController(rootView: PreferencesView())
                let window = NSWindow(contentViewController: hosting)
                window.title = "Preferences"
                window.styleMask = [.titled, .closable, .miniaturizable]
                window.isReleasedWhenClosed = false
                window.setFrameAutosaveName("UnclutterPlusPreferencesWindow")
                window.setContentSize(NSSize(width: 520, height: 500))
                window.center()
                self.preferencesWindowController = NSWindowController(window: window)
            }
            
            guard let windowController = self.preferencesWindowController,
                  let window = windowController.window else { return }
            
            NSApp.activate(ignoringOtherApps: true)
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            windowController.showWindow(nil)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarIconVisibilityChanged),
            name: .menuBarIconVisibilityChanged,
            object: nil
        )
    }
    
    @objc private func menuBarIconVisibilityChanged() {
        if Preferences.shared.showMenuBarIcon {
            // 显示菜单栏图标
            if statusItem == nil {
                setupStatusBar()
            }
        } else {
            // 隐藏菜单栏图标
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    private func setupDockMenu() {
        // 创建 Dock 菜单
        let menu = NSMenu()
        
        // Open
        let openItem = NSMenuItem(title: "menu.open".localized, action: #selector(openMainWindow(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Preferences
        let prefsItem = NSMenuItem(title: "menu.preferences".localized, action: #selector(openPreferences(_:)), keyEquivalent: "")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Show/Hide Menu Bar Icon
        let toggleMenuItem = NSMenuItem(title: "", action: #selector(toggleMenuBarIcon(_:)), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        
        dockMenu = menu
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        // 更新菜单项文本
        if let toggleItem = dockMenu?.items.last {
            toggleItem.title = Preferences.shared.showMenuBarIcon ? "menu.hide_menubar_icon".localized : "menu.show_menubar_icon".localized
        }
        return dockMenu
    }
    
    // 处理 Dock 图标点击
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 点击 Dock 图标时打开主窗口
        windowManager?.showWindow()
        return true
    }
    
    @objc private func toggleMenuBarIcon(_ sender: Any?) {
        Preferences.shared.showMenuBarIcon.toggle()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}