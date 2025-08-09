import Foundation
import SwiftUI

struct TempFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64
    let dateAdded: Date
    var lastAccessed: Date
    var tags: Set<String>
    var isFavorite: Bool
    
    init(id: UUID = UUID(), url: URL, name: String, size: Int64, dateAdded: Date, lastAccessed: Date, tags: Set<String> = [], isFavorite: Bool = false) {
        self.id = id
        self.url = url
        self.name = name
        self.size = size
        self.dateAdded = dateAdded
        self.lastAccessed = lastAccessed
        self.tags = tags
        self.isFavorite = isFavorite
    }
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
    
    var fileType: FileType {
        FileType.from(extension: fileExtension)
    }
    
    var typeColor: Color {
        fileType.color
    }
    
    
    var systemImage: String {
        fileType.systemImage
    }
}

enum FileType: String, CaseIterable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case document = "Document"
    case spreadsheet = "Spreadsheet"
    case presentation = "Presentation"
    case archive = "Archive"
    case text = "Text"
    case code = "Code"
    case pdf = "PDF"
    case other = "Other"
    
    static func from(extension ext: String) -> FileType {
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "svg":
            return .image
        case "mp4", "mov", "avi", "mkv", "wmv", "m4v", "flv":
            return .video
        case "mp3", "wav", "aac", "flac", "m4a", "ogg":
            return .audio
        case "pdf":
            return .pdf
        case "doc", "docx", "pages":
            return .document
        case "xls", "xlsx", "numbers":
            return .spreadsheet
        case "ppt", "pptx", "keynote":
            return .presentation
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return .archive
        case "txt", "rtf", "md":
            return .text
        case "swift", "py", "js", "html", "css", "java", "cpp", "c", "json", "xml":
            return .code
        default:
            return .other
        }
    }
    
    var systemImage: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "music.note"
        case .pdf: return "doc.richtext"
        case .document: return "doc.text"
        case .spreadsheet: return "tablecells"
        case .presentation: return "rectangle.on.rectangle"
        case .archive: return "archivebox"
        case .text: return "doc.plaintext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .other: return "doc"
        }
    }
    
    var color: Color {
        switch self {
        case .image: return .green
        case .video: return .purple
        case .audio: return .orange
        case .pdf: return .red
        case .document: return .blue
        case .spreadsheet: return .teal
        case .presentation: return .pink
        case .archive: return .brown
        case .text: return .gray
        case .code: return .indigo
        case .other: return .secondary
        }
    }
}

enum SortOption: String, CaseIterable {
    case name = "Name"
    case dateAdded = "Date Added"
    case size = "Size"
    case type = "Type"
    case lastAccessed = "Last Accessed"
}

class TempFileManager: ObservableObject {
    @Published var files: [TempFile] = []
    @Published var selectedFiles: Set<UUID> = []
    @Published var sortOption: SortOption = .dateAdded
    @Published var isAscending: Bool = false
    
    private let tempDirectory: URL
    private let metadataDirectory: URL
    
    init() {
        // 创建临时目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                in: .userDomainMask).first!
        tempDirectory = appSupport.appendingPathComponent("UnclutterPlus/TempFiles")
        metadataDirectory = appSupport.appendingPathComponent("UnclutterPlus/Metadata")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: tempDirectory, 
                                               withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: metadataDirectory, 
                                               withIntermediateDirectories: true)
        
        loadExistingFiles()
    }
    
    func addFile(from sourceURL: URL) {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // 如果文件已存在，生成新名称
            let finalURL = generateUniqueURL(for: destinationURL)
            
            // 复制文件到临时目录
            try FileManager.default.copyItem(at: sourceURL, to: finalURL)
            
            // 获取文件大小
            let attributes = try FileManager.default.attributesOfItem(atPath: finalURL.path)
            let size = attributes[.size] as? Int64 ?? 0
            let now = Date()
            
            // 创建 TempFile 对象
            let tempFile = TempFile(
                url: finalURL,
                name: finalURL.lastPathComponent,
                size: size,
                dateAdded: now,
                lastAccessed: now
            )
            
            // 添加到列表
            files.append(tempFile)
            saveMetadata(for: tempFile)
            
        } catch {
            print("Error copying file: \(error)")
        }
    }
    
    func removeFile(_ file: TempFile) {
        // 从文件系统删除
        try? FileManager.default.removeItem(at: file.url)
        
        // 删除元数据
        let metadataURL = metadataDirectory.appendingPathComponent("\(file.id.uuidString).json")
        try? FileManager.default.removeItem(at: metadataURL)
        
        // 从选择中移除
        selectedFiles.remove(file.id)
        
        // 从列表移除
        files.removeAll { $0.id == file.id }
    }
    
    func removeFiles(_ filesToRemove: [TempFile]) {
        for file in filesToRemove {
            removeFile(file)
        }
    }
    
    func renameFile(_ file: TempFile, to newName: String) {
        let newURL = tempDirectory.appendingPathComponent(newName)
        
        do {
            try FileManager.default.moveItem(at: file.url, to: newURL)
            
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                let updatedFile = TempFile(
                    id: file.id,
                    url: newURL,
                    name: newName,
                    size: file.size,
                    dateAdded: file.dateAdded,
                    lastAccessed: file.lastAccessed,
                    tags: file.tags,
                    isFavorite: file.isFavorite
                )
                files[index] = updatedFile
                saveMetadata(for: updatedFile)
            }
        } catch {
            print("Error renaming file: \(error)")
        }
    }
    
    func toggleFavorite(_ file: TempFile) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].isFavorite.toggle()
            saveMetadata(for: files[index])
        }
    }
    
    func addTag(_ tag: String, to file: TempFile) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].tags.insert(tag)
            saveMetadata(for: files[index])
        }
    }
    
    func removeTag(_ tag: String, from file: TempFile) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].tags.remove(tag)
            saveMetadata(for: files[index])
        }
    }
    
    func openFile(_ file: TempFile) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].lastAccessed = Date()
            saveMetadata(for: files[index])
        }
        NSWorkspace.shared.open(file.url)
    }
    
    func toggleSelection(_ file: TempFile) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
        } else {
            selectedFiles.insert(file.id)
        }
    }
    
    func selectAll() {
        selectedFiles = Set(files.map { $0.id })
    }
    
    func deselectAll() {
        selectedFiles.removeAll()
    }
    
    var sortedFiles: [TempFile] {
        files.sorted { first, second in
            // 收藏的文件总是在前面
            if first.isFavorite && !second.isFavorite {
                return true
            } else if !first.isFavorite && second.isFavorite {
                return false
            }
            
            let result: Bool
            switch sortOption {
            case .name:
                result = first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            case .dateAdded:
                result = first.dateAdded < second.dateAdded
            case .size:
                result = first.size < second.size
            case .type:
                result = first.fileType.rawValue.localizedCaseInsensitiveCompare(second.fileType.rawValue) == .orderedAscending
            case .lastAccessed:
                result = first.lastAccessed < second.lastAccessed
            }
            
            return isAscending ? result : !result
        }
    }
    
    var filesByType: [FileType: [TempFile]] {
        Dictionary(grouping: sortedFiles) { $0.fileType }
    }
    
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
    
    func clearAllFiles() {
        for file in files {
            try? FileManager.default.removeItem(at: file.url)
        }
        files.removeAll()
    }
    
    private func loadExistingFiles() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )
            
            for url in fileURLs {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attributes[.size] as? Int64 ?? 0
                let dateAdded = attributes[.creationDate] as? Date ?? Date()
                
                let tempFile = TempFile(
                    url: url,
                    name: url.lastPathComponent,
                    size: size,
                    dateAdded: dateAdded,
                    lastAccessed: dateAdded
                )
                
                // 尝试加载元数据
                let finalFile = loadMetadata(for: tempFile) ?? tempFile
                
                files.append(finalFile)
            }
            
        } catch {
            print("Error loading existing files: \(error)")
        }
    }
    
    private func saveMetadata(for file: TempFile) {
        let metadata = FileMetadata(
            id: file.id,
            tags: file.tags,
            isFavorite: file.isFavorite,
            lastAccessed: file.lastAccessed
        )
        
        do {
            let data = try JSONEncoder().encode(metadata)
            let metadataURL = metadataDirectory.appendingPathComponent("\(file.id.uuidString).json")
            try data.write(to: metadataURL)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
    
    private func loadMetadata(for file: TempFile) -> TempFile? {
        let metadataURL = metadataDirectory.appendingPathComponent("\(file.id.uuidString).json")
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(FileMetadata.self, from: data)
            
            let updatedFile = TempFile(
                id: file.id,
                url: file.url,
                name: file.name,
                size: file.size,
                dateAdded: file.dateAdded,
                lastAccessed: metadata.lastAccessed,
                tags: metadata.tags,
                isFavorite: metadata.isFavorite
            )
            
            return updatedFile
        } catch {
            return nil
        }
    }
    
    private func generateUniqueURL(for url: URL) -> URL {
        var counter = 1
        var uniqueURL = url
        
        while FileManager.default.fileExists(atPath: uniqueURL.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let pathExtension = url.pathExtension
            let directory = url.deletingLastPathComponent()
            
            let newName = pathExtension.isEmpty
                ? "\(nameWithoutExtension) \(counter)"
                : "\(nameWithoutExtension) \(counter).\(pathExtension)"
            
            uniqueURL = directory.appendingPathComponent(newName)
            counter += 1
        }
        
        return uniqueURL
    }
}

struct FileMetadata: Codable {
    let id: UUID
    let tags: Set<String>
    let isFavorite: Bool
    let lastAccessed: Date
}