import SwiftUI
import Combine

/// 现代化 UnclutterPlus 应用入口
@main
struct ModernUnclutterPlusApp: App {
    @NSApplicationDelegateAdaptor(ModernAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            ModernPreferencesView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .help) {
                Button("About Modern UnclutterPlus") {
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
        print("✅ UnclutterPlus v2.0.0 启动完成")
        print("📦 现代化架构: Swift 6.0 + SwiftUI 5.0")
        print("🏗️ MVVM + Repository 模式")
    }
}