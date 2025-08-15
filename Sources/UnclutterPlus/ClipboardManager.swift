import Foundation
import Cocoa
import SwiftUI

enum ClipboardContent: Hashable, Codable {
    enum CodingKeys: String, CodingKey {
        case type, text, imageData, fileURL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let string):
            try container.encode("text", forKey: .type)
            try container.encode(string, forKey: .text)
        case .image(let image):
            try container.encode("image", forKey: .type)
            if let tiffData = image.tiffRepresentation {
                try container.encode(tiffData, forKey: .imageData)
            }
        case .file(let url):
            try container.encode("file", forKey: .type)
            try container.encode(url.path, forKey: .fileURL)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            if let imageData = try container.decodeIfPresent(Data.self, forKey: .imageData),
               let image = NSImage(data: imageData) {
                self = .image(image)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .imageData, in: container, debugDescription: "Invalid image data")
            }
        case "file":
            let path = try container.decode(String.self, forKey: .fileURL)
            self = .file(URL(fileURLWithPath: path))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }
    
    case text(String)
    case image(NSImage)
    case file(URL)
}

struct ClipboardItem: Identifiable, Hashable, Codable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    var isPinned: Bool
    var useCount: Int
    let sourceAppBundleID: String?
    let sourceAppName: String?
    let sourceAppIcon: Data?
    
    init(id: UUID = UUID(), 
         content: ClipboardContent, 
         timestamp: Date = Date(), 
         isPinned: Bool = false,
         useCount: Int = 0,
         sourceAppBundleID: String? = nil,
         sourceAppName: String? = nil,
         sourceAppIcon: Data? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.useCount = useCount
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.sourceAppIcon = sourceAppIcon
    }
    
    var systemImage: String {
        switch content {
        case .text:
            return "doc.plaintext"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }
    
    var typeColor: Color {
        switch content {
        case .text:
            return .blue
        case .image:
            return .green
        case .file:
            return .orange
        }
    }
    
    var preview: String {
        switch content {
        case .text(let text):
            return text.count > 100 ? String(text.prefix(100)) + "..." : text
        case .image:
            return "Image content"
        case .file(let url):
            return url.lastPathComponent
        }
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // 自定义解码器，处理向后兼容性
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(ClipboardContent.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        
        // 为 useCount 提供默认值，处理旧数据
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
        
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceAppIcon = try container.decodeIfPresent(Data.self, forKey: .sourceAppIcon)
    }
    
    // 编码键
    private enum CodingKeys: String, CodingKey {
        case id, content, timestamp, isPinned, useCount, sourceAppBundleID, sourceAppName, sourceAppIcon
    }
}

class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var isLoading: Bool = false
    
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 100
    private let pasteboard = NSPasteboard.general
    private let config = ConfigurationManager.shared
    
    init() {
        startMonitoring()
        // 异步加载历史记录以避免阻塞主线程
        Task { @MainActor in
            isLoading = true
            await loadPersistedItemsAsync()
            isLoading = false
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        lastChangeCount = pasteboard.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForClipboardChanges()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForClipboardChanges() {
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            captureClipboardContent()
        }
    }
    
    private func captureClipboardContent() {
        // 获取当前前台应用信息
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier
        let appName = frontApp?.localizedName
        
        // 获取应用图标
        var iconData: Data? = nil
        if let icon = frontApp?.icon {
            if let tiffData = icon.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                iconData = pngData
            }
        }
        
        // 优先级：文件 > 图片 > 文本
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first {
            addItem(.file(url), sourceAppBundleID: bundleID, sourceAppName: appName, sourceAppIcon: iconData)
        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            addItem(.image(image), sourceAppBundleID: bundleID, sourceAppName: appName, sourceAppIcon: iconData)
        } else if let string = pasteboard.string(forType: .string), !string.isEmpty {
            addItem(.text(string), sourceAppBundleID: bundleID, sourceAppName: appName, sourceAppIcon: iconData)
        }
    }
    
    private func addItem(_ content: ClipboardContent, sourceAppBundleID: String? = nil, sourceAppName: String? = nil, sourceAppIcon: Data? = nil) {
        // 检查是否已存在相同内容
        if let existingIndex = items.firstIndex(where: { item in
            switch (item.content, content) {
            case (.text(let existing), .text(let new)):
                return existing == new
            case (.file(let existing), .file(let new)):
                return existing == new
            case (.image(let existing), .image(let new)):
                return existing.tiffRepresentation == new.tiffRepresentation
            default:
                return false
            }
        }) {
            // 如果已存在，移动到顶部并更新时间戳
            let existingItem = items[existingIndex]
            items.remove(at: existingIndex)
            let updatedItem = ClipboardItem(
                content: content,
                timestamp: Date(),
                isPinned: existingItem.isPinned,
                useCount: existingItem.useCount + 1,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                sourceAppIcon: sourceAppIcon
            )
            items.insert(updatedItem, at: 0)
        } else {
            // 新项目，插入到顶部
            let item = ClipboardItem(
                content: content,
                timestamp: Date(),
                isPinned: false,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                sourceAppIcon: sourceAppIcon
            )
            items.insert(item, at: 0)
            
            // 限制项目数量
            if items.count > maxItems {
                items = Array(items.prefix(maxItems))
            }
        }
        
        persistItems()
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let image):
            pasteboard.writeObjects([image])
        case .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }
        
        // 增加使用频次
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].useCount += 1
            persistItems()
        }
        
        // 更新变更计数以避免重复捕获
        lastChangeCount = pasteboard.changeCount
    }
    
    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }
    
    func removeItems(_ itemsToRemove: [ClipboardItem]) {
        let idsToRemove = Set(itemsToRemove.map { $0.id })
        items.removeAll { idsToRemove.contains($0.id) }
        persistItems()
    }
    
    func togglePin(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.isPinned.toggle()
            items[index] = updatedItem
            
            // 重新排序：置顶项目在前
            items.sort { first, second in
                if first.isPinned && !second.isPinned {
                    return true
                } else if !first.isPinned && second.isPinned {
                    return false
                } else {
                    return first.timestamp > second.timestamp
                }
            }
            
            persistItems()
        }
    }
    
    func clearAll() {
        items.removeAll()
        persistItems()
    }
    
    // 清理过期数据
    func cleanupExpiredItems() {
        let maxAge = config.clipboardMaxAge
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        // 移除过期的非置顶项目
        items.removeAll { item in
            !item.isPinned && item.timestamp < cutoffDate
        }
        
        persistItems()
    }
    
    private func persistItems() {
        // 获取存储路径
        let storageURL = config.clipboardStoragePath.appendingPathComponent("history.json")
        
        // 创建存储目录（如果需要）
        try? FileManager.default.createDirectory(at: config.clipboardStoragePath, withIntermediateDirectories: true)
        
        // 保存所有项目（包括图片和文件）
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // 限制保存的项目数量
        let itemsToSave = Array(items.prefix(50))
        
        do {
            let data = try encoder.encode(itemsToSave)
            try data.write(to: storageURL)
        } catch {
            print("Failed to persist clipboard items: \(error)")
        }
        
        // 保存图片到单独的文件
        saveImages()
    }
    
    private func saveImages() {
        let imagesPath = config.clipboardStoragePath.appendingPathComponent("images")
        try? FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        
        // 清理旧图片
        if let files = try? FileManager.default.contentsOfDirectory(at: imagesPath, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        // 保存当前图片
        for item in items.prefix(20) { // 只保存前20个项目的图片
            if case .image(let image) = item.content {
                let imageURL = imagesPath.appendingPathComponent("\(item.id.uuidString).png")
                if let tiffData = image.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: imageURL)
                }
            }
        }
    }
    
    private func loadPersistedItemsAsync() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            self?.loadPersistedItemsSync()
        }.value
    }
    
    private func loadPersistedItemsSync() {
        let storageURL = config.clipboardStoragePath.appendingPathComponent("history.json")
        
        // 尝试从新格式文件加载
        if let data = try? Data(contentsOf: storageURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            if let loadedItems = try? decoder.decode([ClipboardItem].self, from: data) {
                // 恢复图片
                let imagesPath = config.clipboardStoragePath.appendingPathComponent("images")
                var restoredItems: [ClipboardItem] = []
                
                for var item in loadedItems {
                    if case .image = item.content {
                        // 尝试从文件恢复图片
                        let imageURL = imagesPath.appendingPathComponent("\(item.id.uuidString).png")
                        if let imageData = try? Data(contentsOf: imageURL),
                           let image = NSImage(data: imageData) {
                            item = ClipboardItem(
                                content: .image(image),
                                timestamp: item.timestamp,
                                isPinned: item.isPinned,
                                useCount: item.useCount,
                                sourceAppBundleID: item.sourceAppBundleID,
                                sourceAppName: item.sourceAppName,
                                sourceAppIcon: item.sourceAppIcon
                            )
                        } else {
                            continue // 跳过无法恢复的图片
                        }
                    }
                    restoredItems.append(item)
                }
                
                // 在主线程更新 items
                let sortedItems = restoredItems.sorted { $0.timestamp > $1.timestamp }
                DispatchQueue.main.async { [weak self] in
                    self?.items = sortedItems
                }
                return
            }
        }
    }
}