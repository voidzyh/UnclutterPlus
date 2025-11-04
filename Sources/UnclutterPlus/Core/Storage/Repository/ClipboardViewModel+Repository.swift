import Foundation
import Combine
import SwiftUI
import AppKit

/// 新的剪贴板视图模型（使用 Repository 架构）
@MainActor
final class ClipboardViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 当前选中的项目
    @Published var selectedItem: ClipboardItem?

    /// 多选模式
    @Published var isMultiSelectMode: Bool = false

    /// 选中的项目ID集合
    @Published var selectedItemIds: Set<UUID> = []

    /// 选中的项目集合 (for compatibility)
    @Published var selectedItems: Set<UUID> = []

    /// 悬停的项目ID
    @Published var hoveredItem: UUID?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 显示删除确认对话框
    @Published var showDeleteConfirmation: Bool = false

    /// 待删除的项目
    @Published var itemsToDelete: [ClipboardItem] = []

    /// 当前选中的索引
    @Published var selectedIndex: Int = -1

    // MARK: - Filter State

    /// 选中的内容类型过滤器
    @Published var selectedContentType: String = "all"

    /// 选中的来源应用过滤器
    @Published var selectedSourceApp: String = "all"

    /// 选中的日期范围过滤器
    @Published var selectedDateRange: String = "all"

    /// 排序方式
    @Published var sortBy: String = "time"

    // MARK: - Filter Expansion State

    /// 类型过滤器展开状态
    @Published var showTypeFilter: Bool = false

    /// 来源过滤器展开状态
    @Published var showSourceFilter: Bool = false

    /// 日期过滤器展开状态
    @Published var showDateFilter: Bool = false

    /// 排序过滤器展开状态
    @Published var showSortFilter: Bool = false

    /// 悬停的工具栏项
    @Published var hoveredToolbar: String?

    /// 过滤后的项目（兼容旧版本）
    @Published private(set) var filteredItems: [ClipboardItem] = []

    // MARK: - Dependencies

    private let repository: ClipboardRepository
    private let pasteboard = NSPasteboard.general
    private var cancellables = Set<AnyCancellable>()

    // 监控剪贴板变化
    private var timer: Timer?
    private var lastChangeCount: Int

    // MARK: - Computed Properties

    /// 过滤后的索引
    var filteredIndexes: [ClipboardIndex] {
        repository.filteredIndexes
    }

    /// 搜索文本
    var searchText: String {
        get { repository.searchText }
        set {
            repository.searchText = newValue
            Task {
                await updateFilteredItems()
            }
        }
    }

    /// 只显示收藏
    var showPinnedOnly: Bool {
        get { repository.showPinnedOnly }
        set { repository.showPinnedOnly = newValue }
    }

    /// 总数量
    var totalCount: Int {
        repository.totalCount
    }

    /// 收藏数量
    var pinnedCount: Int {
        repository.pinnedCount
    }

    // MARK: - Initialization

    init(repository: ClipboardRepository) {
        self.repository = repository
        self.lastChangeCount = pasteboard.changeCount

        setupBindings()
        startMonitoring()
    }

    deinit {
        // Timer will be invalidated when the object is deallocated
        timer?.invalidate()
    }

    private func setupBindings() {
        // 监听仓库变化
        repository.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // 监听过滤器变化
        Publishers.CombineLatest4(
            $selectedContentType,
            $selectedSourceApp,
            $selectedDateRange,
            $sortBy
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            Task {
                await self?.updateFilteredItems()
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Clipboard Monitoring

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.checkForClipboardChanges()
            }
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForClipboardChanges() {
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            Task {
                await processClipboardContent()
            }
        }
    }

    private func processClipboardContent() async {
        // 获取剪贴板内容
        guard let content = getClipboardContent() else { return }

        // 检查是否重复（基于内容）
        if isDuplicateContent(content) {
            return
        }

        // 获取源应用信息
        let (bundleID, appName, appIcon) = getSourceAppInfo()

        // 创建新项目
        let item = ClipboardItem(
            content: content,
            timestamp: Date(),
            isPinned: false,
            useCount: 0,
            sourceAppBundleID: bundleID,
            sourceAppName: appName,
            sourceAppIcon: appIcon
        )

        // 添加到仓库
        await repository.addItem(item)
    }

    private func getClipboardContent() -> ClipboardContentCompat? {
        // 检查文本
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return .text(string)
        }

        // 检查图片
        if let image = NSImage(pasteboard: pasteboard) {
            return .image(image)
        }

        // 检查文件URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = urls.first {
            return .file(firstURL)
        }

        return nil
    }

    private func isDuplicateContent(_ content: ClipboardContentCompat) -> Bool {
        // 简单检查：最近的10个项目中是否有相同内容
        // 注意：这是一个同步检查，可能不会检查到所有项目
        // 但对于防止重复已经足够

        // 对于文本，我们可以直接比较预览
        if case .text(let newText) = content {
            let textPreview = String(newText.prefix(100))
            return filteredIndexes.prefix(10).contains { index in
                index.type == .text && index.preview == textPreview
            }
        }

        // 对于文件，比较文件名
        if case .file(let newURL) = content {
            let filename = newURL.lastPathComponent
            return filteredIndexes.prefix(10).contains { index in
                index.type == .file && index.preview == filename
            }
        }

        // 对于图片，暂时不做重复检查（因为需要比较数据）
        return false
    }

    private func getSourceAppInfo() -> (bundleID: String?, name: String?, icon: Data?) {
        guard let workspace = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil, nil)
        }

        let bundleID = workspace.bundleIdentifier
        let name = workspace.localizedName
        var iconData: Data? = nil

        if let icon = workspace.icon {
            if let tiffData = icon.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                iconData = pngData
            }
        }

        return (bundleID, name, iconData)
    }

    // MARK: - Public Methods

    /// 选择项目
    func selectItem(_ index: ClipboardIndex) {
        Task {
            isLoading = true
            selectedItem = await repository.getItem(id: index.id)
            isLoading = false
        }
    }

    /// 复制到剪贴板
    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()

        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let data):
            // 将数据转换回 NSImage
            if let image = NSImage(data: data),
               let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        case .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }

        // 增加使用计数
        Task {
            await repository.incrementUseCount(item)
        }
    }

    /// 删除项目
    func deleteItem(_ item: ClipboardItem) {
        Task {
            await repository.deleteItem(item)
            if selectedItem?.id == item.id {
                selectedItem = nil
            }
        }
    }

    /// 批量删除
    func deleteSelectedItems() {
        guard !selectedItemIds.isEmpty else { return }

        Task {
            for id in selectedItemIds {
                if let item = await repository.getItem(id: id) {
                    await repository.deleteItem(item)
                }
            }
            selectedItemIds.removeAll()
            isMultiSelectMode = false
        }
    }

    /// 切换收藏状态
    func togglePin(_ item: ClipboardItem) {
        Task {
            await repository.togglePin(item)
            // 刷新选中的项目
            if selectedItem?.id == item.id {
                selectedItem = await repository.getItem(id: item.id)
            }
        }
    }

    /// 切换多选模式
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            selectedItemIds.removeAll()
        }
    }

    /// 切换选择状态
    func toggleSelection(_ index: ClipboardIndex) {
        if selectedItemIds.contains(index.id) {
            selectedItemIds.remove(index.id)
        } else {
            selectedItemIds.insert(index.id)
        }
    }

    /// 全选
    func selectAll() {
        selectedItemIds = Set(filteredIndexes.map { $0.id })
    }

    /// 清空选择
    func deselectAll() {
        selectedItemIds.removeAll()
    }

    /// 清空所有非收藏项
    func clearUnpinned() {
        Task {
            await repository.clearUnpinned()
            selectedItem = nil
            selectedItemIds.removeAll()
        }
    }

    /// 清空所有项目
    func clearAll() {
        Task {
            await repository.clearAll()
            selectedItem = nil
            selectedItemIds.removeAll()
        }
    }

    /// 准备删除项目
    func prepareDelete(items: [ClipboardItem]) {
        itemsToDelete = items
        showDeleteConfirmation = true
    }

    /// 确认删除
    func confirmDelete() {
        Task {
            for item in itemsToDelete {
                await repository.deleteItem(item)
            }
            itemsToDelete.removeAll()
            showDeleteConfirmation = false
        }
    }

    /// 取消删除
    func cancelDelete() {
        itemsToDelete.removeAll()
        showDeleteConfirmation = false
    }

    // MARK: - Additional Methods for Compatibility

    /// 清空搜索
    func clearSearch() {
        searchText = ""
    }

    /// 复制项目到剪贴板
    func copyItem(_ item: ClipboardItem) {
        copyToPasteboard(item)
    }

    /// 删除项目（兼容方法）
    func deleteItems(_ items: [ClipboardItem]) {
        Task {
            for item in items {
                await repository.deleteItem(item)
            }
        }
    }

    /// 切换收藏（兼容方法）
    func togglePinned(_ item: ClipboardItem) {
        togglePin(item)
    }

    /// 视图出现时调用
    func onAppear() {
        Task {
            await updateFilteredItems()
        }
    }

    /// 删除选中的项目（用于ClipboardView）
    func deleteSelected() {
        deleteSelectedItems()
    }

    /// 删除单个项目（用于ClipboardView）
    func removeItem(_ item: ClipboardItem) {
        deleteItem(item)
    }

    /// 切换选择（用于ClipboardView）
    func toggleSelection(_ item: ClipboardItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    /// 更新过滤后的项目
    private func updateFilteredItems() async {
        // 获取所有索引并转换为完整项目
        var items: [ClipboardItem] = []

        for index in repository.filteredIndexes {
            if let item = await repository.getItem(id: index.id) {
                items.append(item)
            }
        }

        // 应用额外的过滤器
        var filtered = items

        // 类型过滤
        if selectedContentType != "all" {
            filtered = filtered.filter { item in
                switch item.content {
                case .text:
                    return selectedContentType == "text"
                case .image:
                    return selectedContentType == "image"
                case .file:
                    return selectedContentType == "file"
                }
            }
        }

        // 来源应用过滤
        if selectedSourceApp != "all" {
            filtered = filtered.filter { $0.sourceAppName == selectedSourceApp }
        }

        // 日期范围过滤
        if selectedDateRange != "all" {
            let now = Date()
            filtered = filtered.filter { item in
                switch selectedDateRange {
                case "today":
                    return Calendar.current.isDateInToday(item.timestamp)
                case "week":
                    return item.timestamp > now.addingTimeInterval(-7 * 24 * 60 * 60)
                case "month":
                    return item.timestamp > now.addingTimeInterval(-30 * 24 * 60 * 60)
                default:
                    return true
                }
            }
        }

        // 排序
        switch sortBy {
        case "time":
            filtered.sort { $0.timestamp > $1.timestamp }
        case "usage":
            filtered.sort { $0.useCount > $1.useCount }
        case "alphabet":
            filtered.sort {
                let preview0 = getPreview(for: $0)
                let preview1 = getPreview(for: $1)
                return preview0 < preview1
            }
        default:
            break
        }

        await MainActor.run {
            self.filteredItems = filtered
        }
    }

    private func getPreview(for item: ClipboardItem) -> String {
        switch item.content {
        case .text(let text):
            return String(text.prefix(100))
        case .image:
            return "图片"
        case .file(let url):
            return url.lastPathComponent
        }
    }

    /// 获取所有项目（兼容方法）
    var items: [ClipboardItem] {
        filteredItems
    }
}