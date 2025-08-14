import SwiftUI
import Cocoa

// 全局变量存储设置窗口控制器
var preferencesWindowController: NSWindowController?

func showPreferencesWindow() {
    if preferencesWindowController == nil {
        let hosting = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "preferences.title".localized
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
    @State private var lastConfigHash = 0
    @State private var configMonitorTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器区域
            ZStack {
                // 居中的标签页按钮
                HStack(spacing: 0) {
                    ForEach(Array(config.enabledTabsOrder.enumerated()), id: \.element) { index, tabId in
                        TabButton(
                            title: getTabTitle(for: tabId),
                            systemImage: getTabIcon(for: tabId),
                            isSelected: selectedTab == index
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = index
                            }
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
                        
                        Text("features.no_enabled.title".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("features.no_enabled.description".localized)
                            .foregroundColor(.secondary)
                        
                        Button("features.open_settings".localized) {
                            showPreferencesWindow()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 根据启用的功能显示对应内容
                    let enabledTabs = config.enabledTabsOrder
                    if selectedTab < enabledTabs.count {
                        let tabId = enabledTabs[selectedTab]
                        switch tabId {
                        case "files":
                            if config.isFilesEnabled {
                                FilesView()
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        case "clipboard":
                            if config.isClipboardEnabled {
                                ClipboardView()
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        case "notes":
                            if config.isNotesEnabled {
                                NotesView()
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
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
            startConfigMonitoring()
        }
        .onDisappear {
            stopConfigMonitoring()
        }
        .onChange(of: config.isFilesEnabled) { _, _ in 
            DispatchQueue.main.async {
                adjustSelectedTab()
            }
        }
        .onChange(of: config.isClipboardEnabled) { _, _ in 
            DispatchQueue.main.async {
                adjustSelectedTab()
            }
        }
        .onChange(of: config.isNotesEnabled) { _, _ in 
            DispatchQueue.main.async {
                adjustSelectedTab()
            }
        }
        .onChange(of: config.tabsOrder) { _, _ in
            DispatchQueue.main.async {
                adjustSelectedTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 应用激活时检查配置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                adjustSelectedTab()
            }
        }
    }
    
    // 配置监控定时器
    private func startConfigMonitoring() {
        configMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let currentHash = config.isFilesEnabled.hashValue ^ config.isClipboardEnabled.hashValue ^ config.isNotesEnabled.hashValue
            if currentHash != lastConfigHash {
                DispatchQueue.main.async {
                    lastConfigHash = currentHash
                    adjustSelectedTab()
                }
            }
        }
    }
    
    private func stopConfigMonitoring() {
        configMonitorTimer?.invalidate()
        configMonitorTimer = nil
    }
    
    // 获取启用的功能数量
    private func getEnabledViewCount() -> Int {
        return config.enabledTabsOrder.count
    }
    
    // 调整选中的标签页
    private func adjustSelectedTab() {
        let enabledCount = getEnabledViewCount()
        if enabledCount == 0 {
            selectedTab = 0
            return
        }
        
        // 使用配置的默认标签页
        let defaultIndex = config.defaultTabIndex
        if defaultIndex < enabledCount {
            selectedTab = defaultIndex
        } else {
            selectedTab = 0
        }
        
        // 确保selectedTab在有效范围内
        if selectedTab >= enabledCount {
            selectedTab = 0
        }
        
        // 调试信息
        #if DEBUG
        print("DEBUG: adjustSelectedTab - enabledCount: \(enabledCount), selectedTab: \(selectedTab), enabledTabs: \(config.enabledTabsOrder)")
        #endif
    }
    
    // 获取标签页标题
    private func getTabTitle(for tabId: String) -> String {
        switch tabId {
        case "files":
            return "tab.files".localized
        case "clipboard":
            return "tab.clipboard".localized
        case "notes":
            return "tab.notes".localized
        default:
            return ""
        }
    }
    
    // 获取标签页图标
    private func getTabIcon(for tabId: String) -> String {
        switch tabId {
        case "files":
            return "folder"
        case "clipboard":
            return "doc.on.clipboard"
        case "notes":
            return "note.text"
        default:
            return ""
        }
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.1) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered && !isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: isHovered ? Color.black.opacity(0.1) : Color.clear, radius: 2, x: 0, y: 1)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

// 扩展Button以支持按下事件
extension View {
    func pressEvents(onPress: @escaping () -> Void = {}, onRelease: @escaping () -> Void = {}) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    MainContentView()
        .frame(width: 800, height: 300)
}
#endif