# UnclutterPlus 待办事项

## 更新时间
2026-08-14（勾选同步：Shortcuts/迷你速记/VM 去重/PreferencesView 拆分与提交记录对齐）
2026-07-17（重构后重排，依据 [市场调研](product/market_research.md) 与 [代码结构调研](architecture/refactor_findings.md)）

---

## 🎯 功能 Backlog

### P0 — 立足基本盘（对齐原版 Unclutter 体验并修其短板）

- [ ] 浮动面板全链路稳定（唤出/隐藏/自动隐藏/多屏定位）——重构后首要验收项（代码侧已收敛，需真机回归；回归清单与性能埋点已备：[maintenance/panel_regression_2026-08.md](maintenance/panel_regression_2026-08.md)）
- [x] 剪贴板基线：pin、纯文本粘贴、应用排除规则、密码管理器内容自动忽略（对齐 Maccy）——2026-08 完成
- [x] 文件暂存基线：拖入拖出、Quick Look 预览、Finder 揭示——2026-08 完成（暂存架重建，与收藏文件夹共存）
- [x] 全局快捷键 + 键盘优先操作流——2026-08 完成（⌘⇧U 唤出/隐藏、Esc 隐藏、剪贴板方向键高亮 + 回车复制）
- [ ] 面板唤出速度与内存占用达标——启动 99ms 已达标（2026-08 实测打点）；唤出/隐藏耗时与内存埋点已上线（logger.performance），待真机按回归清单采集定标
- [ ] UI 原生化改造（三阶段）——2026-08-14 真机评审结论「不像苹果商业软件」，评估与方案见 [product/ui_native_polish_plan.md](product/ui_native_polish_plan.md)；建议在面板回归采集完成后启动

### P1 — 差异化（原版没有或用户反复要求的）

- [ ] iCloud/CloudKit 同步（原版用户第一大痛点）——技术调研完成（[产品级报告](product/icloud_sync_research.md)：推荐 CloudKit 私有库 + CKSyncEngine，首域笔记；P0 立项验证需 Apple Developer 账号）
- [x] 截图管理：自动归集 + Vision 本地 OCR 全文搜索（做"管理"不做"拍摄"）——2026-08 完成（Vision 本地 OCR 引擎替代 Deepseek CLI 为默认）
- [x] Shortcuts / App Intents 集成（竞品标配）——2026-08 完成（显示/隐藏面板、复制最近剪贴板项，AppShortcutsProvider 暴露）
- [x] 剪贴板智能：高频片段统计（已有洞察引擎基础）、多项合并粘贴——合并粘贴 2026-08 完成（多选 + 按列表顺序合并 + 可配置分隔符）
- [x] 菜单栏迷你速记（Tot 式快速入口）——2026-08 完成（⌘⇧N 浮动小窗，⌘↩︎ 保存为笔记）

### P2 — 前沿布局

- [ ] Foundation Models 本地总结与语义搜索（隐私友好 AI，与 Paste 云路线错位竞争）
- [ ] Obsidian / Markdown 导出（延续现有 AI 聚类方向）
- [ ] Raycast 扩展联动
- [ ] 截图 → 笔记/文件面板一键流转

## 🔧 技术 Backlog（结构 P2，详见 refactor_findings.md 与 architecture/reassessment_2026-08.md）

- [x] 错误系统收敛：13 个错误枚举 → 1 套——2026-08 完成（4 个游离枚举并入 UnclutterError 协议，3 个死枚举删除，asUnclutterError 兜底保留底层错误）
- [x] 存储层并发统一（actor 化，消除 NSLock-in-async 的 Swift 6 隐患）——2026-08 完成（ShardedStorage/UnifiedNoteStorage actor 化，waitForInit 改 Task 化等待）
- [x] ViewModel 模板去重（Notes/Clipboard/Files 三段式重复）——2026-08 完成（SearchDebouncer 统一防抖）
- [ ] View/VM 状态双轨消除——Files/Screenshots 已完成（2026-08），仅剩 Clipboard 视图 @State searchText 经 onChange 手工同步进 VM
- [x] PreferencesView 拆分（849 行）——2026-08 完成（容器 + 5 个 tab 扩展 + TabOrderEditor 三文件）
- [ ] 命名统一（去 Modern 前缀，ModernClipboardView 等）
- [x] `@StateObject` 包单例反模式修正（应 `@ObservedObject`）——2026-08 完成（仅剩 InsightsView 一处）
- [x] 剪贴板列表 O(N) 全量重载改增量刷新——2026-08 完成（repository 变更明细 + VM 增量合并）

## 📋 低优先级测试 TODO（非核心功能，可延后）

### 1. 安全测试
**位置**：`Tests/UnclutterPlusTests/TestRunner/TestExecutionManager.swift`（`runSecurityIntegrationTests`）
- 需要实现权限验证测试、数据加密测试、安全边界测试

### 2. 内存测试
**位置**：`Tests/UnclutterPlusTests/TestRunner/TestExecutionManager.swift`（`runMemoryIntegrationTests`）
- 需要实现内存泄漏检测、缓存效率测试、长时间运行内存稳定性测试

### 3. 多组件集成测试
**位置**：`Tests/UnclutterPlusTests/TestRunner/TestExecutionManager.swift`（`runMultiComponentIntegrationTests`）
- 需要实现组件间交互测试、端到端工作流测试、并发操作测试

---

## ✅ 已完成（历史记录）

### 2026-08 iCloud/CloudKit 同步技术调研（R5）
- 一手来源调研（Apple 官方文档/Technote/WWDC/apple org 示例，每条事实附来源链接）：四方案对比 + 配额限制（TN3164）+ 冲突机制 + entitlement 打包 + 菜单栏应用适用性
- **结论**：推荐 CloudKit 私有库 + CKSyncEngine（原生 CKRecord），首个同步域选笔记；不推荐 NSPersistentCloudKitContainer（需引入整套 Core Data）；iCloud Drive 文件同步仅适合单设备备份场景
- 落地路线：P0 立项验证（签名链路）→ P1 笔记域 → P2 截图 → P3 剪贴板（opt-in）→ P4 推送增强
- 三份报告：`docs/product/icloud_sync_research.md`（总报告）+ `icloud_drive_sync_research.md` + `cloudkit-native-ckrecord-research.md`（分项）

### 2026-08 P1/P2 冲刺（todo list 依次执行）
- Shortcuts / App Intents：显示/隐藏面板、复制最近剪贴板项（AppShortcutsProvider 暴露；.app bundle 下可用）
- 菜单栏迷你速记（Tot 式快速入口）：⌘⇧N 浮动小窗，⌘↩︎ 保存为笔记
- View/VM 状态双轨消除：Files 视图 4 个手工同步 @State 直绑 VM；Screenshots 删除 4 个死状态
- VM 三段式模板去重：SearchDebouncer（Task 化防抖）替代三处重复 Combine 样板
- PreferencesView 拆分：880 行 → 容器 + 5 个 tab 扩展 + TabOrderEditor 三文件；删除死代码 getTabTitle/Icon/Color
- 全链路 161 测试全绿，冒烟启动 115ms 零错误

### 2026-08 P0 收尾与 Vision OCR
- 键盘优先操作流收尾：剪贴板方向键高亮/回车复制（多选模式下切换选择）、高亮项状态单源化到 VM、删除后选择一致性
- 性能达标：AppDelegate 启动耗时打点（实测 99ms）、10,000 项剪贴板基准（VM 加载 253ms、搜索过滤 0.1ms）、性能基线写入重评估文档
- Vision 本地 OCR 引擎：VNRecognizeTextRequest 零外部依赖、配置切换（vision/cli）、语言映射、真实图像识别测试

### 2026-08 二轮分析：真机冒烟测试 + 合并粘贴
- 真机冒烟测试：启动健康（存储/面板/菜单栏监控/快捷键/剪贴板监听全链路无错误）
- 修复冒烟测试暴露的两处缺陷（`d3e6415`）：指纹 bootstrap 启动竞态（重建为空）、旧格式分片索引（裸文件名）导致 read/delete 失效——回退目录扫描自愈
- 剪贴板多项合并粘贴：多选模式（单选切换/全选/清空）、按过滤列表顺序合并、可配置分隔符、纯文本写入、复制后自动隐藏；Esc 键隐藏面板（键盘流收尾）
- 新增 ClipboardMergeTests（合并顺序/占位符/选择状态/合并条件），144 测试全绿

### 2026-08 R4 错误系统收敛
- 4 个游离 LocalizedError 枚举（NotesError/ObsidianError/OCRError/AIServiceError）并入统一 `UnclutterError` 协议：分类、错误码、恢复建议、结构化 errorDescription
- 删除死枚举 `StorageOperationError`/`FileError`/`ClipboardError` 与未使用的 VM error 属性
- `ServiceError.unknown(underlying:)` 作为 asUnclutterError 兜底，保留底层错误信息（此前丢失为泛化文案）
- 新增 8 个收敛测试（协议遵循/分类错误码/包装透传/文件系统映射/处理器结构化输出），133 测试全绿

### 2026-08 R3 存储层并发统一
- `ShardedStorage` actor 化：移除 GCD 并发队列与 barrier，shardIndex 由 actor 隔离；`loadAll` 跨分片并行 IO 经不捕获 self 的子任务 + 静态编解码器保留；索引防抖保存改 Task 化
- `UnifiedNoteStorage` actor 化：NSLock 全移除，索引缓存 actor 隔离
- `ClipboardStorageAdapter` 初始化改 Task 化等待（消除 100ms 忙等轮询）
- 剪贴板增量刷新：`ClipboardRepository` 发布变更明细（added/updated/removed/cleared），`ModernClipboardViewModel` 按事件增量合并，替代 objectWillChange 全量重载
- 新增 `ShardedStorageConcurrencyTests`（并发读写删/跨实例索引重建）+ `ClipboardIncrementalRefreshTests`（冷缓存场景验证零重读），125 测试全绿

### 2026-08 剪贴板基线补全与重构收口
- 三笔逻辑提交收口进行中的重构（面板现代化 + Core/UI 依赖倒置、笔记服务纯数据化、功能流测试套件）
- 剪贴板基线补全：pin/取消 pin/清除非 pin 接线、纯文本粘贴确认、密码管理器 ConcealedType + 1Password 标记忽略、瞬态内容忽略、应用排除规则（Bundle ID 配置 + 偏好设置 UI）
- 修复剪贴板指纹 bootstrap 有损 bug（preview 截断/文件名反推指纹 → 重启后长文本与文件重复入库）；`fingerprint` 提升为 ClipboardItem 一等持久化字段，遗留数据启动时按完整内容迁移
- 剪贴板复制后自动隐藏面板（对齐截图面板行为）
- `@StateObject` 包单例反模式修正（InsightsView）
- 文件暂存架重建（`TempFileManager` + `TempFileItem`）：拖入文件暂存（目录自动路由到收藏文件夹）、拖出到任意应用、Quick Look 预览（`QuickLookController`）、Finder 揭示、访问统计、缺失文件容忍、JSON 持久化 + 8 个单元测试
- 新增架构与需求重评估：[architecture/reassessment_2026-08.md](architecture/reassessment_2026-08.md)

### 2026-07 架构清理与重构
- 两波死代码清理共约 -7,500 行（`0ec17bb`、`e0c351f`）：旧 AppDelegate、NotesManager、UnifiedStorageManager、IndexDatabase、NoteRepository、CachedStorage、PerformanceOptimizer 等 20 个文件
- 修复 zh-Hans 本地化文件解析失败（未转义引号导致整表失效）
- 修复 WindowManager 死 cast、菜单栏图标设置双键失步
- 市场调研与功能重排（本文档）

### 2025-12-24 第一性原理 UI/UX 优化（P1-P3）
- 大纲滚动、滚动方向配置、动态菜单栏区域、自动隐藏倒计时、设置界面信息架构、点击即时反馈、TabButton 视觉层次等 8 项（详见 git 历史 `e924787`）

---

## 📝 参考文档

- [产品与市场调研](product/market_research.md)
- [代码结构调研与重构建议](architecture/refactor_findings.md)
- [第一性原理 UI/UX 分析报告](first_principles_ui_analysis.md)
