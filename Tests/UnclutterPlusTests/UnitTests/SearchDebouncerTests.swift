import XCTest
@testable import UnclutterPlus

/// 搜索防抖器测试：合并窗口内连续输入、间隔后触发、取消不触发。
@MainActor
final class SearchDebouncerTests: XCTestCase {

    func testCoalescesRapidChangesIntoOneCallback() async throws {
        var received: [String] = []
        let debouncer = SearchDebouncer(interval: 0.05) { query in
            received.append(query)
        }

        debouncer.queryChanged("a")
        debouncer.queryChanged("ab")
        debouncer.queryChanged("abc")

        // 窗口内不触发
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(received.isEmpty, "防抖窗口内不应触发回调")

        // 窗口结束后仅触发最后一次
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(received, ["abc"], "只应回调窗口内的最后一次查询")
    }

    func testFiresAfterIntervalForSingleChange() async throws {
        var received: [String] = []
        let debouncer = SearchDebouncer(interval: 0.03) { query in
            received.append(query)
        }

        debouncer.queryChanged("hello")

        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(received, ["hello"])
    }

    func testCancelSuppressesPendingCallback() async throws {
        var received: [String] = []
        let debouncer = SearchDebouncer(interval: 0.05) { query in
            received.append(query)
        }

        debouncer.queryChanged("pending")
        debouncer.cancel()

        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertTrue(received.isEmpty, "取消后不应触发回调")
    }
}
