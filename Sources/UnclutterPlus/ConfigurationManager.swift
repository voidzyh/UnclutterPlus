import Foundation
import SwiftUI

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    // 功能开关
    @AppStorage("feature.files.enabled") var isFilesEnabled: Bool = true
    @AppStorage("feature.clipboard.enabled") var isClipboardEnabled: Bool = true
    @AppStorage("feature.notes.enabled") var isNotesEnabled: Bool = true
    
    // 存储路径
    @AppStorage("storage.files.customPath") private var filesCustomPath: String = ""
    @AppStorage("storage.clipboard.customPath") private var clipboardCustomPath: String = ""
    @AppStorage("storage.notes.customPath") private var notesCustomPath: String = ""
    
    // 使用自定义路径
    @AppStorage("storage.files.useCustomPath") var useCustomFilesPath: Bool = false
    @AppStorage("storage.clipboard.useCustomPath") var useCustomClipboardPath: Bool = false
    @AppStorage("storage.notes.useCustomPath") var useCustomNotesPath: Bool = false
    
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
        isFilesEnabled = true
        isClipboardEnabled = true
        isNotesEnabled = true
        
        useCustomFilesPath = false
        useCustomClipboardPath = false
        useCustomNotesPath = false
        
        filesCustomPath = ""
        clipboardCustomPath = ""
        notesCustomPath = ""
        
        objectWillChange.send()
    }
}