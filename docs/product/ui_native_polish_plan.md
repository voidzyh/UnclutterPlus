# UI 原生化改造计划（2026-08）

## 背景与评估结论

- 触发：2026-08-14 真机评审反馈「UI 设计和功能排版不像苹果商业软件」。
- 方法：真机截图 + 视觉模型批评 + 设计系统代码走查，问题全部可定位到代码。
- 根因：观感偏离不是实现走样，而是 [Redesign_Spec.md](../Redesign_Spec.md)（"Crystal & Canvas" v2.0）本身的设计选择——微交互缩放、彩色图标、圆体字、纯图标轨是 iOS/web 风格，不是 macOS 原生惯例。本计划实施后部分取代该规范（见文末「规范处置」）。

## 问题清单（附代码定位）

| # | 问题 | 定位 |
|---|------|------|
| 1 | 每标签一种鲜艳彩色 + 悬停彩色辉光（视觉模型第一眼点名「彩色圆底图标」） | `AppTab.swift:26-31`、`ModernMainContentView.swift:194` |
| 2 | 悬停缩放（卡片 1.02 / 图标 1.1）、选中 bounce 弹跳——macOS 原生无悬停缩放，玩具感最大来源 | `ModernDesignSystem.swift:161-198`、`ModernMainContentView.swift:193-195` |
| 3 | SF Rounded 圆体标题字——macOS 商业软件不用圆体 | `ModernDesignSystem.swift:204` |
| 4 | 蓝紫渐变 App 标识（iOS 营销风）；毛玻璃侧栏与不透明画布拼接出「补丁感」 | `ModernMainContentView.swift:47-52`、`:22,100` |
| 5 | 纯图标侧栏无文字标签（68px 图标轨靠 tooltip）——Mac 惯例是带文字侧栏或顶部标签条 | `ModernMainContentView.swift:17` |
| 6 | 多选空心圆自定义指示「像廉价 web UI」；类型图标蓝/橙/绿彩色编码过载 | `ModernClipboardView.swift:262`、`:318-322` |
| 7 | 搜索占位符硬编码英文 `Search history...`——中文系统观感硬伤 | `ModernClipboardView.swift:46` |

## 改造方向

**原生克制风**，对标 Raycast / Paste / 系统备忘录：单色 SF Symbols + 单一系统强调色、默认 SF 字体、整窗统一材质、动效克制（无 hover 缩放、无辉光、无弹跳）。

## 分阶段实施

### 阶段一：无争议硬伤（低风险，先行，约 1–2 小时）

- [ ] 占位符与文案本地化：全 UI 扫一遍硬编码字符串（`Search history...` 等）
- [ ] 删悬停缩放/辉光/弹跳：`HoverScaleModifier`、`CardStyleModifier` 的 scaleEffect、图标 hover 放大与 shadow 辉光、`symbolEffect(.bounce)`
- [ ] 删 `roundedTitle`，回系统默认字体

### 阶段二：视觉统一（约半天）

- [ ] 图标单色化：常态 `.secondary` / 选中 `.accentColor` 两态；删 `AppTab.color` 彩色映射
- [ ] 整窗统一材质（`.regularMaterial`；侧栏与内容区同材质，靠明度区分层次）
- [ ] 多选指示原生化：选中行 `accentSoft` 底色 + 行尾 checkmark，删空心圆组件
- [ ] App 标识去渐变（单色符号即可）
- [ ] 类型图标去彩色（统一 secondary，靠符号形状区分类型）

### 阶段三：信息架构与密度（约半天，含对照调整）

- [ ] 侧栏加文字标签（图标 + 小号文字，Raycast 式）；或评估改顶部标签条（Paste 式），二选一以并排截图定夺
- [ ] 列表行密度：行内图标 16pt 级、行高压实、间距统一走 Spacing 令牌
- [ ] 剪贴板/文件/笔记/截图四个 tab 的行排版对齐同一规格

## 验收标准

- 与 Raycast/Paste/系统备忘录并排截图对照，无「一眼非原生」的元素
- 161 测试全绿（改动限视图层，不触 VM/Service）
- 键盘流回归不受影响（⌘⇧U / 方向键高亮 / 回车 / Esc）
- 深色与浅色两种外观分别检查

## 时序与依赖

- **建议在面板真机回归数据采集完成后启动**（回归进行中，见 [maintenance/panel_regression_2026-08.md](../maintenance/panel_regression_2026-08.md)）：性能基线以当前 UI 采集，若先改 UI 则唤出耗时/内存需重测。
- 与 iCloud 同步立项无依赖，可并行推进。

## 规范处置

本计划落地后，Redesign_Spec.md 以下条款作废，由本计划「原生克制」原则取代：

- §1「Micro-Interactions: every click/hover has physical response (scale…)」
- §3「System Rounded for headers」
- §4「Icons glow/scale on hover」「icon-only 68px sidebar」
- §5「Cards Hover: scale(1.02)」「Primary 按钮渐变背景」

语义色令牌、间距刻度、材质分层思路继续有效。
