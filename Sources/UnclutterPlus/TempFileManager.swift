import Foundation
import SwiftUI

struct TempFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let dateAdded: Date
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var systemImage: String {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp":
            return "photo"
        case "mp4", "mov", "avi", "mkv", "wmv":
            return "video"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "txt", "rtf":
            return "doc.plaintext"
        case "swift", "py", "js", "html", "css", "java", "cpp", "c":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }
}

class TempFileManager: ObservableObject {
    @Published var files: [TempFile] = []
    private let tempDirectory: URL
    
    init() {
        // 创建临时目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                in: .userDomainMask).first!
        tempDirectory = appSupport.appendingPathComponent("UnclutterPlus/TempFiles")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: tempDirectory, 
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
            
            // 创建 TempFile 对象
            let tempFile = TempFile(
                url: finalURL,
                name: finalURL.lastPathComponent,
                size: size,
                dateAdded: Date()
            )
            
            // 添加到列表
            files.append(tempFile)
            
        } catch {
            print("Error copying file: \(error)")
        }
    }
    
    func removeFile(_ file: TempFile) {
        // 从文件系统删除
        try? FileManager.default.removeItem(at: file.url)
        
        // 从列表移除
        files.removeAll { $0.id == file.id }
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
                    dateAdded: dateAdded
                )
                
                files.append(tempFile)
            }
            
            // 按添加时间排序
            files.sort { $0.dateAdded > $1.dateAdded }
            
        } catch {
            print("Error loading existing files: \(error)")
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