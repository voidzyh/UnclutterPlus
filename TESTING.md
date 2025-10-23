# UnclutterPlus 测试文档

## 测试概述

本项目采用 **XCTest** 框架进行单元测试,测试覆盖核心业务逻辑和状态管理层。

---

## 测试统计

| 指标 | 数值 |
|------|------|
| 总测试数 | 47 |
| 通过率 | 100% |
| 测试类数 | 4 |
| 平均执行时间 | ~1.2 秒 |

---

## 测试类结构

### 1. ConfigurationManagerTests (18 测试)

**测试范围**: 全局配置管理器

**核心测试用例**:
```swift
// 默认值测试
func testDefaultValues()
func testDefaultTabOrder()
func testDefaultTab()

// 功能开关测试
func testDisablingFeatures()
func testPartialFeatureDisabling()

// 标签页顺序测试
func testCustomTabOrder()
func testEnabledTabsOrderRespectsCustomOrder()
func testDefaultTabIndex()
func testDefaultTabIndexWhenDefaultTabDisabled()

// 存储路径测试
func testDefaultStoragePaths()
func testCustomStoragePath()
func testPathValidation()

// 窗口行为测试
func testAutoHideSettings()

// 剪贴板设置测试
func testClipboardMaxAge()
func testClipboardSortAndFilter()

// 重置测试
func testResetToDefaults()

// 边界条件测试
func testTabsOrderValidation()
func testEmptyTabsOrder()
```

**测试要点**:
- `@AppStorage` 在测试间保持状态,需要谨慎处理
- 使用 `resetToDefaults()` 恢复初始状态
- 测试边界条件和异常输入

### 2. MainContentViewModelTests (11 测试)

**测试范围**: 主内容视图模型

**核心测试用例**:
```swift
// 初始化测试
func testInitialState()
func testInitialSelectionWithCustomDefaultTab()

// 标签页管理测试
func testTabIdentifier()
func testHasEnabledTabs()

// 配置同步测试
func testSynchronizationWhenTabsChange()
func testSelectedTabAdjustmentWhenCurrentTabDisabled()
func testSelectedTabPreservedWhenStillValid()

// 本地化测试
func testForceRefreshForLocalizationChange()

// 偏好设置测试
func testShowPreferences()

// 边界条件测试
func testEmptyEnabledTabs()
func testOnAppear()
```

**测试重点**:
- 标签页状态管理
- 配置变化响应
- 异常状态处理

### 3. ClipboardViewModelTests (17 测试)

**测试范围**: 剪贴板视图模型

**核心测试用例**:
```swift
// 初始化测试
func testInitialState()
func testDefaultFilterSetup()
func testCustomDefaultFilter()

// 过滤器测试
func testContentTypeFilter()
func testSearchTextFilter()
func testDateRangeFilter()

// 排序测试
func testSortByTime()
func testSortByUseCount()

// 选择测试
func testMultiSelectMode()

// 用户操作测试
func testClearSearch()
func testDeleteItems()

// 悬停状态测试
func testHoverState()
func testToolbarHoverState()

// 性能测试
func testSearchDebounce()

// 边界条件测试
func testEmptyFilteredItems()
func testMultipleFiltersCombination()
func testAvailableSourceApps()
```

**测试技术**:
- Combine 异步测试 (`XCTestExpectation`)
- 防抖动验证
- 状态组合测试

### 4. UnclutterPlusTests (1 测试)

**测试范围**: 基础功能验证

```swift
func testExample() {
    XCTAssertEqual(1 + 1, 2)
}
```

---

## 测试最佳实践

### 1. 测试命名规范

```swift
// ✅ 好的命名 - 描述性强
func testSelectedTabAdjustmentWhenCurrentTabDisabled()
func testSynchronizationWhenTabsChange()

// ❌ 差的命名 - 不清晰
func testTab()
func testConfig()
```

### 2. AAA 模式 (Arrange-Act-Assert)

```swift
func testMultiSelectMode() {
    // Arrange - 准备测试数据
    XCTAssertFalse(sut.isMultiSelectMode)

    // Act - 执行操作
    sut.toggleMultiSelectMode()

    // Assert - 验证结果
    XCTAssertTrue(sut.isMultiSelectMode)
}
```

### 3. 测试隔离

```swift
override func setUp() {
    super.setUp()
    // 每个测试前重置状态
    sut = MainContentViewModel()
    mockConfig.resetToDefaults()
}

override func tearDown() {
    // 清理资源
    sut = nil
    super.tearDown()
}
```

### 4. 异步测试

```swift
func testSearchDebounce() {
    let expectation = XCTestExpectation(description: "等待防抖动")

    sut.$filteredItems
        .dropFirst()
        .sink { _ in
            expectation.fulfill()
        }
        .store(in: &cancellables)

    sut.searchText = "test"

    wait(for: [expectation], timeout: 1.0)
}
```

---

## 测试覆盖策略

### 已覆盖区域 ✅
- ✅ ViewModel 状态管理
- ✅ ConfigurationManager 配置逻辑
- ✅ 过滤和排序算法
- ✅ 用户交互流程
- ✅ 边界条件和异常处理

### 待覆盖区域 📝
- ⏳ 文件管理器测试
- ⏳ 剪贴板管理器测试
- ⏳ 笔记管理器测试
- ⏳ 窗口管理器测试
- ⏳ 边缘触发系统测试
- ⏳ 集成测试

---

## 运行测试

### 命令行运行
```bash
# 运行所有测试
swift test

# 运行特定测试类
swift test --filter ConfigurationManagerTests

# 运行特定测试方法
swift test --filter MainContentViewModelTests/testInitialState

# 显示详细输出
swift test -v
```

### Xcode 运行
1. 打开 `Package.swift`
2. `⌘ + U` 运行所有测试
3. 点击测试导航器查看结果

---

## 性能基准测试

### 测试执行时间

| 测试类 | 测试数 | 执行时间 |
|--------|--------|----------|
| ConfigurationManagerTests | 18 | ~0.03s |
| MainContentViewModelTests | 11 | ~0.54s |
| ClipboardViewModelTests | 17 | ~0.37s |
| UnclutterPlusTests | 1 | ~0.00s |
| **总计** | **47** | **~1.15s** |

### 性能优化建议
- 避免在测试中执行实际文件 I/O
- 使用 Mock 对象替代真实依赖
- 并行运行独立测试

---

## 持续集成建议

### GitHub Actions 配置示例

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: swift test
```

### 测试质量门禁
- ✅ 100% 测试通过率
- ✅ 无编译警告
- ✅ 代码覆盖率 > 60%

---

## 测试维护指南

### 何时添加测试
1. ✅ 新增 ViewModel 时
2. ✅ 修改核心业务逻辑时
3. ✅ 修复 Bug 后 (回归测试)
4. ✅ 重构代码前 (保证行为不变)

### 测试维护原则
1. **快速反馈**: 测试应在 2 秒内完成
2. **可读性**: 测试即文档,应易于理解
3. **独立性**: 测试间不应有依赖
4. **确定性**: 相同输入应得到相同结果

### 处理脆弱测试
```swift
// ❌ 脆弱测试 - 依赖固定延迟
wait(for: [expectation], timeout: 5.0)

// ✅ 健壮测试 - 监听实际事件
sut.$filteredItems.sink { _ in expectation.fulfill() }
```

---

## 已知测试局限

### 1. `@AppStorage` 状态共享
**问题**: UserDefaults 在测试间共享状态

**解决方案**:
```swift
override func setUp() {
    // 每次测试前重置
    sut.resetToDefaults()
}

override func tearDown() {
    // 恢复原始状态
    sut.setTabsOrder(originalOrder)
}
```

### 2. 单例模式测试
**问题**: `ConfigurationManager.shared` 难以隔离

**当前方案**: 依赖注入 + 接受共享状态
**改进方向**: 使用协议抽象 + Mock 实现

---

## 测试报告示例

```
Test Suite 'All tests' passed at 2025-10-23 10:09:22.211.
     Executed 47 tests, with 0 failures (0 unexpected) in 1.144 (1.148) seconds

✅ ConfigurationManagerTests: 18/18 passed
✅ MainContentViewModelTests: 11/11 passed
✅ ClipboardViewModelTests: 17/17 passed
✅ UnclutterPlusTests: 1/1 passed
```

---

## 常见问题

### Q: 为什么有些测试不验证默认值?
A: 由于 `@AppStorage` 在测试间保持状态,部分测试调整为验证合理范围而非固定值。

### Q: 如何测试 SwiftUI View?
A: 当前专注于 ViewModel 测试。View 测试可使用 `ViewInspector` 库(未来扩展)。

### Q: 如何测试异步操作?
A: 使用 `XCTestExpectation` 和 Combine 的 `sink` 方法。

---

**文档版本**: v1.0
**最后更新**: 2025-10-23
**维护者**: UnclutterPlus Team
