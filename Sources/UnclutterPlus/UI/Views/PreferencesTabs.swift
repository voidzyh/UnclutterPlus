import SwiftUI
import AppKit

// MARK: - 设置标签页（自 PreferencesView 拆分，5 个 tab 各居其位）

extension PreferencesView {

    // MARK: - 通用设置标签页
    var generalSettingsTab: some View {
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

                Divider()

                Picker("preferences.scroll_direction.title".localized, selection: $config.scrollDirectionMapping) {
                    ForEach(ScrollDirectionMapping.allCases) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }
                Text("preferences.scroll_direction.help".localized)
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
    var featuresSettingsTab: some View {
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

            // Markdown 设置（使用渐进式披露）
            Section("preferences.section.markdown".localized) {
                DisclosureGroup("preferences.markdown.advanced".localized, isExpanded: .constant(false)) {
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
    }
    
    // MARK: - 存储设置标签页
    var storageSettingsTab: some View {
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
                    
                    Toggle("preferences.clipboard.ignore_concealed".localized, isOn: $config.clipboardIgnoreConcealed)
                        .help("preferences.clipboard.ignore_concealed_help".localized)
                    
                    Toggle("preferences.clipboard.ignore_transient".localized, isOn: $config.clipboardIgnoreTransient)
                        .help("preferences.clipboard.ignore_transient_help".localized)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("preferences.clipboard.excluded_apps".localized)
                        TextField("preferences.clipboard.excluded_apps_placeholder".localized, text: $config.clipboardExcludedApps)
                            .textFieldStyle(.roundedBorder)
                        Text("preferences.clipboard.excluded_apps_help".localized)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("preferences.clipboard.merge_separator".localized)
                        TextField("\\n", text: $config.clipboardMergeSeparator)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .help("preferences.clipboard.merge_separator_help".localized)
                    
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
    var integrationSettingsTab: some View {
        Form {
            // MARK: - AI 服务
            Section("preferences.ai.section".localized) {
                Picker("preferences.ai.type".localized, selection: $config.aiServiceType) {
                    Text("preferences.ai.type.http".localized).tag("http")
                    Text("preferences.ai.type.cli".localized).tag("cli")
                }
                .pickerStyle(.segmented)

                if config.aiServiceType == "http" {
                    TextField("preferences.ai.endpoint".localized, text: $config.aiEndpoint)
                        .autocorrectionDisabled()

                    SecureField("preferences.ai.api_key".localized, text: $aiAPIKeyInput)
                        .autocorrectionDisabled()
                        .onAppear { aiAPIKeyInput = config.aiAPIKey }
                        .onChange(of: aiAPIKeyInput) { _, newValue in
                            config.aiAPIKey = newValue
                        }

                    TextField("preferences.ai.model".localized, text: $config.aiModel)
                } else {
                    TextField("preferences.ai.cli_path".localized, text: $config.aiCliPath)
                    TextField("preferences.ai.cli_model".localized, text: $config.aiCliModel)
                }

                HStack {
                    Text("preferences.ai.timeout".localized)
                    Spacer()
                    Slider(value: $config.aiTimeout, in: 10...180, step: 5) {
                        Text("preferences.ai.timeout".localized)
                    }
                    Text("\(Int(config.aiTimeout))s")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                if AIServiceFactory.isConfigured {
                    Label("preferences.ai.configured".localized, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("preferences.ai.not_configured".localized, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // MARK: - Obsidian
            Section("preferences.obsidian.section".localized) {
                TextField("preferences.obsidian.vault_path".localized, text: $config.obsidianVaultPath)
                    .disabled(true)
                HStack {
                    Button("preferences.storage.choose_folder".localized) {
                        selectFolder { url in
                            config.obsidianVaultPath = url.path
                        }
                    }
                    if !config.obsidianVaultPath.isEmpty {
                        Button("preferences.storage.reveal".localized) {
                            NSWorkspace.shared.open(URL(fileURLWithPath: config.obsidianVaultPath))
                        }
                    }
                }

                TextField("preferences.obsidian.vault_name".localized, text: $config.obsidianVaultName)
                    .help("preferences.obsidian.vault_name.help".localized)
            }

            // MARK: - OCR（补全：此前定义但无 UI）
            Section("preferences.ocr.section".localized) {
                Picker("preferences.ocr.engine".localized, selection: $config.ocrEngineType) {
                    Text("preferences.ocr.engine.vision".localized).tag("vision")
                    Text("preferences.ocr.engine.cli".localized).tag("cli")
                }
                .help("preferences.ocr.engine.help".localized)
                TextField("preferences.ocr.deepseek_path".localized, text: $config.deepseekBinaryPath)
                    .disabled(config.ocrEngineType != "cli")
                TextField("preferences.ocr.deepseek_langs".localized, text: $config.deepseekLanguages)
                    .help("preferences.ocr.deepseek_langs.help".localized)
                Toggle("preferences.ocr.auto".localized, isOn: $config.ocrAutoEnabled)
            }
        }
    }

    var advancedSettingsTab: some View {
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
        // 实现清除所有文件夹的逻辑
        let foldersManager = FavoriteFoldersManager()
        foldersManager.clearAllFolders()
    }
    
    private func clearClipboardHistory() {
        // 使用新的 Repository 清空剪贴板历史
        Task { @MainActor in
            await AppStorageManager.shared.clipboardRepository.clearAll()
        }
    }
    
    private func clearAllNotes() {
        Task { @MainActor in
            let notes = await AppStorageManager.shared.notesService.getAllNotes()
            _ = await AppStorageManager.shared.notesService.deleteNotes(notes)
        }
    }
}
