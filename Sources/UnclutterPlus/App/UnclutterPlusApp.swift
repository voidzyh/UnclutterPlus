import SwiftUI

// @main // 临时禁用，避免与 ModernUnclutterPlusApp 冲突
struct UnclutterPlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            PreferencesView()
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Preferences...") {
                    NSApp.sendAction(#selector(AppDelegate.openPreferences(_:)), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}