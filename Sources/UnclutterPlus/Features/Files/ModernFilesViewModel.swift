import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// 现代化文件视图模型 - 改进的交互体验和流畅动画
@MainActor
final class ModernFilesViewModel: ObservableObject {
    // MARK: - 发布属性
    
    @Published var folders: [FavoriteFolder] = []
    @Published var filteredFolders: [FavoriteFolder] = []
    @Published var stagedFiles: [TempFileItem] = []
    @Published var searchText: String = "" {
        didSet {
            debouncedSearch.send(searchText)
        }
    }
    
    @Published var isSearching = false
    @Published var viewMode: FileViewMode = .grid
    @Published var sortOption: FileSortOption = .dateNewest
    @Published var showHiddenFiles = false
    
    // 统计信息
    @Published var statistics: [FileStatistic] = []
    
    // 状态管理
    @Published var isLoading = false
    
    // 选择状态
    @Published var selectedFolders: Set<UUID> = []
    
    // MARK: - 私有属性
    
    private let foldersManager = FavoriteFoldersManager.shared
    private let tempFileManager = TempFileManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let debouncedSearch = PassthroughSubject<String, Never>()
    
    // 搜索防抖
    private let searchDebounceInterval: TimeInterval = 0.3
    
    // 性能优化
    private var searchTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?
    
    // 拖拽支持
    private var dropTask: Task<Void, Never>?
    
    // MARK: - 初始化
    
    init() {
        setupBindings()
        setupDebouncedSearch()
        loadInitialData()
    }
    
    // MARK: - 私有方法
    
    private func setupBindings() {
        // 监听文件夹管理器的变化
        foldersManager.$folders
            .receive(on: DispatchQueue.main)
            .sink { [weak self] folders in
                self?.folders = folders
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // 监听暂存文件的变化
        tempFileManager.$files
            .receive(on: DispatchQueue.main)
            .sink { [weak self] files in
                self?.stagedFiles = files
            }
            .store(in: &cancellables)
    }
    
    private func setupDebouncedSearch() {
        debouncedSearch
            .debounce(for: .seconds(searchDebounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await refresh()
        }
    }
    
    private func applyFilters() {
        filterTask?.cancel()
        filterTask = Task { @MainActor in
            var items = folders
            
            // 应用搜索过滤
            if !searchText.isEmpty {
                items = items.filter { folder in
                    folder.name.localizedCaseInsensitiveContains(searchText) ||
                    folder.url.path.localizedCaseInsensitiveContains(searchText)
                }
            }
            
            // 应用排序
            items = sortFolders(items)
            
            // 更新过滤结果
            filteredFolders = items
            
            // 更新统计信息
            updateStatistics()
        }
    }
    
    private func updateStatistics() {
        let totalCount = folders.count
        let favoriteCount = folders.filter { $0.isFavorite }.count
        let recentCount = folders.filter { folder in
            guard let lastAccessed = folder.lastAccessed else { return false }
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return lastAccessed >= weekAgo
        }.count
        
        statistics = [
            FileStatistic(title: "Total", value: "\(totalCount)", icon: "folder", color: .blue),
            FileStatistic(title: "Favorites", value: "\(favoriteCount)", icon: "star.fill", color: .yellow),
            FileStatistic(title: "Recent", value: "\(recentCount)", icon: "clock", color: .green)
        ]
    }
    
    // MARK: - 公共方法
    
    func addFolder(_ url: URL) async {
        foldersManager.addFolder(url: url)
    }
    
    func deleteFolder(_ folder: FavoriteFolder) async {
        foldersManager.removeFolder(folder)
    }
    
    func renameFolder(_ folder: FavoriteFolder, to newName: String) async {
        foldersManager.renameFolder(folder, to: newName)
    }
    
    func toggleFavorite(_ folder: FavoriteFolder) async {
        foldersManager.toggleFavorite(folder)
    }
    
    func openFolder(_ folder: FavoriteFolder) async {
        foldersManager.openFolder(folder)
    }
    
    func openFolderInNewWindow(_ folder: FavoriteFolder) async {
        foldersManager.openFolderInNewWindow(folder)
    }
    
    func showInFinder(_ folder: FavoriteFolder) async {
        foldersManager.showInFinder(folder)
    }

    // MARK: - 暂存文件（drop zone）

    /// 暂存一个文件（引用）；目录不会被暂存（应走收藏文件夹流程）
    @discardableResult
    func stageFile(_ url: URL) -> Bool {
        tempFileManager.stageFile(url: url)
    }

    func removeStagedFile(_ item: TempFileItem) {
        tempFileManager.removeFile(item)
    }

    func clearStagedFiles() {
        tempFileManager.clearAllFiles()
    }

    func openStagedFile(_ item: TempFileItem) {
        tempFileManager.openFile(item)
    }

    func revealStagedFile(_ item: TempFileItem) {
        tempFileManager.revealInFinder(item)
    }

    func recordStagedFileAccess(_ item: TempFileItem) {
        tempFileManager.recordAccess(for: item)
    }

    /// 判断 URL 是否为目录（拖入路由：目录 → 收藏文件夹，文件 → 暂存）
    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    func handleFileDragToFolder(providers: [NSItemProvider], folder: FavoriteFolder) -> Bool {
        return foldersManager.moveFileToFolder(fileURL: URL(fileURLWithPath: "/tmp/test"), folder: folder)
    }
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        // 文件夹数据已经通过绑定自动更新
        applyFilters()
    }
    
    func clearSearch() {
        searchText = ""
    }
    
    func toggleSelection(_ folder: FavoriteFolder) {
        foldersManager.toggleSelection(folder)
    }
    
    func selectFolder(_ folder: FavoriteFolder) {
        selectedFolders.insert(folder.id)
    }
    
    func deselectFolder(_ folder: FavoriteFolder) {
        selectedFolders.remove(folder.id)
    }
    
    func deleteSelectedFolders(_ folders: [FavoriteFolder]) {
        for folder in folders {
            foldersManager.removeFolder(folder)
        }
        selectedFolders.removeAll()
    }
    
    func startEditingFolderName(_ folder: FavoriteFolder) {
        // 这个方法需要在视图中实现
    }
    
    func setSortOption(_ option: FolderSortOption) {
        foldersManager.sortOption = option
    }
    
    // MARK: - 排序和过滤
    
    private func sortFolders(_ items: [FavoriteFolder]) -> [FavoriteFolder] {
        var sortedItems = items
        
        switch sortOption {
        case .name:
            sortedItems.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .dateNewest:
            sortedItems.sort { $0.dateAdded > $1.dateAdded }
        case .dateOldest:
            sortedItems.sort { $0.dateAdded < $1.dateAdded }
        case .accessCount:
            sortedItems.sort { $0.accessCount > $1.accessCount }
        }
        
        return sortedItems
    }
}

// MARK: - 辅助类型

enum FileViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    
    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

enum FileSortOption: String, CaseIterable, DisplayableEnum {
    case name = "Name"
    case dateNewest = "Date (Newest)"
    case dateOldest = "Date (Oldest)"
    case accessCount = "Access Count"
    
    var displayName: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .name:
            return "textformat"
        case .dateNewest:
            return "arrow.down.circle"
        case .dateOldest:
            return "arrow.up.circle"
        case .accessCount:
            return "number"
        }
    }
}

struct FileStatistic: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
}