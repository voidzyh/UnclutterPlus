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

/// 现代化偏好设置视图
struct ModernPreferencesView: View {
    var body: some View {
        VStack {
            Text("UnclutterPlus v2.0.0")
                .font(.title)
                .padding()

            Text("现代化 macOS 生产力应用")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text("© 2025 UnclutterPlus")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
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