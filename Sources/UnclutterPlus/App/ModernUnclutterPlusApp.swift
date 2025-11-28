import SwiftUI
import Combine

/// 现代化 UnclutterPlus 应用入口 - 集成所有新组件
@main
struct ModernUnclutterPlusApp: App {
    @NSApplicationDelegateAdaptor(ModernAppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var designSystem = ModernDesignSystem.shared
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared

    var body: some Scene {
        ModernPreferencesView()
            .frame(minWidth: 600, minHeight: 500)
    }
    .commands {
        // 应用菜单命令
        CommandGroup(after: .appSettings) {
            Button("Show UnclutterPlus") {
                appState.showApp()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift]) {
                appState.hideApp()
            }
            Button("Hide UnclutterPlus") {
                appState.hideApp()
            }
        }

        CommandGroup(after: .help) {
            Button("Performance Monitor") {
                appState.showPerformanceMonitorWindow()
            }
            Button("About Modern UnclutterPlus") {
                appState.showAbout()
            }
        }
    }
}