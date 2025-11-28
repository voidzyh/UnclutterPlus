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
struct ClipboardIndex: Codable, Identifiable {
    let id: UUID
    let type: ClipboardContentType
    let timestamp: Date
    let sourceApp: String?
    let useCount: Int
    let isPinned: Bool
    let preview: String

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
            self.preview = String(text.prefix(100))
        case .image:
            self.type = .image
            self.preview = "图片"
        case .file(let url):
            self.type = .file
            self.preview = url.lastPathComponent
        }
    }
}

/// 截图索引
struct ScreenshotIndex: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: ScreenshotType
    let hasAnnotation: Bool
    let thumbnailData: Data?

    enum ScreenshotType: String, Codable {
        case region
        case window
        case screen
    }
}