import XCTest
@testable import UnclutterPlus

/// 面板状态机流程级测试：仅覆盖不依赖窗口显示的非 UI 逻辑
/// 使用全新 WindowManager 实例（非 shared 单例），不触发真实 showWindow 动画
final class PanelStateTests: XCTestCase {

    var windowManager: WindowManager!
    var originalHideOnLostFocus: Bool!
    var originalAutoHideAfterAction: Bool!

    override func setUp() {
        super.setUp()
        // Given - 全新实例，避免 WindowManager.shared 单例副作用
        windowManager = WindowManager()
        // 保存全局配置原始值，tearDown 还原（UserDefaults 副作用最小化）
        let config = ConfigurationManager.shared
        originalHideOnLostFocus = config.hideOnLostFocus
        originalAutoHideAfterAction = config.autoHideAfterAction
    }

    override func tearDown() {
        let config = ConfigurationManager.shared
        config.hideOnLostFocus = originalHideOnLostFocus
        config.autoHideAfterAction = originalAutoHideAfterAction
        windowManager.cancelAutoHide()
        windowManager = nil
        super.tearDown()
    }

    // MARK: - Flow Tests

    /// 初始状态 + 无窗口守卫：未注入内容工厂时 prepareWindow/toggle/hide/动作后隐藏均安全无副作用
    func testWindowLessGuardsFlow() {
        // Given - 初始状态
        XCTAssertFalse(windowManager.isWindowVisible, "未创建窗口时默认为隐藏")
        XCTAssertEqual(windowManager.autoHideProgress, 0.0)

        // When - 未注入内容工厂时准备窗口（幂等 no-op）
        windowManager.prepareWindow()
        windowManager.prepareWindow()

        // Then - 不创建窗口
        XCTAssertNil(windowManager.window, "无内容工厂时不应创建窗口")
        XCTAssertFalse(windowManager.isWindowVisible)

        // When - 无窗口时执行切换/隐藏/各类型动作后隐藏/取消
        ConfigurationManager.shared.autoHideAfterAction = true
        windowManager.toggleWindow()
        windowManager.hideWindow()
        for action in [AutoHideAction.fileOpened, .fileShowInFinder, .clipboardCopied, .settingsOpened] {
            windowManager.hideWindowAfterAction(action, delay: 0.1)
        }
        windowManager.cancelAutoHide()

        // Then - 状态保持隐藏，无崩溃、无进度残留
        XCTAssertFalse(windowManager.isWindowVisible)
        XCTAssertEqual(windowManager.autoHideProgress, 0.0)
    }

    /// 动作后自动隐藏：总开关关闭时任何动作都不触发状态变化
    func testHideAfterActionRespectsMasterSwitchFlow() {
        // Given - 关闭「动作后自动隐藏」总开关
        ConfigurationManager.shared.autoHideAfterAction = false

        // When - 触发所有动作类型
        for action in [AutoHideAction.fileOpened, .fileShowInFinder, .clipboardCopied, .settingsOpened] {
            windowManager.hideWindowAfterAction(action, delay: 0.05)
        }

        // Then - 无任何状态变化
        XCTAssertFalse(windowManager.isWindowVisible)
        XCTAssertEqual(windowManager.autoHideProgress, 0.0)
    }

    /// 失去焦点自动隐藏：配置关闭时不启动倒计时
    func testAutoHideOnLostFocusDisabledByConfigFlow() {
        // Given - 关闭「失去焦点自动隐藏」
        ConfigurationManager.shared.hideOnLostFocus = false

        // When
        windowManager.checkAutoHideOnLostFocus()

        // Then - 倒计时进度保持 0
        XCTAssertEqual(windowManager.autoHideProgress, 0.0, "配置关闭时不应启动自动隐藏倒计时")
    }

    /// 失去焦点自动隐藏：编辑笔记期间被阻止，结束编辑后状态可复位
    func testAutoHideBlockedWhileEditingFlow() {
        // Given - 开启配置，但处于编辑状态
        ConfigurationManager.shared.hideOnLostFocus = true
        windowManager.setEditingNote(true)

        // When
        windowManager.checkAutoHideOnLostFocus()

        // Then - 编辑状态阻止自动隐藏，进度保持 0
        XCTAssertEqual(windowManager.autoHideProgress, 0.0, "编辑笔记期间不应启动自动隐藏")

        // When - 结束编辑并取消自动隐藏
        windowManager.setEditingNote(false)
        windowManager.cancelAutoHide()

        // Then - 状态复位
        XCTAssertEqual(windowManager.autoHideProgress, 0.0)
        XCTAssertFalse(windowManager.isWindowVisible)
    }
}
