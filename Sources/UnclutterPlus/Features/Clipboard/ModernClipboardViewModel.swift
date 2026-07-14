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
            debouncedSearch.send(searchText)
        }
    }
    
    @Published var isSearching = false
    @Published var selectedContentType: ClipboardContentType = .all
    @Published var selectedDateRange: DateRange = .all
    @Published var sortOption: SortOption = .newest
    
    // 统计信息
    @Published var statistics: [ClipboardStatistic] = []
    
    // 状态管理
    @Published var isLoading = false
    @Published var error: ClipboardError?
    
    // MARK: - 私有属性

    /// 数据源：走持久化的 ClipboardRepository（而非旧的空 stub ClipboardManager）。
    /// ClipboardMonitor 采集的新内容会写入此 repository，从而驱动 UI 实时更新。
    private let repository = AppStorageManager.shared.clipboardRepository
    private var cancellables = Set<AnyCancellable>()
    private let debouncedSearch = PassthroughSubject<String, Never>()

    // 搜索防抖
    private let searchDebounceInterval: TimeInterval = 0.3

    // 性能优化
    private var searchTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?

    // MARK: - 初始化

    init() {
        setupBindings()
        setupDebouncedSearch()
        loadInitialData()
    }

    // MARK: - 私有方法

    private func setupBindings() {
        // 订阅 repository 变化（ClipboardMonitor 写入新项 / 更新 useCount 时触发）
        repository.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadInitialData()
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
            pasteboard.setString(text, forType: .string)
        case .image(let data):
            if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }
        // 注意：ClipboardMonitor 会监听到 changeCount 变化并自行 +1 useCount，
        // 这里不重复增加计数。
    }

    func deleteItem(_ item: ClipboardItem) async {
        await repository.deleteItem(item)
    }

    func clearAll() async {
        await repository.clearAll()
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

enum ClipboardError: LocalizedError {
    case loadFailed(String)
    case copyFailed(String)
    case deleteFailed(String)
    case clearFailed(String)
    case pinFailed(String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load clipboard items: \(message)"
        case .copyFailed(let message):
            return "Failed to copy to clipboard: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete item: \(message)"
        case .clearFailed(let message):
            return "Failed to clear clipboard: \(message)"
        case .pinFailed(let message):
            return "Failed to pin item: \(message)"
        case .updateFailed(let message):
            return "Failed to update item: \(message)"
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