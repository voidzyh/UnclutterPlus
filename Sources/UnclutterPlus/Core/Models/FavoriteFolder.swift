import Foundation

/// 常用文件夹快捷方式模型
struct FavoriteFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let url: URL
    let dateAdded: Date
    var tags: [String]
    var isFavorite: Bool
    var customIcon: String?
    var accessCount: Int
    var lastAccessed: Date?
    
    /// 系统图标名称（用于 UI 显示）
    var systemImage: String {
        customIcon ?? "folder.fill"
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        dateAdded: Date = Date(),
        tags: [String] = [],
        isFavorite: Bool = false,
        customIcon: String? = nil,
        accessCount: Int = 0,
        lastAccessed: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.dateAdded = dateAdded
        self.tags = tags
        self.isFavorite = isFavorite
        self.customIcon = customIcon
        self.accessCount = accessCount
        self.lastAccessed = lastAccessed
    }
    
    /// 获取文件夹内的文件数量
    var fileCount: Int {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            return 0
        }
    }
    
    /// 检查文件夹是否存在
    var exists: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    /// 更新访问统计
    mutating func recordAccess() {
        accessCount += 1
        lastAccessed = Date()
    }
    
    /// 项目计数字符串（用于UI显示）
    var itemCountString: String {
        let count = fileCount
        return "\(count) " + (count == 1 ? "item" : "items")
    }
}

/// 文件夹排序选项
enum FolderSortOption: String, CaseIterable, Identifiable, DisplayableEnum {
    case name
    case dateAdded
    case lastAccessed
    case accessCount
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .dateAdded:
            return "Date Added"
        case .lastAccessed:
            return "Last Accessed"
        case .accessCount:
            return "Access Count"
        }
    }
}

/// 文件夹元数据
struct FolderMetadata: Codable {
    let folder: FavoriteFolder
    let isValid: Bool
    let lastChecked: Date
    
    init(folder: FavoriteFolder) {
        self.folder = folder
        self.isValid = folder.exists
        self.lastChecked = Date()
    }
}