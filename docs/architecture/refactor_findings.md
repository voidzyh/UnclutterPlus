# UnclutterPlus 代码结构调研与重构建议

调研日期：2026-07-17 · 调研范围：`Sources/UnclutterPlus`（66 个 Swift 文件，16,506 行）

> 本文档记录深度结构调研结论。其中 P0（第二波死代码、双 AppDelegate 收敛方向、设置单源化）与 P1（笔记链拍平、Core→UI 反向依赖、配置合一）已纳入 2026-07 重构计划执行；P2 为未来 backlog。

## 1. 已确认并处理的问题（2026-07 重构）

- 两波死代码共约 -7,500 行（详见 git 历史 `0ec17bb`、`e0c351f`）
- 旧 `AppDelegate` 与新 `ModernAppDelegate` 并存；`WindowManager.swift` 曾对旧类做永远失败的 cast
- 菜单栏图标设置双键（`ShowMenuBarIcon` vs `ui.menuBarIcon.enabled`）已单源化
- `IndexDatabase`（FTS5）从未接线且恒为 nil，已随死代码删除

## 2. 架构层面的核心发现

### 2.1 双主窗口架构（重构方向：收敛到浮动面板）

- `App/ModernUnclutterPlusApp.swift`：`WindowGroup { UnifiedMainLayout() }`，导航 `UnifiedNavigationModel.selectedTab: AppTab`
- `Core/Monitoring/WindowManager.swift`：浮动 NSPanel 托管 `ModernMainContentView`，导航 `ModernMainContentViewModel.selectedTab: String`
- 第三套 `MainContentViewModel.selectedTab: Int`（已删除）
- `.showPreferences` 通知曾只有发布者、无观察者（Settings 按钮无效 bug）

### 2.2 笔记域三层状态镜像（P1 处理）

- `NotesService`（604 行）含 14 个 UI 态 @Published；`ModernNotesViewModel`（576 行）逐字段镜像 13 个属性并 10 处双写
- 过滤逻辑曾分叉（`NoteRepository.filteredIndexes` 收藏置顶 vs `NotesService.filteredNotes` 不置顶）
- 缓存曾多达 7 套实现；收敛方向：保留 `NotesService` 的 `LRUCache`（带 `removeNote` 精准失效），删除 `UnifiedNoteStorage` 的 `NoteCacheManager`

### 2.3 Core→UI 反向依赖

- `WindowManager` 直接实例化 UI 视图（改注入解决）
- `Core/Errors/GlobalErrorHandler.swift` 内的 `ErrorAlertView`（SwiftUI 视图，应移入 UI 层）
- `FavoriteFoldersManager` 直接调 `WindowManager.shared.hideWindowAfterAction`（改回调注入）
- `Preferences`（配置类）位于 `UI/Components/MarkdownPreferences.swift`（应并入 `ConfigurationManager`）

### 2.4 配置系统双轨

- `ConfigurationManager`（40+ @AppStorage 键）与 `Preferences`（MarkdownPreferences.swift）并存，`PreferencesView` 同时观察两者
- 菜单栏图标键已单源化（2026-07）；其余键的合并为 P1 工作

## 3. P2 Backlog（本次不做）

1. **错误系统收敛**：13 个错误枚举（`UnclutterError` 系 + `ClipboardError`/`FileError`/`NotesError`/`OCRError`/`AIServiceError`/`ObsidianError`/`StorageOperationError` 等）统一到一套
2. **存储层并发统一**：`ShardedStorage` GCD+barrier 与 `UnifiedNoteStorage` NSLock 混用，`waitForInit` 轮询忙等；建议 actor 化（Swift 6 会将 NSLock-in-async 警告升级为错误）
3. **ViewModel 模板去重**：`setupBindings + setupDebouncedSearch + applyFilters` 三段式在 Notes/Clipboard/Files VM 几乎逐行重复
4. **View/VM 状态双轨消除**：`ModernFilesView`、`ScreenshotsView`、`ModernClipboardView` 的 @State 与 VM @Published 同名字段手工同步
5. **PreferencesView 拆分**：849 行按 5 个 tab 拆文件
6. **命名统一**：结构稳定后去掉 `Modern` 前缀；统一三个 "Preferences" 命名
7. **`@StateObject` 包裹单例**反模式修正（应 `@ObservedObject`）：`InsightsView`、`GlobalErrorHandler`、`UnifiedMainLayout`
8. **剪贴板 O(N) 全量重载改增量**：任何 repository 变化都触发 `loadInitialData` 逐条重载

## 4. 状态管理画像（调研时点）

- 单例 21 个（`static let shared`），150 处 `.shared` 调用点分布 35 文件
- 23 个 ObservableObject 类；@MainActor 类 13 个；actor 仅 2 个（其一已删）
- 日志器 `StructuredLogger` 本身带 @Published（日志配置变化驱动 UI 刷新）
