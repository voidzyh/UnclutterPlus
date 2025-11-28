import Foundation

/// 笔记模型
struct Note: Identifiable, Codable, Equatable, Storable {
    let id: UUID
    var title: String
    var content: String
    var tags: [String]
    var isPinned: Bool
    var isFavorite: Bool
    let createdAt: Date
    var updatedAt: Date
    var attachments: [NoteAttachment]
    
    // Conformance to Storable protocol
    var modifiedAt: Date { updatedAt }
    
    // 缓存属性
    private(set) var cachedPreview: String = ""
    private(set) var cachedWordCount: Int = 0
    private(set) var cachedCharacterCount: Int = 0
    private(set) var cachedReadingTime: Int = 0
    private(set) var cachedHeadings: [String] = []
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        tags: [String] = [],
        isPinned: Bool = false,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        attachments: [NoteAttachment] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attachments = attachments
        updateCache()
    }
    
    mutating func update(title: String? = nil, content: String? = nil, tags: [String]? = nil) {
        if let title = title {
            self.title = title
        }
        if let content = content {
            self.content = content
        }
        if let tags = tags {
            self.tags = tags
        }
        self.updatedAt = Date()
        updateCache()
    }
    
    mutating func togglePin() {
        isPinned.toggle()
        updatedAt = Date()
    }
    
    mutating func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = Date()
    }
    
    private mutating func updateCache() {
        // 更新预览
        cachedPreview = String(content.prefix(200))
        
        // 更新字数统计
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        cachedWordCount = words.count
        
        // 更新字符数统计
        cachedCharacterCount = content.count
        
        // 更新阅读时间（假设每分钟200字）
        cachedReadingTime = max(1, cachedWordCount / 200)
        
        // 提取标题（简单的Markdown标题检测）
        let lines = content.components(separatedBy: .newlines)
        cachedHeadings = lines.filter { line in
            line.hasPrefix("#") && !line.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    var preview: String {
        cachedPreview
    }
    
    var wordCount: Int {
        cachedWordCount
    }
    
    var characterCount: Int {
        cachedCharacterCount
    }
    
    var readingTime: Int {
        cachedReadingTime
    }
    
    var headings: [String] {
        cachedHeadings
    }
}

/// 笔记附件
struct NoteAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    let type: AttachmentType
    let fileName: String
    let fileSize: Int64
    let createdAt: Date
    var url: URL?
    
    enum AttachmentType: String, Codable {
        case image
        case file
        case link
    }
    
    init(
        id: UUID = UUID(),
        type: AttachmentType,
        fileName: String,
        fileSize: Int64 = 0,
        createdAt: Date = Date(),
        url: URL? = nil
    ) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.url = url
    }
}

/// 笔记排序选项
enum NoteSortOption: String, CaseIterable, DisplayableEnum {
    case dateCreated = "Date Created"
    case dateModified = "Date Modified"
    case title = "Title"
    case tagCount = "Tag Count"
    
    var displayName: String { rawValue }
}

/// 笔记错误类型
enum NotesError: LocalizedError {
    case loadFailed(String)
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case createFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load notes: \(message)"
        case .saveFailed(let message):
            return "Failed to save notes: \(message)"
        case .updateFailed(let message):
            return "Failed to update note: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete note: \(message)"
        case .createFailed(let message):
            return "Failed to create note: \(message)"
        }
    }
}