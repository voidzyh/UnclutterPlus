import Foundation
import SwiftUI

struct FavoriteFolder: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let dateAdded: Date
    var lastAccessed: Date
    var accessCount: Int
    var tags: Set<String>
    var isFavorite: Bool
    var customIcon: String?
    
    init(id: UUID = UUID(), url: URL, name: String, dateAdded: Date, lastAccessed: Date, accessCount: Int = 0, tags: Set<String> = [], isFavorite: Bool = false, customIcon: String? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.dateAdded = dateAdded
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
        self.tags = tags
        self.isFavorite = isFavorite
        self.customIcon = customIcon
    }
    
    var systemImage: String {
        customIcon ?? "folder.fill"
    }
    
    var itemCount: Int? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            return nil
        }
    }
    
    var itemCountString: String {
        if let count = itemCount {
            return "\(count) items"
        }
        return "N/A"
    }
}

enum SortOption: String, CaseIterable {
    case name = "Name"
    case dateAdded = "Date Added"
    case lastAccessed = "Last Accessed"
    case accessCount = "Access Count"
}

class FavoriteFoldersManager: ObservableObject {
    @Published var folders: [FavoriteFolder] = []
    @Published var selectedFolders: Set<UUID> = []
    @Published var sortOption: SortOption = .dateAdded
    @Published var isAscending: Bool = false
    
    private let config = ConfigurationManager.shared
    private var metadataDirectory: URL {
        config.filesStoragePath.appendingPathComponent("FoldersMetadata")
    }
    
    init() {
        // 确保元数据目录存在
        try? FileManager.default.createDirectory(at: metadataDirectory, 
                                               withIntermediateDirectories: true)
        
        loadExistingFolders()
    }
    
    func addFolder(url: URL) {
        // 验证是否为文件夹
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("Error: Not a valid directory")
            return
        }
        
        // 检查是否已存在
        if folders.contains(where: { $0.url.path == url.path }) {
            print("Folder already exists")
            return
        }
        
        let now = Date()
        let folder = FavoriteFolder(
            url: url,
            name: url.lastPathComponent,
            dateAdded: now,
            lastAccessed: now
        )
        
        folders.append(folder)
        saveMetadata(for: folder)
    }
    
    func removeFolder(_ folder: FavoriteFolder) {
        // 删除元数据
        let metadataURL = metadataDirectory.appendingPathComponent("\(folder.id.uuidString).json")
        try? FileManager.default.removeItem(at: metadataURL)
        
        // 从选择中移除
        selectedFolders.remove(folder.id)
        
        // 从列表移除
        folders.removeAll { $0.id == folder.id }
    }
    
    func removeFolders(_ foldersToRemove: [FavoriteFolder]) {
        for folder in foldersToRemove {
            removeFolder(folder)
        }
    }
    
    func renameFolder(_ folder: FavoriteFolder, to newName: String) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            let updatedFolder = FavoriteFolder(
                id: folder.id,
                url: folder.url,
                name: newName,
                dateAdded: folder.dateAdded,
                lastAccessed: folder.lastAccessed,
                accessCount: folder.accessCount,
                tags: folder.tags,
                isFavorite: folder.isFavorite,
                customIcon: folder.customIcon
            )
            folders[index] = updatedFolder
            saveMetadata(for: updatedFolder)
        }
    }
    
    func toggleFavorite(_ folder: FavoriteFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].isFavorite.toggle()
            saveMetadata(for: folders[index])
        }
    }
    
    func addTag(_ tag: String, to folder: FavoriteFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].tags.insert(tag)
            saveMetadata(for: folders[index])
        }
    }
    
    func removeTag(_ tag: String, from folder: FavoriteFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].tags.remove(tag)
            saveMetadata(for: folders[index])
        }
    }
    
    func openFolder(_ folder: FavoriteFolder) {
        // 更新访问统计
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].lastAccessed = Date()
            folders[index].accessCount += 1
            saveMetadata(for: folders[index])
        }
        
        // 在 Finder 中打开文件夹
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)
        
        // 触发自动隐藏窗口
        WindowManager.shared.hideWindowAfterAction(.fileOpened)
    }
    
    func openFolderInNewWindow(_ folder: FavoriteFolder) {
        // 更新访问统计
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].lastAccessed = Date()
            folders[index].accessCount += 1
            saveMetadata(for: folders[index])
        }
        
        // 在新窗口中打开
        NSWorkspace.shared.open(folder.url)
        
        // 触发自动隐藏窗口
        WindowManager.shared.hideWindowAfterAction(.fileOpened)
    }
    
    func moveFileToFolder(fileURL: URL, folder: FavoriteFolder) -> Bool {
        let fileName = fileURL.lastPathComponent
        let destinationURL = folder.url.appendingPathComponent(fileName)
        
        do {
            // 如果目标文件已存在，生成新名称
            let finalURL = generateUniqueURL(for: destinationURL)
            
            // 移动文件
            try FileManager.default.moveItem(at: fileURL, to: finalURL)
            
            // 更新访问统计
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].lastAccessed = Date()
                folders[index].accessCount += 1
                saveMetadata(for: folders[index])
            }
            
            return true
        } catch {
            print("Error moving file: \(error)")
            return false
        }
    }
    
    func toggleSelection(_ folder: FavoriteFolder) {
        if selectedFolders.contains(folder.id) {
            selectedFolders.remove(folder.id)
        } else {
            selectedFolders.insert(folder.id)
        }
    }
    
    func selectAll() {
        selectedFolders = Set(folders.map { $0.id })
    }
    
    func deselectAll() {
        selectedFolders.removeAll()
    }
    
    var sortedFolders: [FavoriteFolder] {
        folders.sorted { first, second in
            // 收藏的文件夹总是在前面
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
            case .lastAccessed:
                result = first.lastAccessed < second.lastAccessed
            case .accessCount:
                result = first.accessCount < second.accessCount
            }
            
            return isAscending ? result : !result
        }
    }
    
    func clearAllFolders() {
        for folder in folders {
            let metadataURL = metadataDirectory.appendingPathComponent("\(folder.id.uuidString).json")
            try? FileManager.default.removeItem(at: metadataURL)
        }
        folders.removeAll()
    }
    
    private func loadExistingFolders() {
        do {
            let metadataFiles = try FileManager.default.contentsOfDirectory(
                at: metadataDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
            
            for metadataFile in metadataFiles {
                if let folder = loadMetadata(from: metadataFile) {
                    // 验证文件夹是否仍然存在
                    if FileManager.default.fileExists(atPath: folder.url.path) {
                        folders.append(folder)
                    } else {
                        // 文件夹不存在，删除元数据
                        try? FileManager.default.removeItem(at: metadataFile)
                    }
                }
            }
            
        } catch {
            print("Error loading existing folders: \(error)")
        }
    }
    
    private func saveMetadata(for folder: FavoriteFolder) {
        let metadata = FolderMetadata(
            id: folder.id,
            url: folder.url,
            name: folder.name,
            dateAdded: folder.dateAdded,
            lastAccessed: folder.lastAccessed,
            accessCount: folder.accessCount,
            tags: folder.tags,
            isFavorite: folder.isFavorite,
            customIcon: folder.customIcon
        )
        
        do {
            let data = try JSONEncoder().encode(metadata)
            let metadataURL = metadataDirectory.appendingPathComponent("\(folder.id.uuidString).json")
            try data.write(to: metadataURL)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
    
    private func loadMetadata(from url: URL) -> FavoriteFolder? {
        do {
            let data = try Data(contentsOf: url)
            let metadata = try JSONDecoder().decode(FolderMetadata.self, from: data)
            
            let folder = FavoriteFolder(
                id: metadata.id,
                url: metadata.url,
                name: metadata.name,
                dateAdded: metadata.dateAdded,
                lastAccessed: metadata.lastAccessed,
                accessCount: metadata.accessCount,
                tags: metadata.tags,
                isFavorite: metadata.isFavorite,
                customIcon: metadata.customIcon
            )
            
            return folder
        } catch {
            print("Error loading metadata: \(error)")
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

struct FolderMetadata: Codable {
    let id: UUID
    let url: URL
    let name: String
    let dateAdded: Date
    let lastAccessed: Date
    let accessCount: Int
    let tags: Set<String>
    let isFavorite: Bool
    let customIcon: String?
}
