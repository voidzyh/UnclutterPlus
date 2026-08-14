import AppIntents
import SwiftUI

// MARK: - App Intents（Shortcuts 集成）

/// 声明本应用提供的 App Intents（macOS 13+）。
///
/// 注意：Shortcuts 应用的发现与运行依赖完整 .app bundle（scripts/build.sh 打包时
/// 注入 entitlements/Info.plist）；swift run 直接运行二进制时 Shortcuts 不可见。
struct UnclutterPlusIntents: AppIntentsPackage {}

/// 显示/隐藏浮动面板
struct ShowPanelIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.show_panel.title"
    static var description = IntentDescription("intent.show_panel.description")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        WindowManager.shared.showWindow()
        return .result()
    }
}

/// 隐藏浮动面板
struct HidePanelIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.hide_panel.title"
    static var description = IntentDescription("intent.hide_panel.description")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        WindowManager.shared.hideWindow()
        return .result()
    }
}

/// 复制最近一条剪贴板历史
struct CopyLatestClipboardItemIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.copy_latest.title"
    static var description = IntentDescription("intent.copy_latest.description")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let succeeded = await AppStorageManager.shared.clipboardRepository.copyLatestItemToPasteboard()
        let dialog: IntentDialog = succeeded
            ? "intent.copy_latest.success"
            : "intent.copy_latest.empty"
        return .result(dialog: dialog)
    }
}

// MARK: - Shortcuts 暴露

/// 向 Shortcuts 应用暴露快捷指令（每个应用仅允许一个 AppShortcutsProvider）
struct UnclutterPlusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowPanelIntent(),
            phrases: [
                "Show \(.applicationName) panel",
                "Open \(.applicationName)",
            ],
            shortTitle: "intent.show_panel.short_title",
            systemImageName: "macwindow"
        )

        AppShortcut(
            intent: CopyLatestClipboardItemIntent(),
            phrases: [
                "Copy latest \(.applicationName) clipboard item",
                "Copy last copied item from \(.applicationName)",
            ],
            shortTitle: "intent.copy_latest.short_title",
            systemImageName: "doc.on.clipboard"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}
