import SwiftUI
import Combine
import AppKit

/// 现代化 UnclutterPlus 应用入口（菜单栏浮动面板形态，无主窗口）
@main
struct ModernUnclutterPlusApp: App {
    @NSApplicationDelegateAdaptor(ModernAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

/// 现代化应用委托：负责菜单栏图标、浮动面板唤出（滚动/点击/快捷键）、剪贴板监听
final class ModernAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    /// 进程启动时刻（AppDelegate 在应用引导最早阶段创建，用于启动耗时打点）
    private let launchStartTime = ProcessInfo.processInfo.systemUptime

    private var windowManager: WindowManager { WindowManager.shared }
    private var menuBarTracker: MenuBarScrollTracker { MenuBarScrollTracker.shared }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchDurationMs = (ProcessInfo.processInfo.systemUptime - launchStartTime) * 1000
        logger.info(
            "UnclutterPlus v2.0.0 启动完成（耗时 \(String(format: "%.0f", launchDurationMs))ms）",
            category: "Service"
        )

        // 依赖注入：面板内容视图（App 层 → Core 层）与文件夹/暂存文件动作的自动隐藏回调
        WindowManager.shared.contentFactory = { AnyView(ModernMainContentView()) }
        WindowManager.shared.prepareWindow()
        FavoriteFoldersManager.shared.autoHideHandler = { action in
            WindowManager.shared.hideWindowAfterAction(action)
        }
        TempFileManager.shared.autoHideHandler = { action in
            WindowManager.shared.hideWindowAfterAction(action)
        }

        setupStatusBar()
        setupMenuBarScrollTracking()
        setupGlobalHotkey()
        setupNotificationObservers()

        // 启动剪贴板监听（智能洞察数据源）
        if ConfigurationManager.shared.clipboardMonitorEnabled {
            Task { @MainActor in
                ClipboardMonitor.shared.start()
            }
        }
    }

    // MARK: - 菜单栏图标

    private func setupStatusBar() {
        guard ConfigurationManager.shared.isMenuBarIconEnabled else {
            statusItem = nil
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let appIcon = NSImage(named: NSImage.Name("AppIcon")) {
                button.image = appIcon
                button.image?.size = NSSize(width: 16, height: 16)
            } else {
                button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "UnclutterPlus")
                button.image?.size = NSSize(width: 16, height: 16)
            }
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "menu.open".localized, action: #selector(openMainWindow(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "menu.preferences".localized, action: #selector(openPreferences(_:)), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = [.command]
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "menu.quit".localized, action: #selector(NSApplication.terminate), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openMainWindow(_ sender: Any?) {
        windowManager.showWindow()
    }

    @objc private func openPreferences(_ sender: Any?) {
        showPreferencesWindow()
    }

    private func showPreferencesWindow() {
        PreferencesWindowManager.shared.showPreferences()
    }

    // MARK: - 菜单栏滚动/点击唤出

    private func setupMenuBarScrollTracking() {
        menuBarTracker.startTracking { [weak self] direction in
            self?.handleMenuBarScroll(direction: direction)
        } onClick: { [weak self] in
            self?.handleMenuBarClick()
        }
    }

    private func handleMenuBarScroll(direction: MenuBarScrollTracker.ScrollDirection) {
        // 根据配置的滚动方向映射来决定操作
        let mapping = ConfigurationManager.shared.scrollDirectionMapping
        let shouldShowWindow: Bool

        switch mapping {
        case .upToShow:
            shouldShowWindow = (direction == .up)
        case .downToShow:
            shouldShowWindow = (direction == .down)
        case .natural:
            // 自然模式：根据窗口位置判断
            if let windowFrame = windowManager.window?.frame,
               let screenFrame = NSScreen.main?.frame {
                let windowIsNearTop = windowFrame.maxY > screenFrame.maxY * 0.8
                shouldShowWindow = windowIsNearTop ? (direction == .up) : (direction == .down)
            } else {
                shouldShowWindow = (direction == .up)
            }
        }

        if shouldShowWindow {
            windowManager.showWindow()
        } else {
            windowManager.hideWindow()
        }
    }

    private func handleMenuBarClick() {
        // 点击即时反馈（涟漪动画）
        ClickFeedbackManager.shared.showFeedback(at: NSEvent.mouseLocation)

        // 基于窗口状态切换显示
        windowManager.toggleWindow()
    }

    // MARK: - 全局快捷键

    private func setupGlobalHotkey() {
        // Command+Shift+U 唤出/隐藏面板（keyCode 32 = "U"）
        let registered = GlobalHotkey.shared.register(keyCode: 32, modifiers: [.command, .shift]) {
            Task { @MainActor in
                WindowManager.shared.toggleWindow()
            }
        }
        logger.info("全局快捷键 Command+Shift+U 注册\(registered ? "成功" : "失败")", category: "ModernAppDelegate")
    }

    // MARK: - 通知观察

    private func setupNotificationObservers() {
        // 设置界面入口（Sidebar Settings 按钮）
        NotificationCenter.default.addObserver(
            forName: .showPreferences,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showPreferencesWindow()
        }

        // 菜单栏图标显隐设置变更
        NotificationCenter.default.addObserver(
            forName: .menuBarIconVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuBarIconVisibility()
        }
    }

    private func updateMenuBarIconVisibility() {
        if ConfigurationManager.shared.isMenuBarIconEnabled {
            if statusItem == nil {
                setupStatusBar()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    // MARK: - Dock

    /// 点击 Dock 图标时唤出面板
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowManager.showWindow()
        return true
    }
}
