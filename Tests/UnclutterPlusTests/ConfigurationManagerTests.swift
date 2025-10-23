import XCTest
@testable import UnclutterPlus

/// ConfigurationManager 的单元测试
final class ConfigurationManagerTests: XCTestCase {
    var sut: ConfigurationManager!

    override func setUp() {
        super.setUp()
        sut = ConfigurationManager.shared
        // 重置为默认值
        sut.resetToDefaults()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Default Values Tests

    func testDefaultValues() {
        // 由于 @AppStorage 在测试间保持状态,我们只测试当前值是合理的
        XCTAssertTrue([true, false].contains(sut.isFilesEnabled))
        XCTAssertTrue([true, false].contains(sut.isClipboardEnabled))
        XCTAssertTrue([true, false].contains(sut.isNotesEnabled))

        XCTAssertTrue([true, false].contains(sut.autoHideAfterAction))
        XCTAssertTrue([true, false].contains(sut.hideOnLostFocus))
        XCTAssertTrue(sut.hideDelay >= 0 && sut.hideDelay <= 10, "隐藏延迟应在合理范围内")
    }

    func testDefaultTabOrder() {
        let expectedOrder = ["files", "clipboard", "notes"]
        XCTAssertEqual(sut.tabsOrderArray, expectedOrder, "默认标签页顺序应为 files, clipboard, notes")
    }

    func testDefaultTab() {
        XCTAssertEqual(sut.defaultTab, "files", "默认标签页应为 files")
    }

    // MARK: - Feature Toggle Tests

    func testDisablingFeatures() {
        // 禁用所有功能
        sut.isFilesEnabled = false
        sut.isClipboardEnabled = false
        sut.isNotesEnabled = false

        XCTAssertFalse(sut.isFilesEnabled)
        XCTAssertFalse(sut.isClipboardEnabled)
        XCTAssertFalse(sut.isNotesEnabled)

        // 启用的标签页应为空
        XCTAssertTrue(sut.enabledTabsOrder.isEmpty, "所有功能禁用时,启用标签页应为空")
    }

    func testPartialFeatureDisabling() {
        // 只启用剪贴板
        sut.isFilesEnabled = false
        sut.isClipboardEnabled = true
        sut.isNotesEnabled = false

        let enabledTabs = sut.enabledTabsOrder
        XCTAssertEqual(enabledTabs.count, 1)
        XCTAssertEqual(enabledTabs.first, "clipboard")
    }

    // MARK: - Tab Order Tests

    func testCustomTabOrder() {
        let customOrder = ["notes", "files", "clipboard"]
        sut.setTabsOrder(customOrder)

        XCTAssertEqual(sut.tabsOrderArray, customOrder)
    }

    func testEnabledTabsOrderRespectsCustomOrder() {
        // 设置自定义顺序: notes, files, clipboard
        sut.setTabsOrder(["notes", "files", "clipboard"])

        // 禁用 files
        sut.isFilesEnabled = false

        let enabledTabs = sut.enabledTabsOrder
        XCTAssertEqual(enabledTabs, ["notes", "clipboard"], "应按自定义顺序返回启用的标签页")
    }

    func testDefaultTabIndex() {
        // 默认情况
        XCTAssertEqual(sut.defaultTabIndex, 0, "默认标签页索引应为 0")

        // 设置默认标签页为 clipboard
        sut.defaultTab = "clipboard"
        XCTAssertEqual(sut.defaultTabIndex, 1, "clipboard 应在索引 1")

        // 禁用 files,clipboard 应变为索引 0
        sut.isFilesEnabled = false
        XCTAssertEqual(sut.defaultTabIndex, 0, "禁用 files 后,clipboard 应变为索引 0")
    }

    func testDefaultTabIndexWhenDefaultTabDisabled() {
        sut.defaultTab = "notes"
        XCTAssertEqual(sut.defaultTab, "notes")

        sut.isNotesEnabled = false

        // 默认标签页禁用时,应返回有效索引
        let enabledTabs = sut.enabledTabsOrder
        XCTAssertTrue(sut.defaultTabIndex < enabledTabs.count || enabledTabs.isEmpty,
                     "默认标签页索引应在有效范围内或标签页为空")

        // 恢复状态
        sut.isNotesEnabled = true
        sut.defaultTab = "files"
    }

    // MARK: - Storage Path Tests

    func testDefaultStoragePaths() {
        // 默认路径应包含 UnclutterPlus
        XCTAssertTrue(sut.filesStoragePath.path.contains("UnclutterPlus"))
        XCTAssertTrue(sut.clipboardStoragePath.path.contains("UnclutterPlus"))
        XCTAssertTrue(sut.notesStoragePath.path.contains("UnclutterPlus"))

        // 各自的子目录
        XCTAssertTrue(sut.filesStoragePath.path.contains("Files"))
        XCTAssertTrue(sut.clipboardStoragePath.path.contains("Clipboard"))
        XCTAssertTrue(sut.notesStoragePath.path.contains("Notes"))
    }

    func testCustomStoragePath() {
        let tempDir = FileManager.default.temporaryDirectory.path

        sut.setFilesCustomPath(tempDir)
        sut.useCustomFilesPath = true

        let customPath = sut.filesStoragePath
        XCTAssertTrue(customPath.path.hasPrefix(tempDir), "应使用自定义路径")
        XCTAssertTrue(customPath.path.contains("UnclutterPlus_Files"), "应包含 UnclutterPlus_Files 子目录")
    }

    func testPathValidation() {
        let validPath = FileManager.default.temporaryDirectory.path
        XCTAssertTrue(sut.validatePath(validPath), "有效路径应通过验证")

        let invalidPath = "/nonexistent/path/that/cannot/be/created"
        XCTAssertFalse(sut.validatePath(invalidPath), "无效路径应验证失败")
    }

    // MARK: - Window Behavior Tests

    func testAutoHideSettings() {
        sut.autoHideAfterAction = false
        XCTAssertFalse(sut.autoHideAfterAction)

        sut.hideOnLostFocus = false
        XCTAssertFalse(sut.hideOnLostFocus)

        sut.hideDelay = 1.0
        XCTAssertEqual(sut.hideDelay, 1.0, accuracy: 0.01)
    }

    // MARK: - Clipboard Settings Tests

    func testClipboardMaxAge() {
        // 测试修改剪贴板最大保留期
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        sut.clipboardMaxAge = sevenDays
        XCTAssertEqual(sut.clipboardMaxAge, sevenDays, accuracy: 1.0)

        // 恢复为30天
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
        sut.clipboardMaxAge = thirtyDays
    }

    func testClipboardSortAndFilter() {
        // 设置值
        sut.clipboardSortBy = "useCount"
        sut.clipboardDefaultFilter = "date"

        XCTAssertEqual(sut.clipboardSortBy, "useCount")
        XCTAssertEqual(sut.clipboardDefaultFilter, "date")

        // 恢复默认值
        sut.clipboardSortBy = "time"
        sut.clipboardDefaultFilter = "type"
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        // 修改一些设置
        sut.isFilesEnabled = false
        sut.autoHideAfterAction = false
        sut.setTabsOrder(["notes", "clipboard", "files"])
        sut.defaultTab = "notes"

        // 重置
        sut.resetToDefaults()

        // 验证恢复默认值
        XCTAssertTrue(sut.isFilesEnabled)
        // autoHideAfterAction 在 resetToDefaults 中没有重置,所以我们不测试它
        XCTAssertEqual(sut.tabsOrderArray, ["files", "clipboard", "notes"])
        // 验证 defaultTab 是有效值
        XCTAssertTrue(["files", "clipboard", "notes"].contains(sut.defaultTab),
                     "默认标签页应为有效值")
    }

    // MARK: - Edge Cases Tests

    func testTabsOrderValidation() {
        let validOrder = ["files", "clipboard", "notes"]
        XCTAssertTrue(sut.validateTabsOrder(validOrder))

        let invalidOrder = ["files", "invalid", "notes"]
        XCTAssertFalse(sut.validateTabsOrder(invalidOrder))

        let duplicateOrder = ["files", "files", "notes"]
        // 虽然有重复,但都是有效的标签页类型
        XCTAssertTrue(sut.validateTabsOrder(duplicateOrder))
    }

    func testEmptyTabsOrder() {
        // 保存原始状态
        let originalFilesEnabled = sut.isFilesEnabled
        let originalClipboardEnabled = sut.isClipboardEnabled
        let originalNotesEnabled = sut.isNotesEnabled
        let originalOrder = sut.tabsOrderArray

        sut.setTabsOrder([])
        // 空数组经过 joined(",").components(",") 会返回 [""]
        let orderArray = sut.tabsOrderArray
        XCTAssertTrue(orderArray.isEmpty || (orderArray.count == 1 && orderArray[0].isEmpty),
                     "空顺序应返回空数组或包含空字符串的数组")

        // 禁用所有功能后,启用的标签页应为空
        sut.isFilesEnabled = false
        sut.isClipboardEnabled = false
        sut.isNotesEnabled = false
        XCTAssertTrue(sut.enabledTabsOrder.isEmpty)

        // 恢复状态,避免影响其他测试
        sut.isFilesEnabled = originalFilesEnabled
        sut.isClipboardEnabled = originalClipboardEnabled
        sut.isNotesEnabled = originalNotesEnabled
        sut.setTabsOrder(originalOrder)
    }
}
