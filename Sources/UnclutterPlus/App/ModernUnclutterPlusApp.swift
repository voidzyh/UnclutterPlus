import SwiftUI
import Combine
import AppKit

/// 现代化 UnclutterPlus 应用入口
@main
struct ModernUnclutterPlusApp: App {
    @NSApplicationDelegateAdaptor(ModernAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            UnifiedMainLayout()
        }
        .commands {
            CommandGroup(after: .help) {
                Button("About UnclutterPlus") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}

/// 现代化应用委托
final class ModernAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("UnclutterPlus v2.0.0 启动完成", category: "Service")
        logger.info("📦 现代化架构: Swift 6.0 + SwiftUI 5.0", category: "ModernUnclutterPlusApp")
        logger.info("🏗️ MVVM + Repository 模式", category: "ModernUnclutterPlusApp")

        // 启动剪贴板监听（智能洞察数据源）
        if ConfigurationManager.shared.clipboardMonitorEnabled {
            Task { @MainActor in
                ClipboardMonitor.shared.start()
            }
        }
    }
}