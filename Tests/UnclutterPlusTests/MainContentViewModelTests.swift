import XCTest
import Combine
@testable import UnclutterPlus

/// MainContentViewModel 的单元测试
final class MainContentViewModelTests: XCTestCase {
    var sut: MainContentViewModel!
    var mockConfig: ConfigurationManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockConfig = ConfigurationManager.shared
        mockConfig.resetToDefaults()
        sut = MainContentViewModel(config: mockConfig)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockConfig = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(sut.selectedTab, 0, "初始选中标签页应为 0")
        XCTAssertEqual(sut.enabledTabs, ["files", "clipboard", "notes"], "默认应启用所有标签页")
        XCTAssertTrue(sut.hasEnabledTabs, "应有启用的标签页")
    }

    func testInitialSelectionWithCustomDefaultTab() {
        mockConfig.defaultTab = "clipboard"
        let viewModel = MainContentViewModel(config: mockConfig)

        XCTAssertEqual(viewModel.selectedTab, 1, "应选中 clipboard 标签页")
    }

    // MARK: - Tab Management Tests

    func testTabIdentifier() {
        XCTAssertEqual(sut.tabIdentifier(at: 0), "files")
        XCTAssertEqual(sut.tabIdentifier(at: 1), "clipboard")
        XCTAssertEqual(sut.tabIdentifier(at: 2), "notes")
        XCTAssertNil(sut.tabIdentifier(at: 99), "越界索引应返回 nil")
    }

    func testHasEnabledTabs() {
        XCTAssertTrue(sut.hasEnabledTabs)

        // 禁用所有功能
        mockConfig.isFilesEnabled = false
        mockConfig.isClipboardEnabled = false
        mockConfig.isNotesEnabled = false

        sut.handleAppDidBecomeActive()

        XCTAssertFalse(sut.hasEnabledTabs, "所有功能禁用时应返回 false")
    }

    // MARK: - Configuration Synchronization Tests

    func testSynchronizationWhenTabsChange() {
        let expectation = XCTestExpectation(description: "等待标签页更新")

        sut.$enabledTabs
            .dropFirst() // 跳过初始值
            .sink { tabs in
                XCTAssertEqual(tabs, ["clipboard", "notes"])
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // 禁用 files
        mockConfig.isFilesEnabled = false

        wait(for: [expectation], timeout: 1.0)
    }

    func testSelectedTabAdjustmentWhenCurrentTabDisabled() {
        // 选中 notes (索引 2)
        sut.selectedTab = 2

        // 禁用 notes
        mockConfig.isNotesEnabled = false
        sut.handleAppDidBecomeActive()

        // 应调整到有效索引
        XCTAssertTrue(sut.selectedTab < sut.enabledTabs.count, "应调整到有效索引")
    }

    func testSelectedTabPreservedWhenStillValid() {
        sut.selectedTab = 1 // clipboard

        // 禁用 files,不影响当前选中的 clipboard
        mockConfig.isFilesEnabled = false
        sut.handleAppDidBecomeActive()

        // clipboard 现在是索引 0
        XCTAssertEqual(sut.selectedTab, 0, "应调整索引但保持选中 clipboard")
        XCTAssertEqual(sut.tabIdentifier(at: sut.selectedTab), "clipboard")
    }

    // MARK: - Localization Tests

    func testForceRefreshForLocalizationChange() {
        let oldToken = sut.refreshToken

        sut.forceRefreshForLocalizationChange()

        XCTAssertNotEqual(sut.refreshToken, oldToken, "刷新令牌应改变")
    }

    // MARK: - Preferences Tests

    func testShowPreferences() {
        // 此测试验证方法调用不崩溃
        XCTAssertNoThrow(sut.showPreferences())
    }

    // MARK: - Edge Cases Tests

    func testEmptyEnabledTabs() {
        mockConfig.isFilesEnabled = false
        mockConfig.isClipboardEnabled = false
        mockConfig.isNotesEnabled = false

        sut.handleAppDidBecomeActive()

        XCTAssertTrue(sut.enabledTabs.isEmpty)
        XCTAssertEqual(sut.selectedTab, 0, "空标签页时应重置为 0")
        XCTAssertNil(sut.tabIdentifier(at: 0))
    }

    func testOnAppear() {
        mockConfig.defaultTab = "notes"
        mockConfig.isFilesEnabled = false

        sut.onAppear()

        // 验证配置同步
        XCTAssertFalse(sut.enabledTabs.contains("files"))
    }
}
