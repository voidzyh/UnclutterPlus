import Foundation
import Combine
import AppKit

/// 常用文件夹快捷方式管理器
class FavoriteFoldersManager: ObservableObject {
    static let shared = FavoriteFoldersManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var folders: [FavoriteFolder] = []
    @Published var sortOption: FolderSortOption = .dateAdded
    @Published var isAscending: Bool = false
    @Published var selectedFolders: Set<UUID> = []
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    /// 元数据存储目录
    private var metadataDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("UnclutterPlus")
        let metadataDirectory = appDirectory.appendingPathComponent("Files").appendingPathComponent("FoldersMetadata")
        
        if !fileManager.fileExists(atPath: metadataDirectory.path) {
            try? fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        }
        
        return metadataDirectory
    }
    
    // MARK: - Initialization
    
    init() {
        loadFolders()
        setupBindings()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 监听排序选项变化
        $sortOption
            .sink { [weak self] _ in
                self?.saveFolders()
            }
            .store(in: &cancellables)
        
        // 监听排序顺序变化
        $isAscending
            .sink { [weak self] _ in
                self?.saveFolders()
            }
            .store(in: &cancellables)
    }
    
    /// 加载文件夹列表
    private func loadFolders() {
        let folderPath = metadataDirectory.appendingPathComponent("favoriteFolders.json")
        
        guard fileManager.fileExists(atPath: folderPath.path) else {
            folders = []
            return
        }
        
        do {
            let data = try Data(contentsOf: folderPath)
            let decoder = JSONDecoder()
            let loadedFolders = try decoder.decode([FavoriteFolder].self, from: data)
            
            // 过滤掉不存在的文件夹
            folders = loadedFolders.filter { $0.exists }
            
            // 排序
            sortFolders()
        } catch {
            logger.debug("Failed to load folders: \(error)", category: "FavoriteFoldersManager")
            folders = []
        }
    }
    
    /// 保存文件夹列表
    private func saveFolders() {
        let folderPath = metadataDirectory.appendingPathComponent("favoriteFolders.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(folders)
            try data.write(to: folderPath)
        } catch {
            logger.debug("Failed to save folders: \(error)", category: "FavoriteFoldersManager")
        }
    }
    
    /// 排序文件夹
    private func sortFolders() {
        folders.sort { folder1, folder2 in
            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = folder1.name.localizedStandardCompare(folder2.name) == .orderedAscending
            case .dateAdded:
                comparison = folder1.dateAdded < folder2.dateAdded
            case .lastAccessed:
                let date1 = folder1.lastAccessed ?? folder1.dateAdded
                let date2 = folder2.lastAccessed ?? folder2.dateAdded
                comparison = date1 < date2
            case .accessCount:
                comparison = folder1.accessCount < folder2.accessCount
            }
            
            return isAscending ? comparison : !comparison
        }
    }
    
    // MARK: - Public Methods
    
    /// 添加文件夹
    func addFolder(url: URL) {
        // 检查是否已存在
        if folders.contains(where: { $0.url == url }) {
            return
        }
        
        // 检查是否为有效文件夹
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        
        // 创建新文件夹对象
        let folderName = url.lastPathComponent
        let newFolder = FavoriteFolder(
            name: folderName,
            url: url
        )
        
        folders.append(newFolder)
        sortFolders()
        saveFolders()
    }
    
    /// 移除文件夹
    func removeFolder(_ folder: FavoriteFolder) {
        folders.removeAll { $0.id == folder.id }
        selectedFolders.remove(folder.id)
        saveFolders()
    }
    
    /// 重命名文件夹
    func renameFolder(_ folder: FavoriteFolder, to newName: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }
        
        folders[index].name = newName
        saveFolders()
    }
    
    /// 切换收藏状态
    func toggleFavorite(_ folder: FavoriteFolder) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }
        
        folders[index].isFavorite.toggle()
        saveFolders()
    }
    
    /// 切换选择状态
    func toggleSelection(_ folder: FavoriteFolder) {
        if selectedFolders.contains(folder.id) {
            selectedFolders.remove(folder.id)
        } else {
            selectedFolders.insert(folder.id)
        }
    }
    
    /// 打开文件夹
    func openFolder(_ folder: FavoriteFolder) {
        // 更新访问统计
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].recordAccess()
            sortFolders()
            saveFolders()
        }
        
        // 在 Finder 中打开
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)
        
        // 通知 WindowManager 自动隐藏
        WindowManager.shared.hideWindowAfterAction(.fileOpened)
    }
    
    /// 在新窗口中打开文件夹
    func openFolderInNewWindow(_ folder: FavoriteFolder) {
        // 更新访问统计
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index].recordAccess()
            sortFolders()
            saveFolders()
        }
        
        // 在新窗口中打开
        NSWorkspace.shared.open(folder.url)
    }
    
    /// 在 Finder 中显示文件夹
    func showInFinder(_ folder: FavoriteFolder) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)
        
        // 通知 WindowManager 自动隐藏
        WindowManager.shared.hideWindowAfterAction(.fileShowInFinder)
    }
    
    /// 移动文件到文件夹
    func moveFileToFolder(fileURL: URL, folder: FavoriteFolder) -> Bool {
        guard folder.exists else {
            return false
        }
        
        let destinationURL = folder.url.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            try fileManager.moveItem(at: fileURL, to: destinationURL)
            
            // 更新文件夹访问统计
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].recordAccess()
                sortFolders()
                saveFolders()
            }
            
            return true
        } catch {
            logger.debug("Failed to move file: \(error)", category: "FavoriteFoldersManager")
            return false
        }
    }
    
    /// 清空所有文件夹
    func clearAllFolders() {
        folders.removeAll()
        selectedFolders.removeAll()
        saveFolders()
    }
    
    /// 获取过滤后的文件夹列表
    func getFilteredFolders(searchText: String) -> [FavoriteFolder] {
        if searchText.isEmpty {
            return folders
        }
        
        return folders.filter { folder in
            folder.name.localizedCaseInsensitiveContains(searchText) ||
            folder.url.path.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    /// 设置排序选项
    func setSortOption(_ option: FolderSortOption) {
        sortOption = option
        sortFolders()
        saveFolders()
    }
    
    /// 切换排序顺序
    func toggleSortOrder() {
        isAscending.toggle()
        sortFolders()
        saveFolders()
    }
}
    /// 切换多选模式
    func toggleMultiSelectMode() {
        // 这个方法是为了兼容性，实际多选逻辑由 ViewModel 处理
        logger.debug("切换多选模式 - 由 ViewModel 处理", category: "FavoriteFoldersManager")
    }
