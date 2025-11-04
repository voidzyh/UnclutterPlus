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

    var sortOption: SortOption {
        foldersManager.sortOption
    }

    var isAscending: Bool {
        foldersManager.isAscending
    }

    var selectedFolders: Set<UUID> {
        foldersManager.selectedFolders
    }

    var totalFolders: Int {
        foldersManager.folders.count
    }

    // MARK: - Initialization

    init(foldersManager: FavoriteFoldersManager = FavoriteFoldersManager()) {
        self.foldersManager = foldersManager
        observeChanges()
    }

    // MARK: - Public Methods

    /// 视图出现时调用
    func onAppear() {
        updateFilteredFolders()
    }

    /// 处理拖拽进入
    func handleDragEntered() {
        dragOver = true
    }

    /// 处理拖拽退出
    func handleDragExited() {
        dragOver = false
    }

    /// 处理文件夹拖放
    func handleFolderDrop(providers: [NSItemProvider]) -> Bool {
        dragOver = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, error in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }

                    DispatchQueue.main.async {
                        // 检查是否为文件夹
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                           isDirectory.boolValue {
                            self?.foldersManager.addFolder(url: url)
                        }
                    }
                }
            }
        }

        return true
    }
    
    /// 处理拖放文件到文件夹
    func handleFileDragToFolder(providers: [NSItemProvider], folder: FavoriteFolder) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, error in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }

                    DispatchQueue.main.async {
                        let success = self?.foldersManager.moveFileToFolder(fileURL: url, folder: folder) ?? false
                        if success {
                            // 可以添加成功提示
                            print("File moved successfully to \(folder.name)")
                        } else {
                            // 可以添加失败提示
                            print("Failed to move file to \(folder.name)")
                        }
                    }
                }
            }
        }
        return true
    }

    /// 打开文件夹
    func openFolder(_ folder: FavoriteFolder) {
        foldersManager.openFolder(folder)
    }
    
    /// 在新窗口中打开文件夹
    func openFolderInNewWindow(_ folder: FavoriteFolder) {
        foldersManager.openFolderInNewWindow(folder)
    }

    /// 设置排序选项
    func setSortOption(_ option: SortOption) {
        foldersManager.sortOption = option
    }

    /// 切换排序顺序
    func toggleSortOrder() {
        foldersManager.isAscending.toggle()
    }

    /// 在访达中显示文件夹
    func showInFinder(_ folder: FavoriteFolder) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)

        // 通知 WindowManager 自动隐藏
        WindowManager.shared.hideWindowAfterAction(.fileShowInFinder)
    }

    /// 删除文件夹
    func deleteFolder(_ folder: FavoriteFolder) {
        foldersManager.removeFolder(folder)
    }

    /// 重命名文件夹
    func renameFolder(_ folder: FavoriteFolder, to newName: String) {
        foldersManager.renameFolder(folder, to: newName)
        editingFolderName = nil
        newFolderName = ""
    }

    /// 开始编辑文件夹名
    func startEditingFolderName(_ folder: FavoriteFolder) {
        editingFolderName = folder.id
        newFolderName = folder.name
    }

    /// 取消编辑文件夹名
    func cancelEditingFolderName() {
        editingFolderName = nil
        newFolderName = ""
    }

    /// 清空搜索文本
    func clearSearch() {
        searchText = ""
    }

    /// 切换视图模式
    func switchViewMode(to mode: ViewMode) {
        viewMode = mode
    }

    /// 切换多选模式
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            foldersManager.selectedFolders.removeAll()
        }
    }

    /// 切换文件夹选择状态
    func toggleSelection(_ folder: FavoriteFolder) {
        foldersManager.toggleSelection(folder)
    }

    /// 切换收藏状态
    func toggleFavorite(_ folder: FavoriteFolder) {
        foldersManager.toggleFavorite(folder)
    }

    /// 删除选中的文件夹
    func deleteSelectedFolders(_ folders: [FavoriteFolder]) {
        for folder in folders {
            foldersManager.removeFolder(folder)
        }
        foldersManager.selectedFolders.removeAll()
    }

    /// 全选
    func selectAll() {
        foldersManager.selectedFolders = Set(filteredFolders.map { $0.id })
    }

    /// 清空所有文件夹
    func clearAllFolders() {
        foldersManager.clearAllFolders()
    }

    // MARK: - Private Methods

    /// 监听变化
    private func observeChanges() {
        // 监听搜索文本变化（增加 debounce 时间）
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFilteredFolders()
            }
            .store(in: &cancellables)

        // 监听文件夹管理器变化
        foldersManager.objectWillChange
            .sink { [weak self] _ in
                self?.updateFilteredFolders()
            }
            .store(in: &cancellables)
    }

    /// 更新过滤后的文件夹列表（优化版：单次遍历）
    private func updateFilteredFolders() {
        PerformanceMonitor.measure("FoldersFilter") {
            let folders = foldersManager.sortedFolders

            if searchText.isEmpty {
                filteredFolders = folders
            } else {
                let searchTextLowercase = searchText.lowercased()

                // 单次遍历完成过滤
                filteredFolders = folders.filter { folder in
                    folder.name.lowercased().contains(searchTextLowercase) ||
                    folder.tags.contains { $0.lowercased().contains(searchTextLowercase) }
                }
            }
        }
    }
}
