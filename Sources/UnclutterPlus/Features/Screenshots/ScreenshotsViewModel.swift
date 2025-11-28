import Combine
import Foundation
import SwiftUI

/// ScreenshotsView 的视图模型
/// 职责: 管理截图视图的状态、搜索过滤和视图模式
final class ScreenshotsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 搜索文本
    @Published var searchText: String = ""

    /// 视图模式
    @Published var viewMode: ViewMode = .grid

    /// 多选模式标志
    @Published var isMultiSelectMode: Bool = false

    /// 悬停的截图ID
    @Published var hoveredScreenshot: UUID?

    /// 正在编辑的截图名ID
    @Published var editingScreenshotName: UUID?

    /// 新截图名
    @Published var newScreenshotName: String = ""

    /// 过滤后的截图列表
    @Published private(set) var filteredScreenshots: [ScreenshotItem] = []

    // MARK: - Dependencies

    private let screenshotManager: ScreenshotManager
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Public Computed Properties

    var selectedScreenshots: Set<UUID> {
        screenshotManager.selectedScreenshots
    }

    var totalScreenshots: Int {
        screenshotManager.screenshots.count
    }

    // MARK: - Initialization

    init(screenshotManager: ScreenshotManager = ScreenshotManager.shared) {
        self.screenshotManager = screenshotManager
        observeChanges()
    }

    // MARK: - Public Methods

    /// 视图出现时调用
    func onAppear() {
        updateFilteredScreenshots()
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
            screenshotManager.deselectAll()
        }
    }

    /// 切换截图选择状态
    func toggleSelection(_ screenshot: ScreenshotItem) {
        screenshotManager.toggleSelection(screenshot)
    }

    /// 切换收藏状态
    func toggleFavorite(_ screenshot: ScreenshotItem) {
        screenshotManager.toggleFavorite(screenshot)
    }

    /// 删除截图
    func deleteScreenshot(_ screenshot: ScreenshotItem) {
        screenshotManager.deleteScreenshot(screenshot)
    }

    /// 删除选中的截图
    func deleteSelectedScreenshots(_ screenshots: [ScreenshotItem]) {
        screenshotManager.deleteScreenshots(screenshots)
        screenshotManager.deselectAll()
    }

    /// 全选
    func selectAll() {
        screenshotManager.selectAll()
    }

    /// 清空所有截图
    func clearAllScreenshots() {
        screenshotManager.clearAllScreenshots()
    }

    /// 重命名截图
    func renameScreenshot(_ screenshot: ScreenshotItem, to newName: String) {
        screenshotManager.renameScreenshot(screenshot, to: newName)
        editingScreenshotName = nil
        newScreenshotName = ""
    }

    /// 开始编辑截图名
    func startEditingScreenshotName(_ screenshot: ScreenshotItem) {
        editingScreenshotName = screenshot.id
        newScreenshotName = screenshot.title
    }

    /// 取消编辑截图名
    func cancelEditingScreenshotName() {
        editingScreenshotName = nil
        newScreenshotName = ""
    }

    /// 在 Finder 中显示截图
    func showInFinder(_ screenshot: ScreenshotItem) {
        NSWorkspace.shared.activateFileViewerSelecting([screenshot.imageURL])
        WindowManager.shared.hideWindowAfterAction(.fileShowInFinder)
    }

    /// 打开截图
    func openScreenshot(_ screenshot: ScreenshotItem) {
        NSWorkspace.shared.open(screenshot.imageURL)
        WindowManager.shared.hideWindowAfterAction(.fileOpened)
    }

    /// 复制截图到剪贴板
    func copyScreenshot(_ screenshot: ScreenshotItem) {
        guard let image = NSImage(contentsOf: screenshot.imageURL) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        WindowManager.shared.hideWindowAfterAction(.clipboardCopied)
    }

    /// 复制 OCR 文本到剪贴板
    func copyOCRText(_ screenshot: ScreenshotItem) {
        guard let text = screenshot.ocrText else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        WindowManager.shared.hideWindowAfterAction(.clipboardCopied)
    }

    /// 手动触发 OCR
    func performOCR(_ screenshot: ScreenshotItem) {
        Task {
            await screenshotManager.performOCR(for: screenshot)
        }
    }

    // MARK: - Private Methods

    /// 监听变化
    private func observeChanges() {
        // 监听搜索文本变化
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFilteredScreenshots()
            }
            .store(in: &cancellables)

        // 监听截图管理器变化
        screenshotManager.objectWillChange
            .sink { [weak self] _ in
                self?.updateFilteredScreenshots()
            }
            .store(in: &cancellables)
    }

    /// 更新过滤后的截图列表
    private func updateFilteredScreenshots() {
        let screenshots = screenshotManager.sortedScreenshots

        if searchText.isEmpty {
            filteredScreenshots = screenshots
        } else {
            filteredScreenshots = screenshots.filter { screenshot in
                screenshot.title.localizedCaseInsensitiveContains(searchText) ||
                (screenshot.ocrText?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                screenshot.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}

