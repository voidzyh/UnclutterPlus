import XCTest
import Combine
@testable import UnclutterPlus

/// 剪贴板仓库单元测试
@MainActor
final class ClipboardRepositoryTests: XCTestCase {
    
    var repository: ClipboardRepository!
    var mockStorage: MockGenericStorage<ClipboardItem, ClipboardIndex>!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        mockStorage = MockGenericStorage<ClipboardItem, ClipboardIndex>()
        
        // 设置索引工厂，用于从 Item 生成 Index
        mockStorage.indexFactory = { item in
            ClipboardIndex(from: item)
        }
        
        repository = ClipboardRepository(storage: mockStorage)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        repository = nil
        mockStorage = nil
        cancellables = nil
    }
    
    func testAddItem() async throws {
        // Given
        let item = ClipboardItem(content: .text("Test Content"))
        
        // When
        await repository.addItem(item)
        
        // Then
        let storedItem = try await mockStorage.read(id: item.id)
        XCTAssertNotNil(storedItem)
        XCTAssertEqual(repository.totalCount, 1)
        XCTAssertEqual(repository.clipboardIndexes.first?.id, item.id)
    }

    // MARK: - copyLatestItemToPasteboard（App Intents 数据源）

    func testCopyLatestItemWritesTextToPasteboard() async throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test.copyLatest.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        let item = ClipboardItem(content: .text("latest content"))
        await repository.addItem(item)

        let succeeded = await repository.copyLatestItemToPasteboard(pasteboard: pasteboard)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(pasteboard.string(forType: .string), "latest content")
    }

    func testCopyLatestItemReturnsFalseWhenEmpty() async {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test.copyLatest.empty.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        let succeeded = await repository.copyLatestItemToPasteboard(pasteboard: pasteboard)

        XCTAssertFalse(succeeded)
    }
    
    func testDeleteItem() async throws {
        // Given
        let item = ClipboardItem(content: .text("Delete Me"))
        await repository.addItem(item)
        
        // When
        await repository.deleteItem(item)
        
        // Then
        let storedItem = try await mockStorage.read(id: item.id)
        XCTAssertNil(storedItem)
        XCTAssertEqual(repository.totalCount, 0)
    }
    
    func testTogglePin() async throws {
        // Given
        let item = ClipboardItem(content: .text("Pin Me"))
        await repository.addItem(item)
        
        // When
        await repository.togglePin(item)
        
        // Then
        // 验证内存状态
        XCTAssertTrue(repository.clipboardIndexes.first?.isPinned == true)
        
        // 验证存储状态
        let storedItem = try await mockStorage.read(id: item.id)
        XCTAssertTrue(storedItem?.isPinned == true)
        
        // Toggle back
        await repository.togglePin(storedItem!)
        XCTAssertFalse(repository.clipboardIndexes.first?.isPinned == true)
    }
    
    func testSearch() async throws {
        // Given
        let item1 = ClipboardItem(content: .text("Apple Banana"))
        let item2 = ClipboardItem(content: .text("Orange Grape"))
        await repository.addItem(item1)
        await repository.addItem(item2)
        
        // MockStorage 的 search 默认返回所有，我们需要模拟 search 行为或者只测试 repository 的过滤逻辑
        // Repository 的 searchItems 方法直接调用 storage.search
        // 为了测试，我们需要在 MockStorage 中实现简单的过滤，或者验证调用
        
        // 让我们测试 Repository 的 filteredIndexes 属性（它在内存中过滤）
        
        // When
        repository.searchText = "Apple"
        
        // 等待 Combine 更新
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        let results = repository.filteredIndexes
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, item1.id)
    }
    
    func testClearAll() async throws {
        // Given
        await repository.addItem(ClipboardItem(content: .text("1")))
        await repository.addItem(ClipboardItem(content: .text("2")))
        
        // When
        await repository.clearAll()
        
        // Then
        XCTAssertEqual(repository.totalCount, 0)
        let indexes = try await mockStorage.getAllIndexes()
        XCTAssertTrue(indexes.isEmpty)
    }
}
