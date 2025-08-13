import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var config = ConfigurationManager.shared
    @State private var refreshID = UUID()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 通用设置
            generalSettingsTab
                .tabItem {
                    Label("preferences.tab.general".localized, systemImage: "gearshape")
                }
                .tag(0)
            
            // 功能设置
            featuresSettingsTab
                .tabItem {
                    Label("preferences.tab.features".localized, systemImage: "square.stack.3d.up")
                }
                .tag(1)
            
            // 存储设置
            storageSettingsTab
                .tabItem {
                    Label("preferences.tab.storage".localized, systemImage: "externaldrive")
                }
                .tag(2)
            
            // 高级设置
            advancedSettingsTab
                .tabItem {
                    Label("preferences.tab.advanced".localized, systemImage: "wrench.and.screwdriver")
                }
                .tag(3)
        }
        .padding(20)
        .frame(width: 650, height: 500)
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
        }
    }
    
    // MARK: - 功能设置标签页
    private var featuresSettingsTab: some View {
        Form {
            // 功能开关
            Section("preferences.section.features".localized) {
                Toggle("preferences.features.enable_files".localized, isOn: $config.isFilesEnabled)
                Toggle("preferences.features.enable_clipboard".localized, isOn: $config.isClipboardEnabled)
                Toggle("preferences.features.enable_notes".localized, isOn: $config.isNotesEnabled)
                
                Text("preferences.features.description".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
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
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
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
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
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
}