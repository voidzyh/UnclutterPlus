import Foundation

/// 笔记索引（轻量级元数据）
public struct NoteIndex: Codable, Identifiable, StorageIndex {
    public typealias SortKey = Date

    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let modifiedAt: Date
    public let tags: Set<String>
    public let wordCount: Int
    public let previewText: String  // 重命名避免冲突
    public let isFavorited: Bool    // 重命名避免冲突

    // 性能优化：预计算小写版本，避免搜索时重复计算
    public let titleLowercased: String
    public let previewTextLowercased: String
    public let tagsLowercased: [String]

    /// 从完整笔记创建索引
    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.createdAt = note.createdAt
        self.modifiedAt = note.modifiedAt
        self.tags = Set(note.tags)
        self.wordCount = note.cachedWordCount
        self.previewText = note.cachedPreview
        self.isFavorited = note.isFavorite

        // 预计算小写版本
        self.titleLowercased = note.title.lowercased()
        self.previewTextLowercased = note.cachedPreview.lowercased()
        self.tagsLowercased = note.tags.map { $0.lowercased() }
    }

    /// 直接初始化索引
    init(id: UUID, title: String, createdAt: Date, modifiedAt: Date,
         tags: Set<String>, wordCount: Int, previewText: String, isFavorited: Bool) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.wordCount = wordCount
        self.previewText = previewText
        self.isFavorited = isFavorited

        // 预计算小写版本
        self.titleLowercased = title.lowercased()
        self.previewTextLowercased = previewText.lowercased()
        self.tagsLowercased = tags.map { $0.lowercased() }
    }

    var sortKey: Date {
        modifiedAt
    }

    var isFavorite: Bool {
        isFavorited
    }

    var preview: String {
        previewText
    }
}

/// 剪贴板索引
struct ClipboardIndex: Codable, Identifiable, StorageIndex {
    typealias SortKey = Date
    
    let id: UUID
    let type: ClipboardContentType
    let timestamp: Date
    let sourceApp: String?
    let useCount: Int
    let isPinned: Bool
    let previewText: String
    
    // StorageIndex Conformance
    var sortKey: Date { timestamp }
    var isFavorite: Bool { isPinned } // Use pin as favorite
    var preview: String { previewText }

    enum ClipboardContentType: String, Codable {
        case text
        case image
        case file
    }

    /// 从完整项目创建索引
    init(from item: ClipboardItem) {
        self.id = item.id
        self.timestamp = item.timestamp
        self.sourceApp = item.sourceAppName
        self.useCount = item.useCount
        self.isPinned = item.isPinned

        // 确定类型和预览
        switch item.content {
        case .text(let text):
            self.type = .text
            self.previewText = String(text.prefix(100))
        case .image:
            self.type = .image
            self.previewText = "图片"
        case .file(let url):
            self.type = .file
            self.previewText = url.lastPathComponent
        }
    }
}

/// 截图索引
struct ScreenshotIndex: Codable, Identifiable, StorageIndex {
    typealias SortKey = Date
    
    let id: UUID
    let timestamp: Date
    let type: ScreenshotType
    let hasAnnotation: Bool
    let thumbnailData: Data?
    let isFavorite: Bool
    let preview: String

    enum ScreenshotType: String, Codable {
        case region
        case window
        case screen
    }
    
    var sortKey: Date { timestamp }
    
    init(id: UUID, timestamp: Date, type: ScreenshotType, hasAnnotation: Bool, thumbnailData: Data?, isFavorite: Bool, preview: String) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.hasAnnotation = hasAnnotation
        self.thumbnailData = thumbnailData
        self.isFavorite = isFavorite
        self.preview = preview
    }
}
