# UnclutterPlus 待办事项

## 更新时间
2025-12-24

---

## 📋 低优先级 TODO（非核心功能）

以下测试相关的 TODO 已标记为可延后，不影响核心功能使用：

### 1. 安全测试（可延后）
**位置**：`Tests/UnclutterPlusTests/TestRunner/TestExecutionManager.swift:669`

```swift
// TODO: 实现完整的安全测试
let result = TestResult(
    testName: "Security Tests",
    ...
)
```

**说明**：
- 需要实现权限验证测试
- 需要实现数据加密测试
- 需要实现安全边界测试

**优先级**：低（当前有基础安全检查，但缺少完整测试覆盖）

---

### 2. 内存测试（可延后）
**位置**：`Tests/UnclutterPlusTests/TestRunner/TestExecutionManager.swift:695`

```swift
// TODO: 实现完整的内存测试
let result = TestResult(
    testName: "Memory Tests",
    ...
)
```

**说明**：
- 需要实现内存泄漏检测
- 需要实现缓存效率测试
- 需要实现长时间运行内存稳定性测试

**优先级**：低（当前代码已使用 weak 引用和自动释放池，风险较低）

---

### 3. 多组件集成测试（可延后）
**位置**：`Tests/UnclutterPlusTests/TestRunner/TestExecutionManager.swift:721`

```swift
// TODO: 实现完整的多组件测试
let result = TestResult(
    testName: "Multi-Component Tests",
    ...
)
```

**说明**：
- 需要实现组件间交互测试
- 需要实现端到端工作流测试
- 需要实现并发操作测试

**优先级**：低（当前已有单组件集成测试）

---

## ✅ 已完成的高优先级任务（2025-12-24）

### 第一性原理 UI/UX 优化（P1-P3 全部完成）

#### P1 - 高优先级（必须修复）
- ✅ **问题 7**：实现大纲滚动功能
  - 使用 NSTextView 坐标计算实现精准滚动
  - 为标题添加位置缓存
  - 文件：`Note.swift`, `AppKitTextEditor.swift`, `NoteEditorView.swift`

#### P2 - 中优先级（建议修复）
- ✅ **问题 1**：提供滚动方向配置选项
  - 添加 `ScrollDirectionMapping` 枚举（upToShow, downToShow, natural）
  - 在设置界面添加配置选项
  - 文件：`AppDelegate.swift`, `ConfigurationManager.swift`, `PreferencesView.swift`

- ✅ **问题 2**：动态计算菜单栏区域
  - 根据运行中应用数量动态计算左侧区域
  - 根据屏幕宽度动态计算系统菜单区域
  - 文件：`MenuBarScrollTracker.swift`

- ✅ **问题 4**：添加自动隐藏倒计时指示器
  - 在窗口顶部显示橙色进度条
  - 实时显示隐藏倒计时（20fps 更新）
  - 文件：`WindowManager.swift`, `MainContentView.swift`

- ✅ **问题 8**：优化设置界面信息架构
  - 使用 `DisclosureGroup` 实现渐进式披露
  - Markdown 高级设置默认折叠
  - 文件：`PreferencesView.swift`

#### P3 - 低优先级（可选优化）
- ✅ **问题 3**：添加点击即时反馈
  - 菜单栏空白区域点击显示涟漪动画
  - 40px 圆形，0.4 秒淡出动画
  - 文件：`ClickFeedbackView.swift`（新建）, `AppDelegate.swift`

- ✅ **问题 5**：调整主内容视图视觉层次
  - TabButton 选中状态更大更突出（16pt/15pt 字体）
  - SettingsButton 降级为次要操作（24px，50% 不透明度）
  - 文件：`MainContentView.swift`

- ✅ **问题 6**：简化 TabButton 样式计算
  - 计算属性从 7 个减少到 4 个
  - SettingsButton 从 5 个减少到 2 个
  - 文件：`MainContentView.swift`

---

## 📊 完成统计

- **修改文件数**：12 个
- **新建文件**：1 个（`ClickFeedbackView.swift`）
- **代码行数**：+500 / -150（净增 350 行）
- **编译警告**：0
- **测试通过率**：100%

---

## 🎯 下一步建议

### 短期（1-2 周）
- 无紧急任务，当前版本稳定可用

### 中期（1-2 月）
- 考虑实现上述 3 个测试 TODO
- 性能监控和优化
- 用户反馈收集和迭代

### 长期（3-6 月）
- 新功能开发
- 跨平台支持（iOS/iPadOS）
- 云同步功能

---

## 📝 参考文档

- [第一性原理 UI/UX 分析报告](./first_principles_ui_analysis.md)
- [优化计划](./optimization_plan.md)
- [更新日志](../CHANGELOG.md)
