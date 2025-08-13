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
    @ObservedObject private var config = ConfigurationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器区域
            ZStack {
                // 居中的标签页按钮
                HStack(spacing: 0) {
                    if config.isFilesEnabled {
                        TabButton(title: "tab.files".localized, systemImage: "folder", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }
                    }
                    if config.isClipboardEnabled {
                        TabButton(title: "tab.clipboard".localized, systemImage: "doc.on.clipboard", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }
                    }
                    if config.isNotesEnabled {
                        TabButton(title: "tab.notes".localized, systemImage: "note.text", isSelected: selectedTab == 2) {
                            selectedTab = 2
                        }
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
                if getEnabledViewCount() == 0 {
                    // 没有启用任何功能时显示提示
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("没有启用的功能")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("请在设置中启用至少一个功能")
                            .foregroundColor(.secondary)
                        
                        Button("打开设置") {
                            showPreferencesWindow()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 根据启用的功能显示对应内容
                    let actualTab = getActualTab(selectedTab)
                    switch actualTab {
                    case 0:
                        if config.isFilesEnabled {
                            FilesView()
                        }
                    case 1:
                        if config.isClipboardEnabled {
                            ClipboardView()
                        }
                    case 2:
                        if config.isNotesEnabled {
                            NotesView()
                        }
                    default:
                        EmptyView()
                    }
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
        .onAppear {
            adjustSelectedTab()
        }
        .onChange(of: config.isFilesEnabled) { adjustSelectedTab() }
        .onChange(of: config.isClipboardEnabled) { adjustSelectedTab() }
        .onChange(of: config.isNotesEnabled) { adjustSelectedTab() }
    }
    
    // 获取启用的功能数量
    private func getEnabledViewCount() -> Int {
        var count = 0
        if config.isFilesEnabled { count += 1 }
        if config.isClipboardEnabled { count += 1 }
        if config.isNotesEnabled { count += 1 }
        return count
    }
    
    // 将逻辑标签索引转换为实际标签索引
    private func getActualTab(_ logicalTab: Int) -> Int {
        var enabledTabs: [Int] = []
        if config.isFilesEnabled { enabledTabs.append(0) }
        if config.isClipboardEnabled { enabledTabs.append(1) }
        if config.isNotesEnabled { enabledTabs.append(2) }
        
        if logicalTab < enabledTabs.count {
            return enabledTabs[logicalTab]
        }
        return enabledTabs.first ?? 0
    }
    
    // 调整选中的标签页
    private func adjustSelectedTab() {
        let enabledCount = getEnabledViewCount()
        if enabledCount == 0 {
            selectedTab = 0
        } else if selectedTab >= enabledCount {
            selectedTab = 0
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