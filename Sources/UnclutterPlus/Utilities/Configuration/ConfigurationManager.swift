import Foundation
import SwiftUI

/// 滚动方向映射选项
enum ScrollDirectionMapping: String, CaseIterable, Identifiable {
    case upToShow           // 向上显示，向下隐藏（默认）
    case downToShow         // 向下显示，向上隐藏
    case natural            // 自然模式（根据窗口位置自动判断）

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upToShow:
            return "preferences.scroll_direction.up_to_show".localized  // "向上显示"
        case .downToShow:
            return "preferences.scroll_direction.down_to_show".localized  // "向下显示"
        case .natural:
            return "preferences.scroll_direction.natural".localized  // "自然模式"
        }
    }
}

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    // 功能开关
    @AppStorage("feature.files.enabled") var isFilesEnabled: Bool = true
    @AppStorage("feature.clipboard.enabled") var isClipboardEnabled: Bool = true
    @AppStorage("feature.notes.enabled") var isNotesEnabled: Bool = true
    @AppStorage("feature.screenshots.enabled") var isScreenshotsEnabled: Bool = true
    
    // 存储路径
    @AppStorage("storage.files.customPath") private var filesCustomPath: String = ""
    @AppStorage("storage.clipboard.customPath") private var clipboardCustomPath: String = ""
    @AppStorage("storage.notes.customPath") private var notesCustomPath: String = ""
    @AppStorage("storage.screenshots.customPath") private var screenshotsCustomPath: String = ""
    
    // 使用自定义路径
    @AppStorage("storage.files.useCustomPath") var useCustomFilesPath: Bool = false
    @AppStorage("storage.clipboard.useCustomPath") var useCustomClipboardPath: Bool = false
    @AppStorage("storage.notes.useCustomPath") var useCustomNotesPath: Bool = false
    @AppStorage("storage.screenshots.useCustomPath") var useCustomScreenshotsPath: Bool = false
    
    // 窗口自动隐藏设置
    @AppStorage("window.autoHideAfterAction") var autoHideAfterAction: Bool = true
    @AppStorage("window.hideOnLostFocus") var hideOnLostFocus: Bool = true
    @AppStorage("window.hideDelay") var hideDelay: Double = 0.5
    
    // 剪贴板设置
    @AppStorage("clipboard.maxAge") var clipboardMaxAge: TimeInterval = 30 * 24 * 60 * 60 // 30天
    @AppStorage("clipboard.showUseCount") var showUseCount: Bool = true
    @AppStorage("clipboard.sortBy") var clipboardSortBy: String = "time" // "time", "useCount"
    // 启动默认筛选器：type/date/source/sort (启动时默认展开类型筛选)
    @AppStorage("clipboard.defaultFilter") var clipboardDefaultFilter: String = "type"
    // 剪贴板监听设置（智能洞察数据源）
    @AppStorage("clipboard.monitor.enabled") var clipboardMonitorEnabled: Bool = true
    @AppStorage("clipboard.monitor.interval") var clipboardMonitorInterval: Double = 0.5 // 轮询间隔（秒）
    // 敏感内容忽略：密码管理器标记（ConcealedType / 1Password）与瞬态内容
    @AppStorage("clipboard.ignore.concealed") var clipboardIgnoreConcealed: Bool = true
    @AppStorage("clipboard.ignore.transient") var clipboardIgnoreTransient: Bool = true
    // 应用排除规则：逗号分隔的 bundle ID（如 com.1password.1password），来自这些应用的复制内容不入库
    @AppStorage("clipboard.excludedApps") var clipboardExcludedApps: String = ""
    /// 解析后的排除应用 bundle ID 集合（小写、去空白）
    var clipboardExcludedAppIDs: Set<String> {
        Set(
            clipboardExcludedApps
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
    // 频率阈值：粘贴次数达到该值的片段视为"高频"
    @AppStorage("clipboard.insights.frequencyThreshold") var insightsFrequencyThreshold: Int = 3
    // 合并粘贴的分隔符（多项选择的剪贴板内容按此分隔拼接）
    @AppStorage("clipboard.mergeSeparator") var clipboardMergeSeparator: String = "\n"

    // 截图管理设置
    // 全局快捷键（存储为字符串，如 "command-shift-1"），空字符串代表未设置
    @AppStorage("screenshots.hotkey.region") var screenshotsHotkeyRegion: String = "command-shift-1"
    @AppStorage("screenshots.hotkey.window") var screenshotsHotkeyWindow: String = "command-shift-2"
    // OCR 配置
    @AppStorage("ocr.deepseek.path") var deepseekBinaryPath: String = "" // 例如 /usr/local/bin/deepseek-ocr
    @AppStorage("ocr.deepseek.langs") var deepseekLanguages: String = "zh,en" // 逗号分隔
    @AppStorage("ocr.auto") var ocrAutoEnabled: Bool = true
    // OCR 引擎："vision"（本地 Vision，默认）或 "cli"（Deepseek 外部二进制）
    @AppStorage("ocr.engine") var ocrEngineType: String = "vision"

    // AI 服务设置（智能整理 / 聚类总结）
    // 实现类型："http" (OpenAI 兼容 API) 或 "cli" (本地命令行如 ollama)
    @AppStorage("ai.service.type") var aiServiceType: String = "http"
    @AppStorage("ai.service.endpoint") var aiEndpoint: String = "" // 如 https://api.openai.com/v1/chat/completions
    @AppStorage("ai.service.model") var aiModel: String = "gpt-4o-mini"
    // CLI 模式下的可执行文件路径（如 /usr/local/bin/ollama）
    @AppStorage("ai.service.cliPath") var aiCliPath: String = ""
    @AppStorage("ai.service.cliModel") var aiCliModel: String = "" // 如 llama3.2
    // 请求超时（秒）
    @AppStorage("ai.service.timeout") var aiTimeout: Double = 60

    // Obsidian 集成设置
    @AppStorage("obsidian.vault.path") var obsidianVaultPath: String = ""
    @AppStorage("obsidian.vault.name") var obsidianVaultName: String = "" // 用于构造 obsidian:// URI

    /// AI API Key —— 存储在 Keychain（非明文 UserDefaults）。
    /// getter/setter 作为 @AppStorage 的安全替代。
    var aiAPIKey: String {
        get { KeychainWrapper.get(forAccount: "ai.apikey") ?? "" }
        set { KeychainWrapper.set(newValue, forAccount: "ai.apikey") }
    }
    
    // 标签页顺序和默认设置
    @AppStorage("tabs.order") var tabsOrder: String = "files,clipboard,notes" // 默认顺序：文件、粘贴板、笔记
    @AppStorage("tabs.defaultTab") var defaultTab: String = "files" // 默认标签页：files, clipboard, notes

    // 菜单栏设置
    @AppStorage("ui.menuBarIcon.enabled") var isMenuBarIconEnabled: Bool = true

    // 滚动方向映射设置
    @AppStorage("ui.scrollDirectionMapping") var scrollDirectionMapping: ScrollDirectionMapping = .upToShow

    private init() {
        // 延迟初始化检查，确保 @AppStorage 已加载完成
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let defaults = UserDefaults.standard

            // 检查所有功能是否都未启用（使用UserDefaults直接读取）
            let filesEnabled = defaults.bool(forKey: "feature.files.enabled")
            let clipboardEnabled = defaults.bool(forKey: "feature.clipboard.enabled")
            let notesEnabled = defaults.bool(forKey: "feature.notes.enabled")

            if !filesEnabled && !clipboardEnabled && !notesEnabled {
                self.isFilesEnabled = true
                self.isClipboardEnabled = true
                self.isNotesEnabled = true

                // 确保默认标签页有效
                if self.defaultTab.isEmpty {
                    self.defaultTab = "files"
                }

                // 确保排序有效
                if self.tabsOrder.isEmpty {
                    self.tabsOrder = "files,clipboard,notes"
                }
            }
        }
    }
    
    // 默认路径
    private var defaultBasePath: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("UnclutterPlus")
    }
    
    // 获取文件存储路径
    var filesStoragePath: URL {
        if useCustomFilesPath && !filesCustomPath.isEmpty {
            let customURL = URL(fileURLWithPath: filesCustomPath)
                .appendingPathComponent("UnclutterPlus_Files")
            createDirectoryIfNeeded(at: customURL)
            return customURL
        } else {
            let defaultURL = defaultBasePath.appendingPathComponent("Files")
            createDirectoryIfNeeded(at: defaultURL)
            return defaultURL
        }
    }
    
    // 获取剪贴板存储路径
    var clipboardStoragePath: URL {
        if useCustomClipboardPath && !clipboardCustomPath.isEmpty {
            let customURL = URL(fileURLWithPath: clipboardCustomPath)
                .appendingPathComponent("UnclutterPlus_Clipboard")
            createDirectoryIfNeeded(at: customURL)
            return customURL
        } else {
            let defaultURL = defaultBasePath.appendingPathComponent("Clipboard")
            createDirectoryIfNeeded(at: defaultURL)
            return defaultURL
        }
    }
    
    // 获取笔记存储路径
    var notesStoragePath: URL {
        if useCustomNotesPath && !notesCustomPath.isEmpty {
            let customURL = URL(fileURLWithPath: notesCustomPath)
                .appendingPathComponent("UnclutterPlus_Notes")
            createDirectoryIfNeeded(at: customURL)
            return customURL
        } else {
            let defaultURL = defaultBasePath.appendingPathComponent("Notes")
            createDirectoryIfNeeded(at: defaultURL)
            return defaultURL
        }
    }

    // 获取截图存储路径
    var screenshotsStoragePath: URL {
        if useCustomScreenshotsPath && !screenshotsCustomPath.isEmpty {
            let customURL = URL(fileURLWithPath: screenshotsCustomPath)
                .appendingPathComponent("UnclutterPlus_Screenshots")
            createDirectoryIfNeeded(at: customURL)
            return customURL
        } else {
            let defaultURL = defaultBasePath.appendingPathComponent("Screenshots")
            createDirectoryIfNeeded(at: defaultURL)
            return defaultURL
        }
    }
    
    // 设置自定义路径
    func setFilesCustomPath(_ path: String) {
        filesCustomPath = path
        objectWillChange.send()
    }
    
    func setClipboardCustomPath(_ path: String) {
        clipboardCustomPath = path
        objectWillChange.send()
    }
    
    func setNotesCustomPath(_ path: String) {
        notesCustomPath = path
        objectWillChange.send()
    }
    
    func setScreenshotsCustomPath(_ path: String) {
        screenshotsCustomPath = path
        objectWillChange.send()
    }
    
    // 获取自定义路径（用于显示）
    var filesCustomPathDisplay: String {
        filesCustomPath.isEmpty ? "" : filesCustomPath
    }
    
    var clipboardCustomPathDisplay: String {
        clipboardCustomPath.isEmpty ? "" : clipboardCustomPath
    }
    
    var notesCustomPathDisplay: String {
        notesCustomPath.isEmpty ? "" : notesCustomPath
    }
    
    var screenshotsCustomPathDisplay: String {
        screenshotsCustomPath.isEmpty ? "" : screenshotsCustomPath
    }
    
    // 创建目录
    private func createDirectoryIfNeeded(at url: URL) {
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            logger.info("Failed to create directory at \(url): \(error)", category: "ConfigurationManager")
        }
    }
    
    // 验证路径是否可写
    func validatePath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        
        // 检查路径是否存在
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            // 尝试创建目录
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return false
            }
        } else if !isDirectory.boolValue {
            // 路径存在但不是目录
            return false
        }
        
        // 检查是否可写
        return FileManager.default.isWritableFile(atPath: url.path)
    }
    
    // 迁移数据到新路径
    func migrateFiles(from oldPath: URL, to newPath: URL) async throws {
        let fileManager = FileManager.default
        
        // 确保新路径存在
        try fileManager.createDirectory(at: newPath, withIntermediateDirectories: true, attributes: nil)
        
        // 获取所有文件
        let files = try fileManager.contentsOfDirectory(at: oldPath, includingPropertiesForKeys: nil)
        
        // 移动文件
        for file in files {
            let fileName = file.lastPathComponent
            let newFileURL = newPath.appendingPathComponent(fileName)
            
            // 如果目标文件已存在，先删除
            if fileManager.fileExists(atPath: newFileURL.path) {
                try fileManager.removeItem(at: newFileURL)
            }
            
            try fileManager.moveItem(at: file, to: newFileURL)
        }
    }
    
    // 获取存储空间使用情况
    func getStorageUsage(for path: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    // 格式化文件大小
    func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // 重置所有设置
    func resetToDefaults() {
        isFilesEnabled = true
        isClipboardEnabled = true
        isNotesEnabled = true
        isScreenshotsEnabled = false
        
        useCustomFilesPath = false
        useCustomClipboardPath = false
        useCustomNotesPath = false
        useCustomScreenshotsPath = false
        
        filesCustomPath = ""
        clipboardCustomPath = ""
        notesCustomPath = ""
        screenshotsCustomPath = ""
        
        // 重置标签页设置
        tabsOrder = "files,clipboard,notes"
        defaultTab = "files"
        
        objectWillChange.send()
    }
    
    // MARK: - 标签页顺序管理
    
    // 获取标签页顺序数组
    var tabsOrderArray: [String] {
        return tabsOrder.components(separatedBy: ",")
    }
    
    // 设置标签页顺序
    func setTabsOrder(_ order: [String]) {
        tabsOrder = order.joined(separator: ",")
        objectWillChange.send()
    }
    
    // 获取启用的标签页顺序
    var enabledTabsOrder: [String] {
        var enabledTabs: [String] = []
        
        if isFilesEnabled { enabledTabs.append("files") }
        if isScreenshotsEnabled { enabledTabs.append("screenshots") }
        if isClipboardEnabled { enabledTabs.append("clipboard") }
        if isNotesEnabled { enabledTabs.append("notes") }
        
        // 根据用户设置的顺序重新排列
        let userOrder = tabsOrderArray
        var orderedTabs: [String] = []
        
        // 先添加用户设置的顺序
        for tab in userOrder {
            if enabledTabs.contains(tab) {
                orderedTabs.append(tab)
            }
        }
        
        // 添加用户没有设置但已启用的标签页
        for tab in enabledTabs {
            if !orderedTabs.contains(tab) {
                orderedTabs.append(tab)
            }
        }
        
        return orderedTabs
    }
    
    // 获取默认标签页索引
    var defaultTabIndex: Int {
        let enabledTabs = enabledTabsOrder
        if let index = enabledTabs.firstIndex(of: defaultTab) {
            return index
        }
        return 0 // 如果默认标签页不可用，返回第一个
    }
    
    // 验证标签页顺序
    func validateTabsOrder(_ order: [String]) -> Bool {
        let validTabs = ["files", "screenshots", "clipboard", "notes"]
        return order.allSatisfy { validTabs.contains($0) }
    }
}