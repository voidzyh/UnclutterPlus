import XCTest
import Combine
@testable import UnclutterPlus

/// 剪贴板增量刷新测试：验证 VM 按变更明细合并，而非每次变更全量重读存储。
/// 通过统计存储层 read 调用次数证明增量语义。
@MainActor
final class ClipboardIncrementalRefreshTests: XCTestCase {

    private var mockStorage: CountingClipboardStorage!
    private var repository: ClipboardRepository!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockStorage = CountingClipboardStorage()
        repository = ClipboardRepository(storage: mockStorage)
        cancellables = []
    }

    override func tearDown() async throws {
        mockStorage = nil
        repository = nil
        cancellables = nil
    }

    /// 轮询等待条件成立（事件经 PassthroughSubject → Task 异步应用）
    private func waitUntil(
        timeout: TimeInterval = 2.0,
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("waitUntil 超时")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    // MARK: - 增量语义

    func testAddedEventMergesWithoutFullReload() async throws {
        // Given - 存量项直接进存储（repository itemCache 为冷），模拟"历史数据"场景
        let a = ClipboardItem(content: .text("alpha"))
        let b = ClipboardItem(content: .text("beta"))
        try await mockStorage.create([a, b])
        await repository.loadIndexes()

        // VM 初始加载（冷缓存：读取 2 次）
        let viewModel = ModernClipboardViewModel(repository: repository)
        try await waitUntil { viewModel.clipboardItems.count == 2 }
        let readsBefore = mockStorage.readCallCount

        // When - 新增一项（Monitor 路径）
        let c = ClipboardItem(content: .text("gamma"))
        await repository.addItem(c)
        try await waitUntil { viewModel.clipboardItems.count == 3 }

        // Then - 新项插入头部；存量项未被重读（旧实现的全量重载会冷读全部存量项）
        XCTAssertEqual(viewModel.clipboardItems.first?.id, c.id, "新项应插入列表头部")
        XCTAssertEqual(mockStorage.readCallCount - readsBefore, 0, "增量合并不应重读存量项（全量重载会触发 N 次读取）")
    }

    func testUpdatedEventReplacesItemInPlace() async throws {
        let item = ClipboardItem(content: .text("origin"))
        await repository.addItem(item)

        let viewModel = ModernClipboardViewModel(repository: repository)
        try await waitUntil { viewModel.clipboardItems.count == 1 }

        // When - 使用计数 +1（Monitor 重复采集路径）
        await repository.incrementUseCount(item)
        try await waitUntil { viewModel.clipboardItems.first?.useCount == 1 }

        // Then
        XCTAssertEqual(viewModel.clipboardItems.count, 1)
        XCTAssertEqual(viewModel.clipboardItems.first?.id, item.id)
        XCTAssertEqual(viewModel.clipboardItems.first?.useCount, 1)
    }

    func testRemovedEventRemovesWithoutReads() async throws {
        let a = ClipboardItem(content: .text("keep"))
        let b = ClipboardItem(content: .text("drop"))
        await repository.addItem(a)
        await repository.addItem(b)

        let viewModel = ModernClipboardViewModel(repository: repository)
        try await waitUntil { viewModel.clipboardItems.count == 2 }
        let readsBefore = mockStorage.readCallCount

        // When - 删除一项
        await repository.deleteItem(b)
        try await waitUntil { viewModel.clipboardItems.count == 1 }

        // Then - 删除不需要任何读取
        XCTAssertEqual(viewModel.clipboardItems.first?.id, a.id)
        XCTAssertEqual(mockStorage.readCallCount, readsBefore, "删除事件不应触发存储读取")
    }

    func testClearedEventEmptiesList() async throws {
        let a = ClipboardItem(content: .text("one"))
        let b = ClipboardItem(content: .text("two"))
        await repository.addItem(a)
        await repository.addItem(b)

        let viewModel = ModernClipboardViewModel(repository: repository)
        try await waitUntil { viewModel.clipboardItems.count == 2 }

        // When
        await repository.clearAll()
        try await waitUntil { viewModel.clipboardItems.isEmpty }

        // Then
        XCTAssertTrue(viewModel.clipboardItems.isEmpty)
        XCTAssertTrue(viewModel.filteredItems.isEmpty)
    }

    func testPinTogglePropagatesToViewModel() async throws {
        let item = ClipboardItem(content: .text("pinnable"))
        await repository.addItem(item)

        let viewModel = ModernClipboardViewModel(repository: repository)
        try await waitUntil { viewModel.clipboardItems.count == 1 }

        // When
        await viewModel.pinItem(item)
        try await waitUntil { viewModel.clipboardItems.first?.isPinned == true }

        // Then
        XCTAssertTrue(viewModel.clipboardItems.first?.isPinned ?? false)
    }
}

// MARK: - 计数版内存存储（验证增量读取次数）

/// 记录 read 调用次数的内存存储，用于断言「无全量重载」。
final class CountingClipboardStorage: UnifiedStorageProtocol {
    typealias Item = ClipboardItem
    typealias Index = ClipboardIndex

    private(set) var items: [UUID: ClipboardItem] = [:]
    private(set) var readCallCount = 0

    func create(_ items: [ClipboardItem]) async throws {
        for item in items {
            self.items[item.id] = item
        }
    }

    func read(id: UUID) async throws -> ClipboardItem? {
        readCallCount += 1
        return items[id]
    }

    func readBatch(ids: [UUID]) async throws -> [ClipboardItem] {
        readCallCount += ids.count
        return ids.compactMap { items[$0] }
    }

    func update(_ items: [ClipboardItem]) async throws {
        for item in items where self.items[item.id] != nil {
            self.items[item.id] = item
        }
    }

    func delete(ids: [UUID]) async throws {
        for id in ids {
            items.removeValue(forKey: id)
        }
    }

    func search(query: String, limit: Int?) async throws -> [ClipboardIndex] {
        items.values.sorted { $0.timestamp > $1.timestamp }.map(ClipboardIndex.init(from:))
    }

    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [ClipboardIndex] {
        var sorted = items.values.sorted { $0.timestamp > $1.timestamp }.map(ClipboardIndex.init(from:))
        if let offset = offset {
            sorted = Array(sorted.dropFirst(offset))
        }
        if let limit = limit {
            sorted = Array(sorted.prefix(limit))
        }
        return sorted
    }

    func filter(by predicate: @escaping (ClipboardIndex) -> Bool, limit: Int?) async throws -> [ClipboardIndex] {
        try await getAllIndexes(limit: limit, offset: nil).filter(predicate)
    }

    func count() async throws -> Int {
        items.count
    }

    func clear() async throws {
        items.removeAll()
    }

    func getStatistics() async throws -> StorageStatistics {
        StorageStatistics(
            totalItems: items.count,
            totalSize: 0,
            cacheSize: items.count,
            lastModified: Date(),
            storageType: .simple
        )
    }
}
