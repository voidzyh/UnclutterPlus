# UnclutterPlus 架构与需求重评估（2026-08）

评估日期：2026-08-14 · 基线：`swift build` 通过、94 测试全绿、main @ `05f30a1`

本文档在 [refactor_findings.md](refactor_findings.md)（2026-07）与 [pending_tasks.md](../pending_tasks.md) 的基础上，对已完成的重构做收口核对，重新审视剩余债务与需求的优先级，并给出下一步推进计划。

---

## 1. 现状快照

### 1.1 刚收口的三笔重构（本评估前提交）

| 提交 | 内容 | 对应债务 |
|---|---|---|
| `1135f48` | 浮动面板现代化 + Core/UI 依赖倒置（contentFactory 注入、PreferencesWindowManager、AppTab、设计系统静态化） | 双主窗口收敛、Core→UI 反向依赖、`.showPreferences` 无观察者 bug |
| `44f61ea` | 笔记服务纯数据化（14 个 UI 态 @Published 移除、13 处双写镜像删除、awaitInitialLoad 竞态修复） | 笔记域三层状态镜像 |
| `05f30a1` | 功能流测试套件 ×5 + 存储目录可注入 | 测试基础设施 |

### 1.2 与 2026-07 调研结论的对照

- ✅ 双主窗口 → 单浮动面板（`WindowManager` 为唯一窗口宿主，`WindowGroup` 已不存在）
- ✅ 笔记三层状态镜像 → Service 纯数据 + VM 自持 UI 态
- ✅ Core→UI 反向依赖（WindowManager 建 UI、GlobalErrorHandler 含视图、FavoriteFoldersManager 调 WindowManager 单例）→ 全部改为注入/回调
- ✅ 设置按钮无观察者 bug → `ModernAppDelegate` 观察 `.showPreferences` + 复用窗口
- ⚠️ 配置双轨（`ConfigurationManager` vs `Preferences`）→ 尚未合并（`MarkdownPreferences.swift` 仍在）
- ⚠️ P2 八项技术债 → 基本未动（见 §2.3 重新定级）

---

## 2. 架构重评估

### 2.1 本次调研新发现的缺陷（重构遗留，按严重度排序）

1. **剪贴板指纹 bootstrap 有损（真实 bug）**：`ClipboardMonitor.bootstrapFingerprints` 用 `ClipboardIndex.preview`（文本截断 100 字符、文件只留 lastPathComponent）重建指纹，而采集时用全文/全路径。后果：重启后复制超过 100 字符的文本或任何文件，都会被当作新项重复入库，`useCount` 统计失真。**根因**：指纹是派生数据，却从未持久化，只能用有损 preview 反推。**修法**：把 `fingerprint` 提升为 `ClipboardItem` 一等字段（可空、向后兼容），索引透传。
2. **剪贴板 copy 不触发面板自动隐藏**：`ModernClipboardViewModel.copyToClipboard` 未调用 `hideWindowAfterAction(.clipboardCopied)`；`ScreenshotsViewModel` 三处都调用了。行为不一致，属 P0 面板链路完整性缺口。
3. **pin 能力存在但 UI 未接线**：`ClipboardRepository.togglePin`、`VM.pinItem` 齐备，`ClipboardItemRow` 只显示 pin 图标、无操作入口；`clearUnpinned` 同理。用户无法 pin → pin 形同虚设。

### 2.2 结构性判断（保留的架构方向）

- **单面板 + 依赖注入的方向正确**，不再回头做 WindowGroup 主窗口。
- **Service 纯数据化方向正确**，后续 Features 应延续（Screenshots 的 `ScreenshotManager` 仍混合 UI 态与数据态，是下一个候选）。
- **`ModernDesignSystem` 静态化正确**：主题状态从未被 UI 消费（`currentTheme`/`colorScheme` 无读者），删掉即减负。后续新颜色一律进 `ColorToken`，不再引入实例状态。
- **tab 常驻保活（keepAliveTab）**：以 4 个 tab 视图常驻内存换取切换零重建，符合"面板轻快"卖点；风险是 4 个 VM 全部 `@StateObject` 创建即开始订阅（含剪贴板全量加载）。若后续做启动性能优化，优先考虑 tab 懒加载已就绪（`visitedTabs` 已支持首启懒创建）。

### 2.3 技术债重新定级（取代 2026-07 P2 的粗略排序）

| 债务 | 新定级 | 理由 |
|---|---|---|
| 剪贴板指纹 bootstrap 有损 | **P0（bug）** | 数据正确性，已列入本轮修复 |
| 剪贴板 copy 不自动隐藏 / pin 未接线 | **P0（基线）** | 面板链路 + Maccy 基线对齐，本轮修复 |
| 文件面板拖出/QuickLook/Finder 揭示缺失 | **P0（基线）** | pending_tasks P0 明确项，下一轮 |
| 存储层并发统一（NSLock/GCD 混用 + `waitForInit` 忙等轮询） | **P1 高** | Swift 6 严格并发下 NSLock-in-async 会升级为编译错误；`waitForInit` 的 100ms 忙等浪费启动时间。建议 actor 化 + 用 `Task`/`AsyncStream` 替代轮询 |
| 剪贴板 O(N) 全量重载 | **P1 中** | `repository.objectWillChange` 任何变化都触发逐条 `getItem` 重载；应在 repository 上发布变更明细（item id + 类型）做增量合并 |
| 错误系统收敛（13 枚举 → 1 套） | **P1 中** | 真实债务，但对单一功能不阻塞；建议与存储 actor 化同批做（错误多集中在存储/服务层） |
| View/VM 状态双轨（Clipboard 视图 `@State searchText/selectedItem` 与 VM 并存） | **P1 中** | 拖慢剪贴板增量刷新改造，建议先收敛 |
| VM 三段式模板去重（setupBindings/debouncedSearch/applyFilters ×3） | **P2** | 可提取 `FilterableViewModel` 基类或组合，但风险是过早抽象 |
| 配置双轨合并（`MarkdownPreferences.Preferences` → `ConfigurationManager`） | **P2** | 改动面大（PreferencesView 同时观察两者），与 PreferencesView 拆分同批做 |
| `@StateObject` 包单例反模式 | **P2 低** | 全库仅剩 `InsightsView` 一处（`GlobalErrorHandler` 的视图、`UnifiedMainLayout` 已随死代码删除），一次小提交即可 |
| PreferencesView 拆分（849 行） | **P2 低** | 纯结构问题，不阻塞功能 |

---

## 3. 需求重评估

### 3.1 市场判断维持

[market_research.md](../product/market_research.md) 的核心结论不变：

- "开源版 Unclutter" 生态位成立且为空（该形态无开源竞品）
- Tahoe 内置剪贴板把第三方价值上移到**持久化 + 组织 + 搜索 + 自动化**——pin/排除规则/合并粘贴正是补位点
- 买断/开源 + 本地隐私是叙事武器；iCloud 同步是原版用户第一大痛点

### 3.2 按实现状态的优先级表（2026-08 更新）

| 项 | 状态 | 动作 |
|---|---|---|
| 面板唤出/隐藏/多屏定位 | 基本就绪（本轮外观已现代化） | 需真机回归验收 |
| 剪贴板 pin / 纯文本粘贴 / 密码管理器忽略 / 应用排除 | pin 未接线、忽略/排除缺失 | **本轮补全** |
| 剪贴板持久历史 + 搜索 + 计数 | ✅ 已就绪 | — |
| 文件拖入拖出 / Quick Look / Finder 揭示 | 缺失 | **下一轮** |
| 全局快捷键 + 键盘流 | ⌘⇧U 已接线 | 面板验收后细化 |
| iCloud 同步 | 未启动 | P1，技术方案先行（CloudKit vs 文件同步需调研） |
| 截图管理（归集 + Vision OCR 搜索） | 归集已有，OCR 走 Deepseek CLI | 本地 Vision OCR 是 P1 改造点 |
| Shortcuts / App Intents | 未启动 | P1 |
| 剪贴板合并粘贴 | 未启动 | P1（原版用户点名） |

### 3.3 明确不做（防止范围蔓延）

纯文件 shelf 单点、截图拍摄/标注、全功能笔记、跨平台、实时 AI 聚类（保留现有按需批处理）。

---

## 4. 推进计划（按轮）

1. **R1（本轮）剪贴板基线补全**：指纹持久化修复（§2.1-1）、密码管理器 ConcealedType 忽略 + 瞬态忽略、应用排除规则（Bundle ID 白名单配置）、pin/取消 pin/清除非 pin 接线、copy 后自动隐藏。配置项全部落 `ConfigurationManager` + 偏好设置 UI + 本地化。
2. **R2 文件面板基线**：拖出（`NSItemProvider`/file URL 拖拽）、Quick Look（`QLPreviewPanel`）、Finder 揭示 + 自动隐藏接线；补齐 Files 功能流测试。
3. **R3 存储层并发统一**：`ShardedStorage`/`UnifiedNoteStorage` actor 化、`waitForInit` 改 Task 化等待；顺带剪贴板增量刷新。
4. **R4 错误系统收敛 + 小修**：统一错误枚举、`InsightsView` `@StateObject`→`@ObservedObject`。
5. **R5 差异化启动**：iCloud 技术调研报告 → 立项。

每轮以"测试全绿 + 独立提交"为完成标准；文档随轮更新 [pending_tasks.md](../pending_tasks.md) 勾选状态。
