import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowManager: WindowManager?
    private var statusMenu: NSMenu?
    private var dockMenu: NSMenu?

    // 菜单栏滚动触发器
    private let menuBarTracker = MenuBarScrollTracker.shared

    // 优化的服务管理器
    private let serviceManager = ApplicationServiceManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("🚀 UnclutterPlus 启动中...")
        
        Task {
            do {
                // 初始化所有优化后的服务
                try await serviceManager.initialize()
                logger.info("✅ 所有服务初始化完成")
                
                // 记录启动性能指标
                logger.performance("Application Launch completed")
                
            } catch {
                logger.critical("服务初始化失败: \(error.localizedDescription)")
                // 在实际应用中，这里可以显示错误对话框
            }
        }
        
        // 设置UI和系统集成（这些可以在服务初始化期间并行进行）
        setupStatusBar()
        setupWindowManager()
        setupMenuBarScrollTracking()
        setupGlobalHotkey()
        setupDockMenu()
        setupNotificationObservers()
        
        logger.info("🎉 UnclutterPlus 启动完成")
        
        // 定期执行健康检查
        setupHealthMonitoring()
    }
    
    private func setupGlobalHotkey() {
        // 初始化截图快捷键管理器
        _ = GlobalHotkey.shared
        
        // 添加全局键盘快捷键 Command+Shift+U 用于显示窗口
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "u" {
                logger.info("检测到快捷键 Cmd+Shift+U")
                DispatchQueue.main.async {
                    self?.windowManager?.showWindow()
                }
            }
        }
        logger.info("已设置全局快捷键 Command+Shift+U", category: "AppDelegate")
    }
    
    private func setupStatusBar() {
        let defaults = UserDefaults.standard
        let isMenuBarEnabled = defaults.object(forKey: "ShowMenuBarIcon") == nil ?
            true : defaults.bool(forKey: "ShowMenuBarIcon")

        logger.info("菜单栏图标状态: \(isMenuBarEnabled ? "启用" : "禁用")", category: "AppDelegate")

        if isMenuBarEnabled {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        } else {
            statusItem = nil
            return
        }
        
        if let button = statusItem?.button {
            if let appIcon = NSImage(named: NSImage.Name("AppIcon")) {
                button.image = appIcon
                button.image?.size = NSSize(width: 16, height: 16)
            } else {
                button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "UnclutterPlus")
                button.image?.size = NSSize(width: 16, height: 16)
            }
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
        windowManager = WindowManager.shared
        logger.info("WindowManager 已初始化", category: "AppDelegate")
    }
    
    @objc private func statusBarButtonClicked() { /* menu shown automatically by NSStatusItem */ }
    
    @objc private func openMainWindow(_ sender: Any?) {
        windowManager?.showWindow()
    }
    
    @objc public func openPreferences(_ sender: Any?) {
        logger.info("打开设置窗口")
        // 使用单例管理器打开设置窗口
        PreferencesWindowManager.shared.showPreferences()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarIconVisibilityChanged),
            name: .menuBarIconVisibilityChanged,
            object: nil
        )
    }
    
    private func setupHealthMonitoring() {
        // 启动健康检查定时器（每5分钟检查一次）
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor [weak self] in
                let healthReport = await self?.serviceManager.performHealthCheck()
                
                if let report = healthReport {
                    if !report.isHealthy {
                        logger.warning("⚠️ 系统健康检查发现问题", category: "Health")
                        // 在实际应用中，这里可以显示健康状态指示器
                    }
                    
                    // 定期记录健康状态（调试模式）
                    #if DEBUG
                    if let lastLogTime = UserDefaults.standard.object(forKey: "lastHealthLog") as? Date,
                       Date().timeIntervalSince(lastLogTime) > 3600 { // 每小时记录一次
                        logger.debug("健康检查报告: \(report.description)", category: "Health")
                        UserDefaults.standard.set(Date(), forKey: "lastHealthLog")
                    }
                    #endif
                }
            }
        }
    }
    
    @objc private func menuBarIconVisibilityChanged() {
        if ConfigurationManager.shared.isMenuBarIconEnabled {
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
            toggleItem.title = ConfigurationManager.shared.isMenuBarIconEnabled ? 
                "menu.hide_menubar_icon".localized : 
                "menu.show_menubar_icon".localized
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
        ConfigurationManager.shared.isMenuBarIconEnabled.toggle()
    }
    
    // 应用即将退出时的清理
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("应用即将退出，开始清理...")
        
        Task {
            await serviceManager.shutdown()
            logger.info("✅ 应用清理完成")
        }
    }
    
    // MARK: - 菜单栏滚动触发

    private func setupMenuBarScrollTracking() {
        logger.info("设置菜单栏滚动触发器...", category: "UI")

        // 启动菜单栏滚动触发器
        menuBarTracker.startTracking { [weak self] direction in
            self?.handleMenuBarScroll(direction: direction)
        } onClick: { [weak self] in
            self?.handleMenuBarClick()
        }
    }

    private func handleMenuBarScroll(direction: MenuBarScrollTracker.ScrollDirection) {
        logger.info("菜单栏滚动触发：\(direction.description)", category: "UI")

        // 根据配置的滚动方向映射来决定操作
        let mapping = ConfigurationManager.shared.scrollDirectionMapping
        let shouldShowWindow: Bool

        switch mapping {
        case .upToShow:
            // 向上显示，向下隐藏（默认）
            shouldShowWindow = (direction == .up)

        case .downToShow:
            // 向下显示，向上隐藏
            shouldShowWindow = (direction == .down)

        case .natural:
            // 自然模式：根据窗口位置判断
            // 如果窗口在顶部，向上滚动=显示；如果窗口在底部，向下滚动=显示
            if let windowFrame = windowManager?.window?.frame,
               let screenFrame = NSScreen.main?.frame {
                let windowIsNearTop = windowFrame.maxY > screenFrame.maxY * 0.8
                shouldShowWindow = windowIsNearTop ? (direction == .up) : (direction == .down)
            } else {
                // 默认行为：向上显示
                shouldShowWindow = (direction == .up)
            }
        }

        // 执行显示或隐藏操作
        if shouldShowWindow {
            logger.info("滚动操作 - 显示主窗口", category: "UI")
            windowManager?.showWindow()
        } else {
            logger.info("滚动操作 - 隐藏主窗口", category: "UI")
            windowManager?.hideWindow()
        }
    }

    private func handleMenuBarClick() {
        logger.info("菜单栏空白区域点击", category: "UI")

        // 显示点击即时反馈（涟漪动画）
        let mouseLocation = NSEvent.mouseLocation
        ClickFeedbackManager.shared.showFeedback(at: mouseLocation)

        // 点击逻辑：基于窗口状态进行切换
        if let windowManager = windowManager {
            if windowManager.isWindowVisible {
                // 如果窗口可见，点击后隐藏
                logger.info("点击 - 隐藏主窗口", category: "UI")
                windowManager.hideWindow()
            } else {
                // 如果窗口不可见，点击后显示
                logger.info("点击 - 显示主窗口", category: "UI")
                windowManager.showWindow()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        menuBarTracker.stopTracking()
    }
}

