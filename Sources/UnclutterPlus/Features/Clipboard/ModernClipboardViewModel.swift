import Foundation
import Combine
import SwiftUI
import AppKit

/// 现代化剪贴板视图模型 - 支持流畅动画和智能过滤
@MainActor
final class ModernClipboardViewModel: ObservableObject {
    // MARK: - 发布属性
    
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var filteredItems: [ClipboardItem] = []
    @Published var searchText: String = "" {
        didSet {
            debouncer.queryChanged(searchText)
        }
    }
    
    @Published var isSearching = false
    @Published var selectedContentType: ClipboardContentType = .all
    @Published var selectedDateRange: DateRange = .all
    @Published var sortOption: SortOption = .newest

    // 多选模式（合并粘贴）
    @Published var isMultiSelectMode = false
    @Published var selectedItemIds: Set<UUID> = []

    /// 当前高亮项（单选光标，键盘导航/回车激活的唯一数据源；视图不再自持副本）
    @Published var selectedItemID: UUID?
    
    // 统计信息
    @Published var statistics: [ClipboardStatistic] = []
    
    // 状态管理
    @Published var isLoading = false
    
    // MARK: - 私有属性

    /// 数据源：走持久化的 ClipboardRepository（而非旧的空 stub ClipboardManager）。
    /// ClipboardMonitor 采集的新内容会写入此 repository，从而驱动 UI 实时更新。
    let repository: ClipboardRepository
    private var cancellables = Set<AnyCancellable>()
    /// 搜索防抖器（Task 化，替代 Combine debounce 样板）
    private lazy var debouncer = SearchDebouncer { [weak self] _ in self?.applyFilters() }

    // 搜索防抖

    // 性能优化
    private var searchTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?

    // MARK: - 初始化

    /// - Parameter repository: 数据仓库（nil 时使用生产单例；测试可注入 mock 支撑的实例）
    init(repository: ClipboardRepository? = nil) {
        // 默认参数在非隔离上下文求值，不能直接引用 MainActor 单例（Swift 6 会报错）
        self.repository = repository ?? AppStorageManager.shared.clipboardRepository
        setupBindings()
        loadInitialData()
    }

    // MARK: - 私有方法

    private func setupBindings() {
        // 订阅 repository 的变更明细（ClipboardMonitor 写入新项 / 更新 useCount 时触发），
        // 按事件增量合并而非 O(N) 全量重载
        repository.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                Task { @MainActor [weak self] in
                    await self?.applyChange(change)
                }
            }
            .store(in: &cancellables)
    }

    /// 按变更明细增量更新内存列表（新增插头部、更新原位替换、删除移除、清空清列表）
    private func applyChange(_ change: ClipboardChange) async {
        switch change {
        case .added(let id):
            if let item = await repository.getItem(id: id),
               !clipboardItems.contains(where: { $0.id == id }) {
                clipboardItems.insert(item, at: 0)
                applyFilters()
            }
        case .updated(let id):
            if let item = await repository.getItem(id: id),
               let index = clipboardItems.firstIndex(where: { $0.id == id }) {
                clipboardItems[index] = item
                applyFilters()
            }
        case .removed(let id):
            let before = clipboardItems.count
            clipboardItems.removeAll { $0.id == id }
            if clipboardItems.count != before {
                if selectedItemID == id {
                    selectedItemID = nil
                }
                applyFilters()
            }
        case .cleared:
            clipboardItems.removeAll()
            selectedItemID = nil
            applyFilters()
        }
    }

    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }

        // 从 repository 的索引加载完整项目
        var items: [ClipboardItem] = []
        for index in repository.clipboardIndexes {
            if let item = await repository.getItem(id: index.id) {
                items.append(item)
            }
        }
        clipboardItems = items
        applyFilters()
    }

    private func loadInitialData() {
        Task {
            await loadInitialData()
        }
    }
    
    private func applyFilters() {
        filterTask?.cancel()
        filterTask = Task { @MainActor in
            var items = clipboardItems
            
            // 应用内容类型过滤
            if selectedContentType != .all {
                items = items.filter { item in
                    switch (item.content, selectedContentType) {
                    case (.text, .text): return true
                    case (.image, .image): return true
                    case (.file, .files): return true
                    default: return false
                    }
                }
            }
            
            // 应用搜索过滤
            if !searchText.isEmpty {
                items = items.filter { item in
                    switch item.content {
                    case .text(let text):
                        return text.localizedCaseInsensitiveContains(searchText)
                    case .image:
                        return "image".localizedCaseInsensitiveContains(searchText) ||
                               "图片".localizedCaseInsensitiveContains(searchText)
                    case .file(let url):
                        return url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
                    }
                }
            }
            
            // 应用日期范围过滤
            items = filterByDateRange(items)
            
            // 应用排序
            items = sortItems(items)
            
            // 更新过滤结果
            filteredItems = items
        }
    }
    
    // MARK: - 公共方法
    
    func copyToClipboard(_ item: ClipboardItem) async {
        // 写入系统剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.content {
        case .text(let text):
            // 只写纯文本，粘贴时不带任何格式（对齐 Maccy 的纯文本粘贴基线）
            pasteboard.setString(text, forType: .string)
        case .image(let data):
            if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }
        // 复制成功后按配置自动隐藏面板（与截图面板行为一致）
        WindowManager.shared.hideWindowAfterAction(.clipboardCopied)
        // 注意：ClipboardMonitor 会监听到 changeCount 变化并自行 +1 useCount，
        // 这里不重复增加计数。
    }

    func deleteItem(_ item: ClipboardItem) async {
        await repository.deleteItem(item)
    }

    func clearAll() async {
        await repository.clearAll()
    }

    /// 清除非 pin 项目（对齐 Maccy 的 Clear Unpinned）
    func clearUnpinned() async {
        await repository.clearUnpinned()
    }

    // MARK: - 键盘导航（P0 键盘优先操作流）

    /// 当前高亮项
    var selectedItem: ClipboardItem? {
        guard let id = selectedItemID else { return nil }
        return clipboardItems.first { $0.id == id }
    }

    /// 当前高亮项在过滤列表中的位置
    var selectedIndex: Int? {
        guard let id = selectedItemID else { return nil }
        return filteredItems.firstIndex { $0.id == id }
    }

    /// 选中指定项（单选光标）
    func select(_ item: ClipboardItem) {
        selectedItemID = item.id
    }

    /// 方向键上移高亮
    func moveSelectionUp() {
        guard !filteredItems.isEmpty else { return }
        if let index = selectedIndex {
            selectedItemID = filteredItems[max(0, index - 1)].id
        } else {
            selectedItemID = filteredItems.first?.id
        }
    }

    /// 方向键下移高亮
    func moveSelectionDown() {
        guard !filteredItems.isEmpty else { return }
        if let index = selectedIndex {
            let next = min(filteredItems.count - 1, index + 1)
            selectedItemID = filteredItems[next].id
        } else {
            selectedItemID = filteredItems.first?.id
        }
    }

    /// 回车激活高亮项：多选模式下切换选择；否则复制到剪贴板（含自动隐藏）
    func activateSelection() async {
        guard let item = selectedItem else { return }
        if isMultiSelectMode {
            toggleSelection(item)
        } else {
            await copyToClipboard(item)
        }
    }

    // MARK: - 多选与合并粘贴

    /// 是否满足合并条件（至少选中两项）
    var canMerge: Bool { selectedItemIds.count >= 2 }

    /// 按当前过滤列表顺序的选中项（合并输入）
    var orderedSelectedItems: [ClipboardItem] {
        filteredItems.filter { selectedItemIds.contains($0.id) }
    }

    /// 切换多选模式；退出时清空选择
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            selectedItemIds.removeAll()
        }
    }

    /// 切换单个项目的选择状态
    func toggleSelection(_ item: ClipboardItem) {
        if selectedItemIds.contains(item.id) {
            selectedItemIds.remove(item.id)
        } else {
            selectedItemIds.insert(item.id)
        }
    }

    func selectAll() {
        selectedItemIds = Set(clipboardItems.map(\.id))
    }

    func deselectAll() {
        selectedItemIds.removeAll()
    }

    /// 合并选中项（按列表顺序）为纯文本并写入系统剪贴板；成功后按配置自动隐藏面板。
    func mergeSelectedToPasteboard() async {
        let ordered = orderedSelectedItems
        guard ordered.count >= 2 else { return }

        let merged = Self.mergedText(for: ordered, separator: ConfigurationManager.shared.clipboardMergeSeparator)
        guard !merged.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(merged, forType: .string)

        WindowManager.shared.hideWindowAfterAction(.clipboardCopied)
        // 退出多选并清空选择
        isMultiSelectMode = false
        selectedItemIds.removeAll()
        // 注意：ClipboardMonitor 会将合并结果作为新片段入库（内容指纹不同），
        // 这正是合并粘贴的预期行为。
    }

    /// 合并文本（纯函数，便于测试）：按列表顺序拼接，图片用"图片"、文件用文件名占位。
    static func mergedText(for items: [ClipboardItem], separator: String) -> String {
        items.map { item in
            switch item.content {
            case .text(let text):
                return text
            case .image:
                return "图片"
            case .file(let url):
                return url.lastPathComponent
            }
        }
        .joined(separator: separator)
    }

    func refresh() async {
        await loadInitialData()
    }

    func pinItem(_ item: ClipboardItem) async {
        await repository.togglePin(item)
    }

    func incrementUseCount(for item: ClipboardItem) async {
        await repository.incrementUseCount(item)
    }

    func updateItem(_ updatedItem: ClipboardItem) async {
        await repository.updateItem(updatedItem)
    }
    
    // MARK: - 过滤和排序
    
    private func filterByDateRange(_ items: [ClipboardItem]) -> [ClipboardItem] {
        switch selectedDateRange {
        case .all:
            return items
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            return items.filter { $0.timestamp >= today }
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return items.filter { $0.timestamp >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
            return items.filter { $0.timestamp >= monthAgo }
        }
    }
    
    private func sortItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        switch sortOption {
        case .newest:
            return items.sorted { $0.timestamp > $1.timestamp }
        case .oldest:
            return items.sorted { $0.timestamp < $1.timestamp }
        case .mostUsed:
            return items.sorted { $0.useCount > $1.useCount }
        case .alphabetical:
            return items.sorted { item1, item2 in
                let text1 = extractText(from: item1)
                let text2 = extractText(from: item2)
                return text1.localizedCaseInsensitiveCompare(text2) == .orderedAscending
            }
        }
    }
    
    private func extractText(from item: ClipboardItem) -> String {
        switch item.content {
        case .text(let text):
            return text
        case .image:
            return "Image"
        case .file(let url):
            return url.lastPathComponent
        }
    }
    
    // MARK: - 类型切换方法
    
    func toggleContentType(_ type: ClipboardContentType) {
        selectedContentType = type
    }
    
    func setDateRange(_ range: DateRange) {
        selectedDateRange = range
    }
    
    func setSortOption(_ option: SortOption) {
        sortOption = option
    }
}

// MARK: - 辅助类型

enum ClipboardContentType: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case image = "Image"
    case files = "Files"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .files: return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .text: return .green
        case .image: return .orange
        case .files: return .purple
        }
    }
}

enum DateRange: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "calendar"
        case .today: return "calendar.day.timeline.left"
        case .week: return "calendar.week"
        case .month: return "calendar.month"
        }
    }
}

enum SortOption: String, CaseIterable, DisplayableEnum {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case mostUsed = "Most Used"
    case alphabetical = "Alphabetical"
    
    var displayName: String { rawValue }
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .newest: return "arrow.down.circle"
        case .oldest: return "arrow.up.circle"
        case .mostUsed: return "star.circle"
        case .alphabetical: return "textformat"
        }
    }
}

struct ClipboardStatistic: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
}