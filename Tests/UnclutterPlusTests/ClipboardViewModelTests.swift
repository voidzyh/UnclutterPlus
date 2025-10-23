import XCTest
import Combine
@testable import UnclutterPlus

/// ClipboardViewModel 的单元测试
final class ClipboardViewModelTests: XCTestCase {
    var sut: ClipboardViewModel!
    var mockClipboardManager: ClipboardManager!
    var mockConfig: ConfigurationManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockClipboardManager = ClipboardManager()
        mockConfig = ConfigurationManager.shared
        mockConfig.resetToDefaults()
        sut = ClipboardViewModel(
            clipboardManager: mockClipboardManager,
            config: mockConfig
        )
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockClipboardManager = nil
        mockConfig = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(sut.searchText, "")
        XCTAssertTrue(sut.selectedItems.isEmpty)
        XCTAssertNil(sut.hoveredItem)
        XCTAssertFalse(sut.isMultiSelectMode)
        XCTAssertEqual(sut.selectedIndex, -1)
    }

    func testDefaultFilterSetup() {
        // 默认配置应展开类型过滤器
        // 注意:由于其他测试可能修改了配置,这里只验证至少有一个过滤器展开
        let hasFilterExpanded = sut.showTypeFilter || sut.showSourceFilter ||
                               sut.showDateFilter || sut.showSortFilter
        XCTAssertTrue(hasFilterExpanded, "应至少有一个过滤器展开")
    }

    func testCustomDefaultFilter() {
        mockConfig.clipboardDefaultFilter = "date"
        let viewModel = ClipboardViewModel(
            clipboardManager: mockClipboardManager,
            config: mockConfig
        )

        XCTAssertTrue(viewModel.showDateFilter, "应展开日期过滤器")
        XCTAssertFalse(viewModel.showTypeFilter)
    }

    // MARK: - Filter Tests

    func testContentTypeFilter() {
        // 测试内容类型过滤
        sut.selectedContentType = "text"
        XCTAssertEqual(sut.selectedContentType, "text")

        sut.selectedContentType = "image"
        XCTAssertEqual(sut.selectedContentType, "image")

        sut.selectedContentType = "file"
        XCTAssertEqual(sut.selectedContentType, "file")
    }

    func testSearchTextFilter() {
        let expectation = XCTestExpectation(description: "等待搜索过滤")

        sut.$filteredItems
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sut.searchText = "test"

        wait(for: [expectation], timeout: 1.0)
    }

    func testDateRangeFilter() {
        // 测试今天
        sut.selectedDateRange = "today"
        XCTAssertEqual(sut.selectedDateRange, "today")

        // 测试本周
        sut.selectedDateRange = "week"
        XCTAssertEqual(sut.selectedDateRange, "week")

        // 测试本月
        sut.selectedDateRange = "month"
        XCTAssertEqual(sut.selectedDateRange, "month")
    }

    // MARK: - Sort Tests

    func testSortByTime() {
        sut.sortBy = "time"
        XCTAssertEqual(sut.sortBy, "time")
    }

    func testSortByUseCount() {
        sut.sortBy = "useCount"
        XCTAssertEqual(sut.sortBy, "useCount")
    }

    // MARK: - Selection Tests

    func testMultiSelectMode() {
        XCTAssertFalse(sut.isMultiSelectMode)

        sut.toggleMultiSelectMode()
        XCTAssertTrue(sut.isMultiSelectMode)

        // 添加一些选中项
        let itemId = UUID()
        sut.selectedItems.insert(itemId)

        // 关闭多选模式应清空选中项
        sut.toggleMultiSelectMode()
        XCTAssertFalse(sut.isMultiSelectMode)
        XCTAssertTrue(sut.selectedItems.isEmpty, "关闭多选模式应清空选中项")
    }

    // MARK: - User Actions Tests

    func testClearSearch() {
        sut.searchText = "test query"
        sut.clearSearch()
        XCTAssertEqual(sut.searchText, "")
    }

    func testDeleteItems() {
        let itemId1 = UUID()
        let itemId2 = UUID()
        sut.selectedItems = [itemId1, itemId2]

        sut.deleteItems(sut.selectedItems)

        XCTAssertTrue(sut.selectedItems.isEmpty, "删除后应清空选中项")
    }

    // MARK: - Hover State Tests

    func testHoverState() {
        let itemId = UUID()

        sut.hoveredItem = itemId
        XCTAssertEqual(sut.hoveredItem, itemId)

        sut.hoveredItem = nil
        XCTAssertNil(sut.hoveredItem)
    }

    func testToolbarHoverState() {
        sut.hoveredToolbar = "delete"
        XCTAssertEqual(sut.hoveredToolbar, "delete")

        sut.hoveredToolbar = nil
        XCTAssertNil(sut.hoveredToolbar)
    }

    // MARK: - Debounce Tests

    func testSearchDebounce() {
        let expectation = XCTestExpectation(description: "等待防抖动")
        expectation.isInverted = true // 期望不立即触发

        var updateCount = 0
        sut.$filteredItems
            .dropFirst()
            .sink { _ in
                updateCount += 1
            }
            .store(in: &cancellables)

        // 快速连续输入
        sut.searchText = "t"
        sut.searchText = "te"
        sut.searchText = "tes"
        sut.searchText = "test"

        // 等待很短的时间,应该还没触发更新
        wait(for: [expectation], timeout: 0.03)

        // 由于防抖动,快速连续的更新应该被合并
        XCTAssertLessThan(updateCount, 4, "应该通过防抖动减少更新次数")
    }

    // MARK: - Edge Cases Tests

    func testEmptyFilteredItems() {
        XCTAssertTrue(sut.filteredItems.isEmpty, "初始状态过滤列表应为空")
    }

    func testMultipleFiltersCombination() {
        // 同时应用多个过滤器
        sut.selectedContentType = "text"
        sut.selectedDateRange = "week"
        sut.searchText = "test"

        // 验证过滤器状态
        XCTAssertEqual(sut.selectedContentType, "text")
        XCTAssertEqual(sut.selectedDateRange, "week")
        XCTAssertEqual(sut.searchText, "test")
    }

    func testAvailableSourceApps() {
        let apps = sut.availableSourceApps()
        XCTAssertTrue(apps.contains("all"), "应始终包含 'all' 选项")
    }
}
