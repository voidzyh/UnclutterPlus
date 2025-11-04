import Foundation
import SwiftUI

/// 剪贴板内容类型
enum ClipboardContent: Codable, Equatable {
    case text(String)
    case image(Data)  // 存储为 Data 以支持 Codable
    case file(URL)

    // 用于编码/解码
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageData
        case fileURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let data = try container.decode(Data.self, forKey: .imageData)
            self = .image(data)
        case "file":
            let url = try container.decode(URL.self, forKey: .fileURL)
            self = .file(url)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let data):
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .imageData)
        case .file(let url):
            try container.encode("file", forKey: .type)
            try container.encode(url, forKey: .fileURL)
        }
    }

    // Equatable 实现
    static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)):
            return a == b
        case (.image(let a), .image(let b)):
            return a == b
        case (.file(let a), .file(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// 剪贴板项目模型
struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    var isPinned: Bool
    var useCount: Int

    // 源应用信息
    let sourceAppBundleID: String?
    let sourceAppName: String?
    let sourceAppIcon: Data?

    // 初始化方法
    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        timestamp: Date = Date(),
        isPinned: Bool = false,
        useCount: Int = 0,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        sourceAppIcon: Data? = nil
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.useCount = useCount
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.sourceAppIcon = sourceAppIcon
    }

    // 计算属性：预览文本
    var preview: String {
        switch content {
        case .text(let text):
            return String(text.prefix(100))
        case .image:
            return "图片"
        case .file(let url):
            return url.lastPathComponent
        }
    }

    // 计算属性：系统图标
    var systemImage: String {
        switch content {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }

    // 计算属性：类型颜色
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
}

// MARK: - Extensions for SwiftUI compatibility

extension ClipboardContent {
    /// 转换为 NSImage（用于显示）
    var image: NSImage? {
        switch self {
        case .image(let data):
            return NSImage(data: data)
        case .text, .file:
            return nil
        }
    }
}

extension ClipboardItem {
    /// 用于兼容旧版本的构造方法（从 NSImage 创建）
    init(
        content: ClipboardContentCompat,
        timestamp: Date = Date(),
        isPinned: Bool = false,
        useCount: Int = 0,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        sourceAppIcon: Data? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.useCount = useCount
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.sourceAppIcon = sourceAppIcon

        // 转换内容类型
        switch content {
        case .text(let string):
            self.content = .text(string)
        case .image(let nsImage):
            // 将 NSImage 转换为 Data
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                self.content = .image(pngData)
            } else {
                // 如果转换失败，创建空数据
                self.content = .image(Data())
            }
        case .file(let url):
            self.content = .file(url)
        }
    }
}

/// 用于兼容性的内容类型（支持 NSImage）
enum ClipboardContentCompat {
    case text(String)
    case image(NSImage)
    case file(URL)
}