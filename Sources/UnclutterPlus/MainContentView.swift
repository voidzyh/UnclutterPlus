import SwiftUI
import Cocoa

// 全局变量存储设置窗口控制器
var preferencesWindowController: NSWindowController?

func showPreferencesWindow() {
    if preferencesWindowController == nil {
        let hosting = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("UnclutterPlusPreferencesWindow")
        window.setContentSize(NSSize(width: 520, height: 500))
        window.center()
        preferencesWindowController = NSWindowController(window: window)
    }
    
    guard let windowController = preferencesWindowController,
          let window = windowController.window else { return }
    
    NSApp.activate(ignoringOtherApps: true)
    window.level = .floating
    window.makeKeyAndOrderFront(nil)
    windowController.showWindow(nil)
}

struct MainContentView: View {
    @State private var selectedTab = 0
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器区域
            ZStack {
                // 居中的标签页按钮
                HStack(spacing: 0) {
                    TabButton(title: "tab.files".localized, systemImage: "folder", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "tab.clipboard".localized, systemImage: "doc.on.clipboard", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "tab.notes".localized, systemImage: "note.text", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                
                // 右侧的设置按钮
                HStack {
                    Spacer()
                    Button(action: {
                        // 直接创建并显示设置窗口
                        showPreferencesWindow()
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("button.preferences".localized)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    FilesView()
                case 1:
                    ClipboardView()
                case 2:
                    NotesView()
                default:
                    FilesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(radius: 20)
        )
        .padding(8)
        .id(refreshID) // 强制刷新视图
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID() // 语言变化时刷新视图
        }
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    MainContentView()
        .frame(width: 800, height: 300)
}
#endif