import Combine
import Foundation

/// ClipboardView 的视图模型
/// 职责: 管理剪贴板视图的状态、过滤逻辑和用户交互
final class ClipboardViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 搜索文本
    @Published var searchText: String = ""

    /// 选中的项目集合
    @Published var selectedItems: Set<UUID> = []

    /// 悬停的项目ID
    @Published var hoveredItem: UUID?

    /// 多选模式标志
    @Published var isMultiSelectMode: Bool = false

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

    // MARK: - Computed Properties

    /// 过滤后的剪贴板项目
    @Published private(set) var filteredItems: [ClipboardItem] = []

    // MARK: - Dependencies

    private let clipboardManager: ClipboardManager
    private let config: ConfigurationManager
    private var cancellables: Set<AnyCancellable> = []
    private var updateTimer: Timer?

    // MARK: - Initialization

    init(
        clipboardManager: ClipboardManager = ClipboardManager(),
        config: ConfigurationManager = .shared
    ) {
        self.clipboardManager = clipboardManager
        self.config = config

        setupDefaultFilter()
        observeChanges()
    }

    // MARK: - Public Methods

    /// 视图出现时调用
    func onAppear() {
        updateFilteredItems()
    }

    /// 复制项目到剪贴板
    func copyItem(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item)
    }

    /// 删除项目
    func deleteItems(_ itemIds: Set<UUID>) {
        let itemsToDelete = clipboardManager.items.filter { itemIds.contains($0.id) }
        clipboardManager.removeItems(itemsToDelete)
        selectedItems.removeAll()
    }

    /// 清空搜索文本
    func clearSearch() {
        searchText = ""
    }

    /// 切换多选模式
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            selectedItems.removeAll()
        }
    }

    /// 获取可用的来源应用列表
    func availableSourceApps() -> [String] {
        let apps = Set(clipboardManager.items.compactMap { $0.sourceAppBundleID })
        return ["all"] + Array(apps).sorted()
    }

    // MARK: - Private Methods

    /// 设置默认展开的过滤器
    private func setupDefaultFilter() {
        switch config.clipboardDefaultFilter {
        case "type":
            showTypeFilter = true
        case "date":
            showDateFilter = true
        case "source":
            showSourceFilter = true
        case "sort":
            showSortFilter = true
        default:
            showTypeFilter = true
        }
    }

    /// 监听变化并更新过滤结果
    private func observeChanges() {
        // 监听所有影响过滤的属性变化
        Publishers.CombineLatest4(
            $searchText,
            $selectedContentType,
            $selectedSourceApp,
            $selectedDateRange
        )
        .combineLatest($sortBy)
        .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateFilteredItems()
        }
        .store(in: &cancellables)

        // 监听 ClipboardManager 的项目变化
        clipboardManager.objectWillChange
            .sink { [weak self] _ in
                self?.scheduleFilterUpdate()
            }
            .store(in: &cancellables)
    }

    /// 调度过滤更新 (防抖动)
    private func scheduleFilterUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: false
        ) { [weak self] _ in
            self?.updateFilteredItems()
        }
    }

    /// 更新过滤后的项目列表
    private func updateFilteredItems() {
        var items = clipboardManager.items

        // 内容类型过滤
        if selectedContentType != "all" {
            items = items.filter { item in
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
            items = items.filter { $0.sourceAppBundleID == selectedSourceApp }
        }

        // 日期范围过滤
        if selectedDateRange != "all" {
            let calendar = Calendar.current
            let now = Date()
            let cutoffDate: Date

            switch selectedDateRange {
            case "today":
                cutoffDate = calendar.startOfDay(for: now)
            case "week":
                cutoffDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case "month":
                cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            default:
                cutoffDate = now
            }

            items = items.filter { $0.timestamp >= cutoffDate }
        }

        // 搜索文本过滤
        if !searchText.isEmpty {
            items = items.filter { item in
                switch item.content {
                case .text(let text):
                    return text.localizedCaseInsensitiveContains(searchText)
                case .image:
                    return false
                case .file(let url):
                    return url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        // 排序
        items = sortItems(items)

        filteredItems = items
    }

    /// 排序项目
    private func sortItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        switch sortBy {
        case "time":
            return items.sorted { $0.timestamp > $1.timestamp }
        case "useCount":
            return items.sorted { $0.useCount > $1.useCount }
        default:
            return items
        }
    }
}
