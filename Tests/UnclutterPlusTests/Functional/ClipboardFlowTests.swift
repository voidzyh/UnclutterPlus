import XCTest
@testable import UnclutterPlus

/// 剪贴板功能流程级测试：添加 → 搜索 → 置顶 → 清理 → 删除 全链路
/// 使用 MockGenericStorage 隔离存储层，无真实用户数据副作用
@MainActor
final class ClipboardFlowTests: XCTestCase {

    var repository: ClipboardRepository!
    var mockStorage: MockGenericStorage<ClipboardItem, ClipboardIndex>!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockGenericStorage<ClipboardItem, ClipboardIndex>()
        // 设置索引工厂，用于从 Item 生成 Index
        mockStorage.indexFactory = { ClipboardIndex(from: $0) }
        repository = ClipboardRepository(storage: mockStorage)
    }

    override func tearDown() async throws {
        repository = nil
        mockStorage = nil
        try await super.tearDown()
    }

    // MARK: - Flow Tests

    /// 全链路：addItem → 索引插入顶部 → 搜索命中 → togglePin → clearUnpinned 保留置顶 → deleteItem → clearAll
    func testFullClipboardLifecycleFlow() async throws {
        // Given - 连续添加两项
        let first = ClipboardItem(content: .text("第一条记录"))
        let second = ClipboardItem(content: .text("第二条记录 swift"))
        await repository.addItem(first)
        await repository.addItem(second)

        // Then - 新项插入索引顶部
        XCTAssertEqual(repository.totalCount, 2)
        XCTAssertEqual(repository.clipboardIndexes.map(\.id), [second.id, first.id], "新项应插入索引顶部")

        // When - 走存储层的搜索通路
        let searchResults = await repository.searchItems(query: "第二条")

        // Then - Mock 存储返回全部索引，验证仓库→存储调用通路可用
        XCTAssertEqual(searchResults.count, 2)

        // When - 内存搜索过滤（filteredIndexes 为同步计算属性，无 debounce 依赖）
        repository.searchText = "第二条"

        // Then - 只命中匹配项
        XCTAssertEqual(repository.filteredIndexes.map(\.id), [second.id], "内存过滤应命中搜索词")
        repository.searchText = ""

        // When - 置顶第一项
        await repository.togglePin(first)

        // Then - 内存索引与存储同步置顶
        XCTAssertTrue(repository.clipboardIndexes.first { $0.id == first.id }?.isPinned ?? false)
        XCTAssertEqual(repository.pinnedCount, 1)
        let storedFirst = try await mockStorage.read(id: first.id)
        XCTAssertTrue(storedFirst?.isPinned ?? false, "存储层应同步置顶状态")

        // When - 清理未置顶项
        await repository.clearUnpinned()

        // Then - 仅置顶项保留
        XCTAssertEqual(repository.totalCount, 1)
        XCTAssertEqual(repository.clipboardIndexes.first?.id, first.id, "置顶项应在清理后保留")

        // When - 删除剩余项
        let fetchedRemaining = await repository.getItem(id: first.id)
        let remaining = try XCTUnwrap(fetchedRemaining)
        await repository.deleteItem(remaining)

        // Then
        XCTAssertEqual(repository.totalCount, 0)
        let storedAfterDelete = try await mockStorage.read(id: first.id)
        XCTAssertNil(storedAfterDelete, "存储层应同步删除")

        // When - 再次添加后清空全部
        await repository.addItem(ClipboardItem(content: .text("待清空")))
        await repository.clearAll()

        // Then
        XCTAssertEqual(repository.totalCount, 0)
        let storedCount = try await mockStorage.count()
        XCTAssertEqual(storedCount, 0, "清空后存储层应为空")
    }

    /// 搜索词 + 仅看置顶 的组合过滤流程
    func testSearchAndPinnedFilterFlow() async throws {
        // Given
        let pinnedMatch = ClipboardItem(content: .text("Apple 置顶"), isPinned: true)
        let plainMatch = ClipboardItem(content: .text("Apple 普通"))
        let other = ClipboardItem(content: .text("Banana"))
        await repository.addItem(pinnedMatch)
        await repository.addItem(plainMatch)
        await repository.addItem(other)

        // When - 仅搜索（大小写不敏感）
        repository.searchText = "apple"

        // Then
        XCTAssertEqual(Set(repository.filteredIndexes.map(\.id)), Set([pinnedMatch.id, plainMatch.id]))

        // When - 叠加仅看置顶
        repository.showPinnedOnly = true

        // Then
        XCTAssertEqual(repository.filteredIndexes.map(\.id), [pinnedMatch.id], "组合过滤应只剩置顶匹配项")

        // When - 清除全部过滤条件
        repository.searchText = ""
        repository.showPinnedOnly = false

        // Then
        XCTAssertEqual(repository.filteredIndexes.count, 3, "清除条件后应返回全部")
    }

    /// 批量删除 + 使用计数流程
    func testBatchDeleteAndUseCountFlow() async throws {
        // Given
        let keep = ClipboardItem(content: .text("保留"))
        let drop1 = ClipboardItem(content: .text("删除1"))
        let drop2 = ClipboardItem(content: .text("删除2"))
        await repository.addItem(keep)
        await repository.addItem(drop1)
        await repository.addItem(drop2)

        // When - 连续递增使用计数（每次取最新项，与真实调用方式一致）
        await repository.incrementUseCount(keep)
        let fetchedKeep = await repository.getItem(id: keep.id)
        await repository.incrementUseCount(try XCTUnwrap(fetchedKeep))

        // Then - 索引同步最新计数
        XCTAssertEqual(repository.clipboardIndexes.first { $0.id == keep.id }?.useCount, 2)

        // When - 批量删除两条
        await repository.deleteItems([drop1, drop2])

        // Then - 仅保留目标项
        XCTAssertEqual(repository.totalCount, 1)
        XCTAssertEqual(repository.clipboardIndexes.first?.id, keep.id)
        let storedCount = try await mockStorage.count()
        XCTAssertEqual(storedCount, 1, "存储层也应只剩一条")
    }
}
