import Foundation

/// 笔记模型
struct Note: Identifiable, Codable, Equatable, Storable, Hashable {
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
    
    // NSRange 不是 Hashable/Codable，我们需要手动处理或忽略
    // 为了简单起见，我们在 Hashable/Equatable 中忽略它，或者使用自定义实现
    // 由于 Equatable 是自动合成的，且包含 cachedHeadingRanges，这可能导致问题
    // 但如果它是 [String: NSRange]，Swift 的自动合成可能无法处理 NSRange
    // 这里我们将 cachedHeadingRanges 移出自动合成范围，或者标记为非 Codable/Hashable
    // 最好的方法是手动实现 Hashable
    
    private(set) var cachedHeadingRanges: [String: NSRange] = [:]  // 标题位置映射
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(content)
        hasher.combine(tags)
        hasher.combine(isPinned)
        hasher.combine(isFavorite)
        hasher.combine(updatedAt)
        // 忽略缓存属性以避免 NSRange 问题
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.content == rhs.content &&
               lhs.tags == rhs.tags &&
               lhs.isPinned == rhs.isPinned &&
               lhs.isFavorite == rhs.isFavorite &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.attachments == rhs.attachments
    }
    
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

        // 提取标题（简单的Markdown标题检测）并记录位置
        let lines = content.components(separatedBy: .newlines)
        cachedHeadings = []
        cachedHeadingRanges = [:]

        var currentLocation = 0
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("#") && !trimmedLine.isEmpty {
                cachedHeadings.append(trimmedLine)
                // 记录标题在内容中的位置
                let range = NSRange(location: currentLocation, length: line.count)
                cachedHeadingRanges[trimmedLine] = range
            }
            // 更新位置（包括换行符）
            currentLocation += line.count + 1
        }
    }

    // 获取标题的位置
    func headingRange(for heading: String) -> NSRange? {
        return cachedHeadingRanges[heading]
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
struct NoteAttachment: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var type: AttachmentType
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

/// 笔记错误类型（统一错误体系：UnclutterError）
enum NotesError: UnclutterError {
    case loadFailed(String)
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case createFailed(String)

    var category: ErrorCategory { .storage }

    var userMessage: String {
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

    var recoverySuggestion: String? { "请重试操作或检查存储路径设置" }

    var underlyingError: Error? { nil }

    var errorCode: String {
        switch self {
        case .loadFailed:   return "NOTES_001"
        case .saveFailed:   return "NOTES_002"
        case .updateFailed: return "NOTES_003"
        case .deleteFailed: return "NOTES_004"
        case .createFailed: return "NOTES_005"
        }
    }

    var errorDescription: String? {
        "[\(errorCode)] \(userMessage)"
    }
}