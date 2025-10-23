# UnclutterPlus 架构文档

## 概述

UnclutterPlus 采用现代化的 **MVVM (Model-View-ViewModel)** 架构模式,结合 **SwiftUI** 和 **Combine** 响应式编程框架构建。项目通过清晰的分层设计实现了高可维护性和可测试性。

---

## 架构层次

### 1. View 层 (SwiftUI Views)

**职责**: UI渲染和用户交互

**核心组件**:
- `MainContentView`: 主界面容器,管理标签页切换
- `FilesView`: 文件管理界面
- `ClipboardView`: 剪贴板历史界面
- `NotesView`: Markdown笔记界面
- `PreferencesView`: 设置面板

**特点**:
- 使用 `@StateObject` 和 `@ObservedObject` 绑定 ViewModel
- 声明式 UI,响应状态变化自动更新
- 无业务逻辑,所有逻辑委托给 ViewModel

### 2. ViewModel 层

**职责**: 状态管理和业务逻辑

**核心组件**:
- `MainContentViewModel`: 标签页状态和配置同步
- `FilesViewModel`: 文件过滤、搜索和操作
- `ClipboardViewModel`: 剪贴板过滤、排序和管理
- `NotesViewModel`: 笔记编辑和布局管理

**设计模式**:
```swift
final class ExampleViewModel: ObservableObject {
    // Published 状态
    @Published var searchText: String = ""
    @Published private(set) var filteredItems: [Item] = []

    // 依赖注入
    private let manager: DataManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: DataManager = .shared) {
        self.manager = manager
        observeChanges()
    }

    // 公共方法
    func performAction() {
        // 业务逻辑
    }

    // 私有辅助方法
    private func observeChanges() {
        // Combine 响应式订阅
    }
}
```

**核心特性**:
- 依赖注入支持单元测试
- Combine 防抖动优化性能
- 明确的状态更新边界
- 职责单一,易于维护

### 3. Model 层

**职责**: 数据结构和业务实体

**核心模型**:
- `TempFile`: 临时文件模型
- `ClipboardItem`: 剪贴板项目
- `Note`: Markdown 笔记
- `ClipboardContent`: 剪贴板内容枚举

### 4. Manager 层

**职责**: 数据持久化和系统交互

**核心管理器**:
- `ConfigurationManager`: 全局配置管理 (@AppStorage)
- `ClipboardManager`: 剪贴板监听和存储
- `NotesManager`: 笔记文件管理
- `TempFileManager`: 临时文件操作
- `WindowManager`: 窗口显示和自动隐藏

---

## 数据流架构

```
User Interaction
    ↓
  View (SwiftUI)
    ↓
ViewModel (@Published)
    ↓
Manager (Data Operations)
    ↓
File System / UserDefaults
    ↓
Combine Publishers
    ↓
ViewModel (Update @Published)
    ↓
View (Auto Update)
```

---

## 核心设计原则

### 1. 单一职责原则 (SRP)
- ViewModel 只管理状态
- Manager 只处理数据
- View 只渲染 UI

### 2. 依赖注入
```swift
// ✅ 好的设计 - 可测试
init(clipboardManager: ClipboardManager = .shared,
     config: ConfigurationManager = .shared)

// ❌ 差的设计 - 硬编码依赖
init() {
    self.manager = ClipboardManager.shared
}
```

### 3. 响应式编程
```swift
// 使用 Combine 处理异步事件
$searchText
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { [weak self] _ in
        self?.updateFilteredItems()
    }
    .store(in: &cancellables)
```

### 4. 状态不可变性
```swift
// ViewModel 对外暴露只读状态
@Published private(set) var filteredItems: [Item] = []

// 公共方法更新状态
func updateFilter() {
    filteredItems = computeFiltered()
}
```

---

## 关键技术实现

### 1. 配置管理 (@AppStorage)

```swift
class ConfigurationManager: ObservableObject {
    @AppStorage("feature.files.enabled") var isFilesEnabled: Bool = true

    // 计算属性实现动态配置
    var enabledTabsOrder: [String] {
        var tabs: [String] = []
        if isFilesEnabled { tabs.append("files") }
        if isClipboardEnabled { tabs.append("clipboard") }
        if isNotesEnabled { tabs.append("notes") }
        return tabs
    }
}
```

### 2. 窗口管理 (NSPanel + SwiftUI)

```swift
class KeyboardSupportPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // 解决浮动窗口键盘输入问题
}
```

### 3. 边缘触发系统

```swift
// 滚轮或双指滑动触发
EdgeMouseTracker(
    onEdgeTriggered: { direction in
        self.handleEdgeTrigger(direction: direction)
    },
    scrollDirection: .both,
    gestureType: .twoFingerDown
)
```

### 4. 多屏幕适配

```swift
// 智能检测屏幕布局
if hasScreenAbove {
    y = screenFrame.maxY - windowFrame.height - margin * 3
} else {
    y = screenFrame.maxY - windowFrame.height - margin
}
```

---

## 测试架构

### 单元测试覆盖

**测试类型**:
1. **ViewModel 测试** - 状态管理逻辑
2. **ConfigurationManager 测试** - 配置持久化
3. **业务逻辑测试** - 过滤、排序算法

**测试示例**:
```swift
final class MainContentViewModelTests: XCTestCase {
    var sut: MainContentViewModel!
    var mockConfig: ConfigurationManager!

    override func setUp() {
        mockConfig = ConfigurationManager.shared
        mockConfig.resetToDefaults()
        sut = MainContentViewModel(config: mockConfig)
    }

    func testTabManagement() {
        XCTAssertEqual(sut.selectedTab, 0)
        XCTAssertEqual(sut.enabledTabs, ["files", "clipboard", "notes"])
    }
}
```

**测试指标**:
- ✅ 47 个单元测试
- ✅ 100% 通过率
- ✅ 覆盖核心 ViewModel 和 Manager

---

## 性能优化

### 1. 防抖动 (Debounce)
```swift
$searchText
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { [weak self] _ in self?.updateFilteredItems() }
```

### 2. 缓存过滤结果
```swift
@Published private(set) var filteredItems: [Item] = []

private func updateFilteredItems() {
    // 只在必要时重新计算
    filteredItems = items.filter { /* 过滤逻辑 */ }
}
```

### 3. 惰性计算
```swift
var sortedFiles: [TempFile] {
    files.sorted(by: sortOption)
}
```

---

## 未来扩展点

### 1. 插件系统
- 定义 `PluginProtocol`
- 动态加载第三方功能

### 2. 云同步
- 抽象 `SyncEngine` 协议
- 支持 iCloud/Dropbox

### 3. 快捷动作
- 定义 `Action` 协议
- 可配置的快捷操作

---

## 依赖关系图

```
UnclutterPlusApp
    ├── AppDelegate
    │   └── WindowManager
    │       ├── EdgeMouseTracker
    │       └── MainContentView
    │           └── MainContentViewModel
    │               ├── ConfigurationManager
    │               └── [FilesView, ClipboardView, NotesView]
    │                   └── [FilesViewModel, ClipboardViewModel, NotesViewModel]
    │                       └── [TempFileManager, ClipboardManager, NotesManager]
    └── PreferencesWindowManager
        └── PreferencesView
```

---

## 编码规范

### 命名约定
- **View**: `*View.swift`
- **ViewModel**: `*ViewModel.swift`
- **Manager**: `*Manager.swift`
- **Model**: 无后缀 (如 `TempFile.swift`)

### 文件组织
```
Sources/UnclutterPlus/
├── App
│   ├── UnclutterPlusApp.swift
│   └── AppDelegate.swift
├── Views
│   ├── MainContentView.swift
│   ├── FilesView.swift
│   ├── ClipboardView.swift
│   └── NotesView.swift
├── ViewModels
│   ├── MainContentViewModel.swift
│   ├── FilesViewModel.swift
│   ├── ClipboardViewModel.swift
│   └── NotesViewModel.swift
├── Managers
│   ├── ConfigurationManager.swift
│   ├── WindowManager.swift
│   └── ...
└── Models
    ├── TempFile.swift
    └── ...
```

---

## 参考资源

- [Swift 官方文档](https://swift.org/documentation/)
- [SwiftUI 官方教程](https://developer.apple.com/tutorials/swiftui)
- [Clean Architecture SwiftUI](https://github.com/nalexn/clean-architecture-swiftui)
- [Combine 框架指南](https://developer.apple.com/documentation/combine)

---

**文档版本**: v1.0
**最后更新**: 2025-10-23
**维护者**: UnclutterPlus Team
