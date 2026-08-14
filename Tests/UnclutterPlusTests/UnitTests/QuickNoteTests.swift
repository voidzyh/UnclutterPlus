import XCTest
@testable import UnclutterPlus

/// 菜单栏迷你速记测试：标题生成纯函数。
final class QuickNoteTests: XCTestCase {

    func testTitleUsesFirstLine() {
        XCTAssertEqual(
            QuickNoteView.title(for: "今天的三件事\n1. 写代码\n2. 测试"),
            "今天的三件事"
        )
    }

    func testTitleTruncatesToThirtyCharacters() {
        let long = String(repeating: "长", count: 50)
        XCTAssertEqual(QuickNoteView.title(for: long).count, 30)
    }

    func testTitleFallsBackForEmptyContent() {
        let title = QuickNoteView.title(for: "   \n\n  ")
        XCTAssertFalse(title.isEmpty)
        XCTAssertEqual(title, "quicknote.default_title".localized)
    }

    func testTitleTrimsWhitespaceAroundFirstLine() {
        XCTAssertEqual(QuickNoteView.title(for: "  标题周围有空格  \n正文"), "标题周围有空格")
    }
}
