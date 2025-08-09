import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowManager: WindowManager?
    private var preferencesWindowController: NSWindowController?
    private var statusMenu: NSMenu?
    
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
        }

        // Build a persistent status menu
        let menu = NSMenu()
        // Open
        let openItem = NSMenuItem(title: "Open UnclutterPlus", action: #selector(openMainWindow(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = [.command]
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q")
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
    
    @objc func openPreferences(_ sender: Any?) {
        DispatchQueue.main.async {
            if self.preferencesWindowController == nil {
                let hosting = NSHostingController(rootView: PreferencesView())
                let window = NSWindow(contentViewController: hosting)
                window.title = "Preferences"
                window.styleMask = [.titled, .closable, .miniaturizable]
                window.isReleasedWhenClosed = false
                window.setFrameAutosaveName("UnclutterPlusPreferencesWindow")
                window.setContentSize(NSSize(width: 520, height: 400))
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
}