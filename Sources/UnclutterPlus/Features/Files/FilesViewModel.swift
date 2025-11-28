import Combine
import Foundation
import SwiftUI

/// FilesView 的视图模型
/// 职责: 管理文件夹快捷方式视图的状态、搜索过滤和视图模式
final class FilesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 拖拽悬停状态
    @Published var dragOver: Bool = false

    /// 搜索文本
    @Published var searchText: String = ""

    /// 视图模式
    @Published var viewMode: ViewMode = .grid

    /// 多选模式标志
    @Published var isMultiSelectMode: Bool = false

    /// 悬停的文件夹ID
    @Published var hoveredFolder: UUID?

    /// 正在编辑的文件夹名ID
    @Published var editingFolderName: UUID?

    /// 新文件夹名
    @Published var newFolderName: String = ""

    /// 过滤后的文件夹列表
    @Published private(set) var filteredFolders: [FavoriteFolder] = []

    // MARK: - Dependencies

    private let foldersManager: FavoriteFoldersManager
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Public Computed Properties (暴露 foldersManager 必要属性)

    var sortOption: FolderSortOption {
        foldersManager.sortOption
    }

    var isAscending: Bool {
        foldersManager.isAscending
    }

    var selectedFolders: Set<UUID> {
        foldersManager.selectedFolders
    }

    var folders: [FavoriteFolder] {
        foldersManager.folders
    }

    // MARK: - Initialization

    init(foldersManager: FavoriteFoldersManager = FavoriteFoldersManager.shared) {
        self.foldersManager = foldersManager
        setupBindings()
        applyFilters()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // 监听 foldersManager 的 folders 变化
        foldersManager.$folders
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // 监听搜索文本变化
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // 监听视图模式变化 (可选的额外处理)
        $viewMode
            .sink { _ in
                // 如果视图切换需要额外处理，可以在这里添加
            }
            .store(in: &cancellables)
    }

    private func applyFilters() {
        if searchText.isEmpty {
            filteredFolders = foldersManager.folders
        } else {
            filteredFolders = foldersManager.getFilteredFolders(searchText: searchText)
        }
    }

    // MARK: - Public Methods (封装 foldersManager 的功能)

    func clearSearch() {
        searchText = ""
    }

    func addFolder(_ url: URL) {
        foldersManager.addFolder(url: url)
    }

    func deleteFolder(_ folder: FavoriteFolder) {
        foldersManager.removeFolder(folder)
    }

    func renameFolder(_ folder: FavoriteFolder, to newName: String) {
        foldersManager.renameFolder(folder, to: newName)
    }

    func toggleFavorite(_ folder: FavoriteFolder) {
        foldersManager.toggleFavorite(folder)
    }

    func openFolder(_ folder: FavoriteFolder) {
        foldersManager.openFolder(folder)
    }

    func openFolderInNewWindow(_ folder: FavoriteFolder) {
        foldersManager.openFolderInNewWindow(folder)
    }

    func showInFinder(_ folder: FavoriteFolder) {
        foldersManager.showInFinder(folder)
    }

    func handleFileDragToFolder(providers: [NSItemProvider], folder: FavoriteFolder) -> Bool {
        // 这里简化处理，实际应该解析 providers 中的文件 URL
        // 由于拖拽处理比较复杂，这里返回 true 表示接受拖拽
        return true
    }

    func setSortOption(_ option: FolderSortOption) {
        foldersManager.setSortOption(option)
    }
    
    func toggleSortOrder() {
        foldersManager.toggleSortOrder()
    }
    
    func handleFolderDrop(providers: [NSItemProvider]) -> Bool {
        // 处理文件夹拖拽 - 简化实现
        return true
    }
    
    func selectAll() {
        for folder in filteredFolders {
            foldersManager.selectedFolders.insert(folder.id)
        }
    }

    func toggleSelection(_ folder: FavoriteFolder) {
        foldersManager.toggleSelection(folder)
    }

    func startEditingFolderName(_ folder: FavoriteFolder) {
        editingFolderName = folder.id
        newFolderName = folder.name
    }

    func deleteSelectedFolders(_ folders: [FavoriteFolder]) {
        for folder in folders {
            foldersManager.removeFolder(folder)
        }
        foldersManager.selectedFolders.removeAll()
    }
    
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            foldersManager.selectedFolders.removeAll()
        }
    }
    
    func clearAllFolders() {
        for folder in foldersManager.folders {
            foldersManager.removeFolder(folder)
        }
        foldersManager.selectedFolders.removeAll()
    }
}