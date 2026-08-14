import XCTest
@testable import UnclutterPlus

/// 剪贴板多选与合并粘贴测试：合并文本纯函数、选择状态、合并条件。
@MainActor
final class ClipboardMergeTests: XCTestCase {

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

    private func makeVM() -> ModernClipboardViewModel {
        ModernClipboardViewModel(repository: repository)
    }

    /// 轮询等待条件成立（repository 变更事件经 Task 异步应用）
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

    // MARK: - 合并文本（纯函数）

    func testMergedTextPreservesListOrderWithSeparator() {
        let items = [
            ClipboardItem(content: .text("first")),
            ClipboardItem(content: .text("second")),
            ClipboardItem(content: .text("third")),
        ]

        XCTAssertEqual(
            ModernClipboardViewModel.mergedText(for: items, separator: " | "),
            "first | second | third"
        )
        XCTAssertEqual(
            ModernClipboardViewModel.mergedText(for: items, separator: "\n"),
            "first\nsecond\nthird"
        )
    }

    func testMergedTextUsesPlaceholdersForNonTextItems() {
        let items = [
            ClipboardItem(content: .text("hello")),
            ClipboardItem(content: .image(Data([0x01]))),
            ClipboardItem(content: .file(URL(fileURLWithPath: "/tmp/report.pdf"))),
        ]

        XCTAssertEqual(
            ModernClipboardViewModel.mergedText(for: items, separator: ","),
            "hello,图片,report.pdf"
        )
    }

    // MARK: - 选择状态

    func testToggleSelectionAddsAndRemoves() async {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        let b = ClipboardItem(content: .text("b"))
        await repository.addItem(a)
        await repository.addItem(b)

        vm.toggleSelection(a)
        XCTAssertEqual(vm.selectedItemIds, [a.id])

        vm.toggleSelection(b)
        XCTAssertEqual(vm.selectedItemIds, [a.id, b.id])

        vm.toggleSelection(a)
        XCTAssertEqual(vm.selectedItemIds, [b.id])
    }

    func testToggleMultiSelectModeClearsSelectionOnExit() async {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        await repository.addItem(a)

        vm.toggleMultiSelectMode()
        XCTAssertTrue(vm.isMultiSelectMode)
        vm.toggleSelection(a)
        XCTAssertEqual(vm.selectedItemIds.count, 1)

        vm.toggleMultiSelectMode() // 退出
        XCTAssertFalse(vm.isMultiSelectMode)
        XCTAssertTrue(vm.selectedItemIds.isEmpty, "退出多选应清空选择")
    }

    func testSelectAllAndDeselectAll() async throws {
        let vm = makeVM()
        await repository.addItem(ClipboardItem(content: .text("a")))
        await repository.addItem(ClipboardItem(content: .text("b")))
        await repository.addItem(ClipboardItem(content: .text("c")))
        try await waitUntil { vm.clipboardItems.count == 3 }

        // 等待 VM 订阅到变更
        vm.selectAll()
        XCTAssertEqual(vm.selectedItemIds.count, 3)

        vm.deselectAll()
        XCTAssertTrue(vm.selectedItemIds.isEmpty)
    }

    // MARK: - 合并条件与顺序

    func testCanMergeRequiresAtLeastTwoSelections() async {
        let vm = makeVM()
        let a = ClipboardItem(content: .text("a"))
        let b = ClipboardItem(content: .text("b"))
        await repository.addItem(a)
        await repository.addItem(b)

        XCTAssertFalse(vm.canMerge)
        vm.toggleSelection(a)
        XCTAssertFalse(vm.canMerge)
        vm.toggleSelection(b)
        XCTAssertTrue(vm.canMerge)
    }

    func testOrderedSelectedItemsFollowsFilteredListOrder() async throws {
        let vm = makeVM()
        // 按时间先后添加：列表按最新在前排序
        let first = ClipboardItem(content: .text("first"))
        let second = ClipboardItem(content: .text("second"))
        let third = ClipboardItem(content: .text("third"))
        await repository.addItem(first)
        await repository.addItem(second)
        await repository.addItem(third)
        try await waitUntil { vm.clipboardItems.count == 3 }

        vm.selectAll()
        let ordered = vm.orderedSelectedItems

        XCTAssertEqual(ordered.count, 3)
        // 列表顺序 = 最新在前（与 repository 索引一致），合并应遵循该顺序
        XCTAssertEqual(ordered.map(\.id), vm.filteredItems.map(\.id))
    }
}
