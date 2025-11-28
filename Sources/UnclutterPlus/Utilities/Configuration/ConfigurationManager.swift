import Foundation
import SwiftUI

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

    // 截图管理设置
    // 全局快捷键（存储为字符串，如 "command-shift-1"），空字符串代表未设置
    @AppStorage("screenshots.hotkey.region") var screenshotsHotkeyRegion: String = "command-shift-1"
    @AppStorage("screenshots.hotkey.window") var screenshotsHotkeyWindow: String = "command-shift-2"
    // OCR 配置
    @AppStorage("ocr.deepseek.path") var deepseekBinaryPath: String = "" // 例如 /usr/local/bin/deepseek-ocr
    @AppStorage("ocr.deepseek.langs") var deepseekLanguages: String = "zh,en" // 逗号分隔
    @AppStorage("ocr.auto") var ocrAutoEnabled: Bool = true
    
    // 标签页顺序和默认设置
    @AppStorage("tabs.order") var tabsOrder: String = "files,clipboard,notes" // 默认顺序：文件、粘贴板、笔记
    @AppStorage("tabs.defaultTab") var defaultTab: String = "files" // 默认标签页：files, clipboard, notes
    
    private init() {}
    
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
            print("Failed to create directory at \(url): \(error)")
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
        isFilesEnabled = false
        isClipboardEnabled = true
        isNotesEnabled = true
        isScreenshotsEnabled = true
        
        useCustomFilesPath = false
        useCustomClipboardPath = false
        useCustomNotesPath = false
        useCustomScreenshotsPath = false
        
        filesCustomPath = ""
        clipboardCustomPath = ""
        notesCustomPath = ""
        screenshotsCustomPath = ""
        
        // 重置标签页设置
        tabsOrder = "screenshots,clipboard,notes"
        defaultTab = "screenshots"
        
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