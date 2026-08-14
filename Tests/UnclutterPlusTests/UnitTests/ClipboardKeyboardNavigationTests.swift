import XCTest
@testable import UnclutterPlus

/// 剪贴板键盘导航测试：方向键移动高亮、回车激活、删除后选择一致性。
@MainActor
final class ClipboardKeyboardNavigationTests: XCTestCase {

    private var mockStorage: CountingClipboardStorage!
    private var repository: ClipboardRepository!

    override func setUp() async throws {
        mockStorage = CountingClipboardStorage()
        repository = ClipboardRepository(storage: mockStorage)
    }

    override func tearDown() async throws {
        mockStorage = nil
        repository = nil
    }

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

    private func makeVM() -> ModernClipboardViewModel {
        ModernClipboardViewModel(repository: repository)
    }

    // MARK: - 方向键导航

    func testMoveSelectionDownFollowsFilteredOrderAndClamps() async throws {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        let b = ClipboardItem(content: .text("b"))
        let c = ClipboardItem(content: .text("c"))
        await repository.addItem(a)
        await repository.addItem(b)
        await repository.addItem(c)
        try await waitUntil { vm.clipboardItems.count == 3 }

        // 无高亮 → 下移选中第一项
        XCTAssertNil(vm.selectedItemID)
        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedItemID, vm.filteredItems[0].id)

        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedItemID, vm.filteredItems[1].id)

        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedItemID, vm.filteredItems[2].id)

        // 末尾继续下移 → 保持（clamp）
        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedItemID, vm.filteredItems[2].id)
    }

    func testMoveSelectionUpFromTopStaysAtTop() async throws {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        let b = ClipboardItem(content: .text("b"))
        await repository.addItem(a)
        await repository.addItem(b)
        try await waitUntil { vm.clipboardItems.count == 2 }

        vm.moveSelectionDown()
        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedItemID, vm.filteredItems[1].id)

        vm.moveSelectionUp()
        XCTAssertEqual(vm.selectedItemID, vm.filteredItems[0].id)

        vm.moveSelectionUp()
        XCTAssertEqual(vm.selectedItemID, vm.filteredItems[0].id, "顶部继续上移应保持")
    }

    // MARK: - 回车激活

    func testActivateSelectionTogglesSelectionInMultiSelectMode() async throws {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        await repository.addItem(a)
        try await waitUntil { vm.clipboardItems.count == 1 }

        vm.isMultiSelectMode = true
        vm.select(a)

        await vm.activateSelection()
        XCTAssertEqual(vm.selectedItemIds, [a.id], "多选模式下回车应切换选择")

        await vm.activateSelection()
        XCTAssertTrue(vm.selectedItemIds.isEmpty, "再次回车应取消选择")
    }

    // MARK: - 删除后选择一致性

    func testSelectionClearedWhenHighlightedItemRemoved() async throws {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        let b = ClipboardItem(content: .text("b"))
        await repository.addItem(a)
        await repository.addItem(b)
        try await waitUntil { vm.clipboardItems.count == 2 }

        vm.select(a)
        XCTAssertEqual(vm.selectedItemID, a.id)

        await repository.deleteItem(a)
        try await waitUntil { vm.clipboardItems.count == 1 }
        XCTAssertNil(vm.selectedItemID, "高亮项被删除后选择应清空")
    }

    func testSelectionClearedOnClearAll() async throws {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        await repository.addItem(a)
        try await waitUntil { vm.clipboardItems.count == 1 }

        vm.select(a)
        await repository.clearAll()
        try await waitUntil { vm.clipboardItems.isEmpty }
        XCTAssertNil(vm.selectedItemID)
    }
}
