import Combine
import Foundation
import SwiftUI

/// FilesView 的视图模型
/// 职责: 管理文件视图的状态、搜索过滤和视图模式
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

    /// 悬停的文件ID
    @Published var hoveredFile: UUID?

    /// 正在编辑的文件名ID
    @Published var editingFileName: UUID?

    /// 新文件名
    @Published var newFileName: String = ""

    /// 过滤后的文件列表
    @Published private(set) var filteredFiles: [TempFile] = []

    // MARK: - Dependencies

    private let fileManager: TempFileManager
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Public Computed Properties (暴露 fileManager 必要属性)

    var sortOption: SortOption {
        fileManager.sortOption
    }

    var isAscending: Bool {
        fileManager.isAscending
    }

    var selectedFiles: Set<UUID> {
        fileManager.selectedFiles
    }

    var totalSize: Int64 {
        fileManager.totalSize
    }

    var filesByType: [FileType: [TempFile]] {
        fileManager.filesByType
    }

    // MARK: - Initialization

    init(fileManager: TempFileManager = TempFileManager()) {
        self.fileManager = fileManager
        observeChanges()
    }

    // MARK: - Public Methods

    /// 视图出现时调用
    func onAppear() {
        updateFilteredFiles()
    }

    /// 处理拖拽进入
    func handleDragEntered() {
        dragOver = true
    }

    /// 处理拖拽退出
    func handleDragExited() {
        dragOver = false
    }

    /// 处理文件拖放
    func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        dragOver = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, error in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }

                    DispatchQueue.main.async {
                        self?.fileManager.addFile(from: url)
                    }
                }
            }
        }

        return true
    }

    /// 打开文件
    func openFile(_ file: TempFile) {
        fileManager.openFile(file)
    }

    /// 设置排序选项
    func setSortOption(_ option: SortOption) {
        fileManager.sortOption = option
    }

    /// 切换排序顺序
    func toggleSortOrder() {
        fileManager.isAscending.toggle()
    }

    /// 在访达中显示文件
    func showInFinder(_ file: TempFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])

        // 通知 WindowManager 自动隐藏
        WindowManager.shared.hideWindowAfterAction(.fileShowInFinder)
    }

    /// 删除文件
    func deleteFile(_ file: TempFile) {
        fileManager.removeFile(file)
    }

    /// 重命名文件
    func renameFile(_ file: TempFile, to newName: String) {
        fileManager.renameFile(file, to: newName)
        editingFileName = nil
        newFileName = ""
    }

    /// 开始编辑文件名
    func startEditingFileName(_ file: TempFile) {
        editingFileName = file.id
        newFileName = file.name
    }

    /// 取消编辑文件名
    func cancelEditingFileName() {
        editingFileName = nil
        newFileName = ""
    }

    /// 清空搜索文本
    func clearSearch() {
        searchText = ""
    }

    /// 切换视图模式
    func switchViewMode(to mode: ViewMode) {
        viewMode = mode
    }

    /// 获取文件按类型分组
    func groupedFiles() -> [(type: FileType, files: [TempFile])] {
        let grouped = Dictionary(grouping: filteredFiles) { $0.fileType }
        return grouped.map { (type: $0.key, files: $0.value) }
            .sorted { $0.type.rawValue < $1.type.rawValue }
    }

    /// 切换多选模式
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            fileManager.selectedFiles.removeAll()
        }
    }

    /// 切换文件选择状态
    func toggleSelection(_ file: TempFile) {
        fileManager.toggleSelection(file)
    }

    /// 切换收藏状态
    func toggleFavorite(_ file: TempFile) {
        fileManager.toggleFavorite(file)
    }

    /// 删除选中的文件
    func deleteSelectedFiles(_ files: [TempFile]) {
        for file in files {
            fileManager.removeFile(file)
        }
        fileManager.selectedFiles.removeAll()
    }

    /// 全选
    func selectAll() {
        fileManager.selectedFiles = Set(filteredFiles.map { $0.id })
    }

    /// 清空所有文件
    func clearAllFiles() {
        fileManager.clearAllFiles()
    }

    // MARK: - Private Methods

    /// 监听变化
    private func observeChanges() {
        // 监听搜索文本变化
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFilteredFiles()
            }
            .store(in: &cancellables)

        // 监听文件管理器变化
        fileManager.objectWillChange
            .sink { [weak self] _ in
                self?.updateFilteredFiles()
            }
            .store(in: &cancellables)
    }

    /// 更新过滤后的文件列表
    private func updateFilteredFiles() {
        let files = fileManager.sortedFiles

        if searchText.isEmpty {
            filteredFiles = files
        } else {
            filteredFiles = files.filter { file in
                file.name.localizedCaseInsensitiveContains(searchText) ||
                file.fileType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                file.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}
