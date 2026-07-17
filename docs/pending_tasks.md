# UnclutterPlus 待办事项

## 更新时间
2026-07-17（重构后重排，依据 [市场调研](product/market_research.md) 与 [代码结构调研](architecture/refactor_findings.md)）

---

## 🎯 功能 Backlog

### P0 — 立足基本盘（对齐原版 Unclutter 体验并修其短板）

- [ ] 浮动面板全链路稳定（唤出/隐藏/自动隐藏/多屏定位）——重构后首要验收项
- [ ] 剪贴板基线：pin、纯文本粘贴、应用排除规则、密码管理器内容自动忽略（对齐 Maccy）
- [ ] 文件暂存基线：拖入拖出、Quick Look 预览、Finder 揭示
- [ ] 全局快捷键 + 键盘优先操作流（`GlobalHotkey` 已存在，需在面板收敛后完成接线）
- [ ] 面板唤出速度与内存占用达标（把"稳定轻快"做成对原版的对比卖点）

### P1 — 差异化（原版没有或用户反复要求的）

- [ ] iCloud/CloudKit 同步（原版用户第一大痛点）
- [ ] 截图管理：自动归集 + Vision 本地 OCR 全文搜索（做"管理"不做"拍摄"）
- [ ] Shortcuts / App Intents 集成（竞品标配）
- [ ] 剪贴板智能：高频片段统计（已有洞察引擎基础）、多项合并粘贴
- [ ] 菜单栏迷你速记（Tot 式快速入口）

### P2 — 前沿布局

- [ ] Foundation Models 本地总结与语义搜索（隐私友好 AI，与 Paste 云路线错位竞争）
- [ ] Obsidian / Markdown 导出（延续现有 AI 聚类方向）
- [ ] Raycast 扩展联动
- [ ] 截图 → 笔记/文件面板一键流转

## 🔧 技术 Backlog（结构 P2，详见 refactor_findings.md）

- [ ] 错误系统收敛：13 个错误枚举 → 1 套
- [ ] 存储层并发统一（actor 化，消除 NSLock-in-async 的 Swift 6 隐患）
- [ ] ViewModel 模板去重（Notes/Clipboard/Files 三段式重复）
- [ ] View/VM 状态双轨消除（Files/Screenshots/Clipboard 视图）
- [ ] PreferencesView 拆分（849 行）与命名统一（去 Modern 前缀）
- [ ] `@StateObject` 包单例反模式修正（应 `@ObservedObject`）
- [ ] 剪贴板列表 O(N) 全量重载改增量刷新

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
