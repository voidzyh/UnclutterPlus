import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var config = ConfigurationManager.shared
    @State private var refreshID = UUID()
    
    private enum PreferenceCategory: String, CaseIterable, Identifiable {
        case general
        case features
        case storage
        case advanced
        
        var id: String { rawValue }
        
        var titleKey: String {
            switch self {
            case .general: return "preferences.tab.general"
            case .features: return "preferences.tab.features"
            case .storage: return "preferences.tab.storage"
            case .advanced: return "preferences.tab.advanced"
            }
        }
        
        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .features: return "square.stack.3d.up"
            case .storage: return "externaldrive"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }
    
    @State private var selectedCategory: PreferenceCategory = .general
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧分类列表
            List(selection: $selectedCategory) {
                ForEach(PreferenceCategory.allCases) { category in
                    Label(category.titleKey.localized, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 220)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // 右侧详情
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedCategory {
                    case .general:
                        generalSettingsTab
                    case .features:
                        featuresSettingsTab
                    case .storage:
                        storageSettingsTab
                    case .advanced:
                        advancedSettingsTab
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 760, height: 520)
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
    
    // MARK: - 通用设置标签页
    private var generalSettingsTab: some View {
        Form {
            // 语言设置
            Section("preferences.section.language".localized) {
                Picker("preferences.language.select".localized, selection: $localizationManager.currentLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Text("preferences.language.restart_required".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 版本信息与更新
            Section("preferences.section.updates".localized) {
                HStack {
                    Text("preferences.updates.current_version".localized)
                    Spacer()
                    Text(currentAppVersion)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                HStack(spacing: 12) {
                    Button("preferences.updates.check_now".localized) {
                        Task { await UpdateManager.shared.checkForUpdates(force: true) }
                    }
                    if let info = UpdateManager.shared.updateInfo, info.isNewerThanCurrent {
                        Text("update.available.title".localized)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // 外观设置
            Section("preferences.section.appearance".localized) {
                Toggle("preferences.appearance.show_menubar".localized, isOn: $prefs.showMenuBarIcon)
                
                if !prefs.showMenuBarIcon {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("preferences.appearance.menubar_hidden_info".localized, systemImage: "info.circle")
                        Text("preferences.appearance.menubar_hidden_tip1".localized)
                        Text("preferences.appearance.menubar_hidden_tip2".localized)
                        Text("preferences.appearance.menubar_hidden_tip3".localized)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                }
            }
            
            // 交互设置
            Section("preferences.section.interaction".localized) {
                Picker("preferences.mouse.scroll_mode".localized, selection: $prefs.mouseScrollMode) {
                    ForEach(MouseScrollMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text("preferences.trackpad.help".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 窗口行为设置
            Section("preferences.section.window_behavior".localized) {
                Toggle("preferences.window.auto_hide_after_action".localized, isOn: $config.autoHideAfterAction)
                    .help("preferences.window.auto_hide_after_action.help".localized)
                
                Toggle("preferences.window.hide_on_lost_focus".localized, isOn: $config.hideOnLostFocus)
                    .help("preferences.window.hide_on_lost_focus.help".localized)
                
                if config.autoHideAfterAction || config.hideOnLostFocus {
                    HStack {
                        Text("preferences.window.hide_delay".localized)
                        Slider(value: $config.hideDelay, in: 0...2, step: 0.1)
                            .frame(width: 200)
                        Text("\(config.hideDelay, specifier: "%.1f") \("common.seconds".localized)")
                            .frame(width: 60, alignment: .leading)
                    }
                }
            }
        }
    }
    
    // MARK: - 功能设置标签页
    private var featuresSettingsTab: some View {
        Form {
            // 标签页设置（集成开关 + 顺序 + 默认）
            Section("preferences.section.tabs".localized) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("preferences.tabs.order.description".localized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    // 标签页顺序与开关、默认一体化设置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("preferences.tabs.order.title".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TabOrderEditor(
                            order: $config.tabsOrder,
                            defaultTab: $config.defaultTab,
                            isFilesEnabled: $config.isFilesEnabled,
                            isClipboardEnabled: $config.isClipboardEnabled,
                            isNotesEnabled: $config.isNotesEnabled
                        )
                    }
                }
            }
            
            // 笔记设置
            Section("preferences.section.notes".localized) {
                HStack {
                    Text("preferences.notes.autosave_interval".localized)
                    Spacer()
                    Text(String(format: "%.1fs", prefs.notesAutoSaveInterval))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Slider(value: $prefs.notesAutoSaveInterval, in: 0.5...10.0, step: 0.5)
                
                Text("preferences.notes.autosave_help".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // Markdown 设置
            Section("preferences.section.markdown".localized) {
                Picker("preferences.markdown.theme".localized, selection: $prefs.markdownTheme) {
                    ForEach(MarkdownThemeOption.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                
                Picker("preferences.markdown.code_highlight".localized, selection: $prefs.codeHighlightTheme) {
                    ForEach(CodeHighlightThemeOption.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }
        }
    }
    
    // MARK: - 存储设置标签页
    private var storageSettingsTab: some View {
        Form {
            // 文件存储位置
            Section("preferences.storage.files_location".localized) {
                Toggle("preferences.storage.custom_path".localized, isOn: $config.useCustomFilesPath)
                
                HStack {
                    TextField("", text: .constant(config.filesCustomPathDisplay))
                        .disabled(true)
                    
                    Button("preferences.storage.choose_folder".localized) {
                        selectFolder { url in
                            config.setFilesCustomPath(url.path)
                        }
                    }
                    .disabled(!config.useCustomFilesPath)
                }
                
                storageInfo(
                    path: config.filesStoragePath,
                    usage: config.getStorageUsage(for: config.filesStoragePath),
                    showDefault: !config.useCustomFilesPath
                )
            }
            
            // 剪贴板存储位置
            Section("preferences.storage.clipboard_location".localized) {
                Toggle("preferences.storage.custom_path".localized, isOn: $config.useCustomClipboardPath)
                
                HStack {
                    TextField("", text: .constant(config.clipboardCustomPathDisplay))
                        .disabled(true)
                    
                    Button("preferences.storage.choose_folder".localized) {
                        selectFolder { url in
                            config.setClipboardCustomPath(url.path)
                        }
                    }
                    .disabled(!config.useCustomClipboardPath)
                }
                
                storageInfo(
                    path: config.clipboardStoragePath,
                    usage: config.getStorageUsage(for: config.clipboardStoragePath),
                    showDefault: !config.useCustomClipboardPath
                )
                
                // 剪贴板配置选项
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("preferences.clipboard.max_age".localized)
                        Spacer()
                        Text("\(Int(config.clipboardMaxAge / (24 * 60 * 60))) \("preferences.clipboard.days".localized)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $config.clipboardMaxAge, in: 7 * 24 * 60 * 60...365 * 24 * 60 * 60, step: 24 * 60 * 60)
                        .frame(width: 200)
                    
                    Text("preferences.clipboard.max_age_help".localized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Toggle("preferences.clipboard.show_use_count".localized, isOn: $config.showUseCount)
                        .help("preferences.clipboard.show_use_count_help".localized)
                    
                    Toggle("preferences.clipboard.auto_cleanup".localized, isOn: .constant(true))
                        .disabled(true)
                        .help("preferences.clipboard.auto_cleanup_help".localized)
                    
                    // 启动默认筛选器配置
                    Picker("preferences.clipboard.default_filter".localized, selection: $config.clipboardDefaultFilter) {
                        Text("preferences.clipboard.persistent.type".localized).tag("type")
                        Text("preferences.clipboard.persistent.date".localized).tag("date")
                        Text("preferences.clipboard.persistent.source".localized).tag("source")
                        Text("preferences.clipboard.persistent.sort".localized).tag("sort")
                    }
                    .help("preferences.clipboard.persistent_filter.help".localized)
                }
                .padding(.top, 8)
            }
            
            // 笔记存储位置
            Section("preferences.storage.notes_location".localized) {
                Toggle("preferences.storage.custom_path".localized, isOn: $config.useCustomNotesPath)
                
                HStack {
                    TextField("", text: .constant(config.notesCustomPathDisplay))
                        .disabled(true)
                    
                    Button("preferences.storage.choose_folder".localized) {
                        selectFolder { url in
                            config.setNotesCustomPath(url.path)
                        }
                    }
                    .disabled(!config.useCustomNotesPath)
                }
                
                storageInfo(
                    path: config.notesStoragePath,
                    usage: config.getStorageUsage(for: config.notesStoragePath),
                    showDefault: !config.useCustomNotesPath
                )
            }
            
            // 数据管理
            Section("preferences.section.data_management".localized) {
                Button("preferences.storage.reset_paths".localized) {
                    config.resetToDefaults()
                }
                .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - 高级设置标签页
    private var advancedSettingsTab: some View {
        Form {
            // 开发者选项
            Section("preferences.section.developer".localized) {
                Toggle("preferences.base_url.enable".localized, isOn: $prefs.enableBaseURL)
                
                TextField("https://example.com/assets/", text: $prefs.baseURLString)
                    .disabled(!prefs.enableBaseURL)
                
                Text("preferences.base_url.help".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 数据管理
            Section("preferences.section.data_management".localized) {
                HStack {
                    Button("preferences.data.clear_files".localized) {
                        showClearConfirmation { clearAllFiles() }
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("preferences.data.clear_clipboard".localized) {
                        showClearConfirmation { clearClipboardHistory() }
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("preferences.data.clear_notes".localized) {
                        showClearConfirmation { clearAllNotes() }
                    }
                    .foregroundColor(.red)
                }
                
                Divider()
                
                Button("preferences.data.reset_all".localized) {
                    showResetConfirmation()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Helper Views
    private func storageInfo(path: URL, usage: Int64, showDefault: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if showDefault {
                HStack {
                    Text("preferences.storage.default_path".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(path.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            HStack {
                Text("preferences.storage.space_used".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(config.formatFileSize(usage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func selectFolder(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "preferences.storage.choose_folder".localized
        panel.message = "preferences.storage.choose_folder".localized
        
        // 设置正确的父窗口，避免被遮挡
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    if self.config.validatePath(url.path) {
                        completion(url)
                    } else {
                        self.showPathError()
                    }
                }
            }
        } else {
            // 如果没有找到窗口，使用模态方式
            if panel.runModal() == .OK, let url = panel.url {
                if config.validatePath(url.path) {
                    completion(url)
                } else {
                    showPathError()
                }
            }
        }
    }
    
    private func showPathError() {
        let alert = NSAlert()
        alert.messageText = "preferences.storage.invalid_path".localized
        alert.informativeText = "preferences.storage.path_not_writable".localized
        alert.alertStyle = .warning
        
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
    
    private func showClearConfirmation(action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "preferences.data.clear_confirm".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "alert.ok".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    action()
                }
            }
        } else {
            if alert.runModal() == .alertFirstButtonReturn {
                action()
            }
        }
    }
    
    private func showResetConfirmation() {
        let alert = NSAlert()
        alert.messageText = "preferences.data.reset_confirm".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "alert.reset".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        
        let resetAction = {
            self.config.resetToDefaults()
            self.prefs.markdownTheme = .gitHub
            self.prefs.codeHighlightTheme = .sunset
            self.prefs.notesAutoSaveInterval = 2.0
            self.prefs.showMenuBarIcon = true
            self.prefs.enableBaseURL = false
            self.prefs.baseURLString = ""
        }
        
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    resetAction()
                }
            }
        } else {
            if alert.runModal() == .alertFirstButtonReturn {
                resetAction()
            }
        }
    }
    
    private func clearAllFiles() {
        // 实现清除所有文件的逻辑
        let fileManager = TempFileManager()
        fileManager.clearAllFiles()
    }
    
    private func clearClipboardHistory() {
        // 实现清除剪贴板历史的逻辑
        let clipboardManager = ClipboardManager()
        clipboardManager.clearAll()
    }
    
    private func clearAllNotes() {
        // 实现清除所有笔记的逻辑
        NotesManager.shared.deleteAllNotes()
    }
    
    // MARK: - Helper Methods for Tab Management
    
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
    
    // 获取标签页颜色
    private func getTabColor(for tabId: String) -> Color {
        switch tabId {
        case "files":
            return .blue
        case "clipboard":
            return .green
        case "notes":
            return .orange
        default:
            return .secondary
        }
    }
}

// MARK: - Tab Order Editor Component
struct TabOrderEditor: View {
    @Binding var order: String
    @Binding var defaultTab: String
    @Binding var isFilesEnabled: Bool
    @Binding var isClipboardEnabled: Bool
    @Binding var isNotesEnabled: Bool
    @State private var tabItems: [TabItem] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("preferences.tabs.order.help".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            
            ForEach(tabItems.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    // 序号徽章
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .accessibilityLabel("preferences.tabs.order.index \(index + 1)")
                    
                    // 图标 + 标题
                    HStack(spacing: 6) {
                        Image(systemName: tabItems[index].systemImage)
                            .foregroundColor(tabItems[index].color)
                            .font(.system(size: 12))
                        Text(tabItems[index].title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer(minLength: 8)
                    
                    // 功能启用开关
                    enableToggle(for: tabItems[index].id)
                    
                    // 设为默认星标（仅当启用时可用）
                    Button(action: { defaultTab = tabItems[index].id }) {
                        Image(systemName: defaultTab == tabItems[index].id ? "star.fill" : "star")
                            .foregroundColor(defaultTab == tabItems[index].id ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isEnabled(for: tabItems[index].id))
                    .help("preferences.tabs.default.make_default".localized)
                    
                    // 上/下移动（仅当启用时参与排序）
                    HStack(spacing: 4) {
                        Button(action: { moveTabUp(from: index) }) {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .foregroundColor(index > 0 ? .primary : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        
                        Button(action: { moveTabDown(from: index) }) {
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(index < tabItems.count - 1 ? .primary : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == tabItems.count - 1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            
            HStack(spacing: 8) {
                Button("preferences.tabs.order.reset".localized) { resetToDefaultOrder() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
                Spacer()
                // 预览徽章（仅显示启用的）
                HStack(spacing: 6) {
                    ForEach(tabItems.filter { isEnabled(for: $0.id) }, id: \.id) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.systemImage)
                                .foregroundColor(item.color)
                            Text(item.title)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.06), in: Capsule())
                    }
                }
            }
        }
        .onAppear { loadTabItems() }
        .onChange(of: order) { _, _ in loadTabItems() }
        .onChange(of: isFilesEnabled) { _, _ in clampDefaultAndOrder() }
        .onChange(of: isClipboardEnabled) { _, _ in clampDefaultAndOrder() }
        .onChange(of: isNotesEnabled) { _, _ in clampDefaultAndOrder() }
    }
    
    @ViewBuilder
    private func enableToggle(for id: String) -> some View {
        switch id {
        case "files": Toggle("", isOn: $isFilesEnabled).labelsHidden().help("preferences.features.enable_files".localized)
        case "clipboard": Toggle("", isOn: $isClipboardEnabled).labelsHidden().help("preferences.features.enable_clipboard".localized)
        case "notes": Toggle("", isOn: $isNotesEnabled).labelsHidden().help("preferences.features.enable_notes".localized)
        default: EmptyView()
        }
    }
    
    private func isEnabled(for id: String) -> Bool {
        switch id {
        case "files": return isFilesEnabled
        case "clipboard": return isClipboardEnabled
        case "notes": return isNotesEnabled
        default: return false
        }
    }
    
    private func loadTabItems() {
        let orderArray = order.components(separatedBy: ",")
        tabItems = orderArray.compactMap { tabId in
            switch tabId { case "files": return TabItem(id: "files", title: "tab.files".localized, systemImage: "folder", color: .blue)
            case "clipboard": return TabItem(id: "clipboard", title: "tab.clipboard".localized, systemImage: "doc.on.clipboard", color: .green)
            case "notes": return TabItem(id: "notes", title: "tab.notes".localized, systemImage: "note.text", color: .orange)
            default: return nil }
        }
    }
    
    private func moveTabUp(from index: Int) {
        guard index > 0 else { return }
        tabItems.swapAt(index, index - 1)
        updateOrder()
    }
    
    private func moveTabDown(from index: Int) {
        guard index < tabItems.count - 1 else { return }
        tabItems.swapAt(index, index + 1)
        updateOrder()
    }
    
    private func resetToDefaultOrder() {
        tabItems = [
            TabItem(id: "files", title: "tab.files".localized, systemImage: "folder", color: .blue),
            TabItem(id: "clipboard", title: "tab.clipboard".localized, systemImage: "doc.on.clipboard", color: .green),
            TabItem(id: "notes", title: "tab.notes".localized, systemImage: "note.text", color: .orange)
        ]
        if !isEnabled(for: defaultTab) { defaultTab = tabItems.first(where: { isEnabled(for: $0.id) })?.id ?? "files" }
        updateOrder()
    }
    
    private func updateOrder() {
        let newOrder = tabItems.map { $0.id }.joined(separator: ",")
        order = newOrder
        // 如果默认标签对应功能被关闭，降级为第一个启用项
        if !isEnabled(for: defaultTab) {
            defaultTab = tabItems.first(where: { isEnabled(for: $0.id) })?.id ?? "files"
        }
    }
    
    private func clampDefaultAndOrder() {
        // 关闭的功能仍保留在顺序中，但默认与预览仅依据启用项
        if !isEnabled(for: defaultTab) {
            defaultTab = tabItems.first(where: { isEnabled(for: $0.id) })?.id ?? "files"
        }
    }
}

struct TabItem {
    let id: String
    let title: String
    let systemImage: String
    let color: Color
}