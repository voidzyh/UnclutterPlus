import Foundation
import SwiftUI
import AppKit

enum ScreenshotSource: Codable {
    case region
    case window(windowID: CGWindowID?)
}

struct ScreenshotItem: Identifiable, Codable {
    let id: UUID
    let imageURL: URL
    var title: String
    let createdAt: Date
    var ocrText: String?
    var ocrStatus: OCRStatus
    var isFavorite: Bool
    var tags: Set<String>
    let source: ScreenshotSource
    let appName: String?
    
    init(
        id: UUID = UUID(),
        imageURL: URL,
        title: String,
        createdAt: Date = Date(),
        ocrText: String? = nil,
        ocrStatus: OCRStatus = .pending,
        isFavorite: Bool = false,
        tags: Set<String> = [],
        source: ScreenshotSource,
        appName: String? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.title = title
        self.createdAt = createdAt
        self.ocrText = ocrText
        self.ocrStatus = ocrStatus
        self.isFavorite = isFavorite
        self.tags = tags
        self.source = source
        self.appName = appName
    }
    
    var thumbnailImage: NSImage? {
        NSImage(contentsOf: imageURL)
    }
    
    var sizeString: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
              let size = attributes[.size] as? Int64 else {
            return "0 KB"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum OCRStatus: String, Codable {
    case pending
    case running
    case done
    case failed
}

class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()
    
    @Published var screenshots: [ScreenshotItem] = []
    @Published var selectedScreenshots: Set<UUID> = []
    
    private let config = ConfigurationManager.shared
    private var screenshotsDirectory: URL {
        config.screenshotsStoragePath
    }
    private var metadataDirectory: URL {
        config.screenshotsStoragePath.appendingPathComponent("Metadata")
    }
    
    private init() {
        // 确保目录存在
        try? FileManager.default.createDirectory(at: screenshotsDirectory, 
                                               withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: metadataDirectory, 
                                               withIntermediateDirectories: true)
        
        loadExistingScreenshots()
    }
    
    // MARK: - Save Screenshot
    
    func saveScreenshot(image: NSImage, source: ScreenshotSource, appName: String? = nil) -> ScreenshotItem? {
        // 生成文件名
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "screenshot_\(timestamp).png"
        let fileURL = screenshotsDirectory.appendingPathComponent(fileName)
        
        // 保存图片
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Failed to convert image to PNG")
            return nil
        }
        
        do {
            try pngData.write(to: fileURL)
        } catch {
            print("Failed to save screenshot: \(error)")
            return nil
        }
        
        // 创建截图项
        let item = ScreenshotItem(
            imageURL: fileURL,
            title: generateTitle(for: source, appName: appName),
            source: source,
            appName: appName
        )
        
        screenshots.append(item)
        saveMetadata(for: item)
        
        // 如果启用自动 OCR，触发 OCR
        if config.ocrAutoEnabled {
            Task {
                await performOCR(for: item)
            }
        }
        
        return item
    }
    
    private func generateTitle(for source: ScreenshotSource, appName: String?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        switch source {
        case .region:
            return "区域截图 \(timestamp)"
        case .window:
            if let appName = appName {
                return "\(appName) 窗口 \(timestamp)"
            }
            return "窗口截图 \(timestamp)"
        }
    }
    
    // MARK: - Load Screenshots
    
    private func loadExistingScreenshots() {
        do {
            let metadataFiles = try FileManager.default.contentsOfDirectory(
                at: metadataDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
            
            for metadataFile in metadataFiles {
                if let item = loadMetadata(from: metadataFile) {
                    // 验证图片文件是否仍然存在
                    if FileManager.default.fileExists(atPath: item.imageURL.path) {
                        screenshots.append(item)
                    } else {
                        // 图片不存在，删除元数据
                        try? FileManager.default.removeItem(at: metadataFile)
                    }
                }
            }
            
            // 按创建时间倒序排序
            screenshots.sort { $0.createdAt > $1.createdAt }
            
        } catch {
            print("Error loading existing screenshots: \(error)")
        }
    }
    
    // MARK: - Delete Screenshot
    
    func deleteScreenshot(_ item: ScreenshotItem) {
        // 删除图片文件
        try? FileManager.default.removeItem(at: item.imageURL)
        
        // 删除元数据
        let metadataURL = metadataDirectory.appendingPathComponent("\(item.id.uuidString).json")
        try? FileManager.default.removeItem(at: metadataURL)
        
        // 从选择中移除
        selectedScreenshots.remove(item.id)
        
        // 从列表移除
        screenshots.removeAll { $0.id == item.id }
    }
    
    func deleteScreenshots(_ items: [ScreenshotItem]) {
        for item in items {
            deleteScreenshot(item)
        }
    }
    
    // MARK: - Update Screenshot
    
    func updateScreenshot(_ item: ScreenshotItem) {
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index] = item
            saveMetadata(for: item)
        }
    }
    
    func toggleFavorite(_ item: ScreenshotItem) {
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index].isFavorite.toggle()
            saveMetadata(for: screenshots[index])
        }
    }
    
    func addTag(_ tag: String, to item: ScreenshotItem) {
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index].tags.insert(tag)
            saveMetadata(for: screenshots[index])
        }
    }
    
    func removeTag(_ tag: String, from item: ScreenshotItem) {
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index].tags.remove(tag)
            saveMetadata(for: screenshots[index])
        }
    }
    
    func renameScreenshot(_ item: ScreenshotItem, to newTitle: String) {
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index].title = newTitle
            saveMetadata(for: screenshots[index])
        }
    }
    
    // MARK: - OCR
    
    func performOCR(for item: ScreenshotItem) async {
        // 更新状态为运行中
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index].ocrStatus = .running
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        // 执行 OCR（这里会调用 OCREngine）
        // 暂时使用占位符，后续会实现
        let ocrEngine = DeepseekOCREngine()
        let result = await ocrEngine.recognize(imageURL: item.imageURL)
        
        // 更新结果
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            switch result {
            case .success(let text):
                screenshots[index].ocrText = text
                screenshots[index].ocrStatus = .done
            case .failure:
                screenshots[index].ocrStatus = .failed
            }
            saveMetadata(for: screenshots[index])
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Metadata
    
    private func saveMetadata(for item: ScreenshotItem) {
        let metadata = ScreenshotMetadata(
            id: item.id,
            imageURL: item.imageURL,
            title: item.title,
            createdAt: item.createdAt,
            ocrText: item.ocrText,
            ocrStatus: item.ocrStatus,
            isFavorite: item.isFavorite,
            tags: item.tags,
            source: item.source,
            appName: item.appName
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            let metadataURL = metadataDirectory.appendingPathComponent("\(item.id.uuidString).json")
            try data.write(to: metadataURL)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
    
    private func loadMetadata(from url: URL) -> ScreenshotItem? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(ScreenshotMetadata.self, from: data)
            
            return ScreenshotItem(
                id: metadata.id,
                imageURL: metadata.imageURL,
                title: metadata.title,
                createdAt: metadata.createdAt,
                ocrText: metadata.ocrText,
                ocrStatus: metadata.ocrStatus,
                isFavorite: metadata.isFavorite,
                tags: metadata.tags,
                source: metadata.source,
                appName: metadata.appName
            )
        } catch {
            print("Error loading metadata: \(error)")
            return nil
        }
    }
    
    // MARK: - Selection
    
    func toggleSelection(_ item: ScreenshotItem) {
        if selectedScreenshots.contains(item.id) {
            selectedScreenshots.remove(item.id)
        } else {
            selectedScreenshots.insert(item.id)
        }
    }
    
    func selectAll() {
        selectedScreenshots = Set(screenshots.map { $0.id })
    }
    
    func deselectAll() {
        selectedScreenshots.removeAll()
    }
    
    func clearAllScreenshots() {
        for screenshot in screenshots {
            try? FileManager.default.removeItem(at: screenshot.imageURL)
            let metadataURL = metadataDirectory.appendingPathComponent("\(screenshot.id.uuidString).json")
            try? FileManager.default.removeItem(at: metadataURL)
        }
        screenshots.removeAll()
        selectedScreenshots.removeAll()
    }
    
    // MARK: - Sort
    
    var sortedScreenshots: [ScreenshotItem] {
        screenshots.sorted { first, second in
            // 收藏的截图总是在前面
            if first.isFavorite && !second.isFavorite {
                return true
            } else if !first.isFavorite && second.isFavorite {
                return false
            }
            
            // 按创建时间倒序
            return first.createdAt > second.createdAt
        }
    }
}

// MARK: - Metadata Model

struct ScreenshotMetadata: Codable {
    let id: UUID
    let imageURL: URL
    let title: String
    let createdAt: Date
    let ocrText: String?
    let ocrStatus: OCRStatus
    let isFavorite: Bool
    let tags: Set<String>
    let source: ScreenshotSource
    let appName: String?
}
