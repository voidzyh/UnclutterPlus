# UnclutterPlus 产品与市场调研

调研日期：2026-07-17 · 调研方式：公开网络资料 + GitHub API 实测

## 一、原版 Unclutter（对标对象）

**核心功能**：三合一隐藏面板——Files（文件暂存/drop zone）、Notes（速记便签）、Clipboard（剪贴板历史）。鼠标移到屏幕顶部+滚轮下滑手势唤出，面板可拖出分离置顶，支持多显示器、全屏下唤出，文件/笔记经 Dropbox 同步（[unclutterapp.com](https://unclutterapp.com/)）。

**定价与评分**：
- $19.99 一次性买断（官网/MAS），或 Setapp 订阅内（Setapp $9.99/月起）——[MacSources 评测 2025-03](https://macsources.com/unclutter-for-mac-review/)
- 官网自称 App Store 平均评分 4.6，曾获 Apple "Apps and Games We Love"(2018) 与 "Spark Your Productivity"(2020-2023) 推荐——[官网](https://unclutterapp.com/)

**最近更新动态**：最新版 2.2.16（2026-03-10，[MacUpdate](https://unclutter.macupdate.com/)）。近一年更新（2.2.9–2.2.16）几乎全是修复：剪贴板面板崩溃、内存泄漏、iCloud Drive 目录冻结、macOS 26 Tahoe 兼容、刘海适配——[官方 changelog](https://unclutterapp.com/changelog)。**判断：产品已进入维护期，无重大新功能投入。**

**用户抱怨的痛点**（机会点直接来源）：
- 只支持 Dropbox，**用户反复请求 iCloud 同步**——[用户评论汇总](http://unclutter.softwar.io/app-reviews)
- 面板（visor）在其他应用输入时无法保持打开——[Slant 对比](https://www.slant.co/versus/1703/15470/~unclutter_vs_paste)
- 剪贴板功能弱于专用工具：用户点名要"多选历史项合并粘贴"——同 softwar.io 评论
- 无截图管理、无标签/自动整理、不做文件版本管理
- 闭源、无 AI/OCR、无 Shortcuts 集成迹象

## 二、竞品格局

### 文件暂存（shelf）类
| 产品 | 价格 | 差异化 | 来源 |
|---|---|---|---|
| Yoink | $7.99 一次性（MAS），Setapp 内 | 屏幕边缘滑出 shelf，拖拽体验最顺滑，含剪贴板历史 widget，有 iOS 版 | [appleworld.today 2026-06](https://appleworld.today/2026/06/yoink-is-a-handy-shelf-app-for-macos-that-makes-dragging-and-dropping-less-cumbersome/) |
| Dropover | 免费 + Pro IAP，Setapp 内 | "摇鼠标"手势唤出多 shelf、云链接分享、Shortcuts 集成、文件夹观察；[Daring Fireball 2026-05 仍在推荐](https://daringfireball.net/linked/2026/05/15/dropover) | [dropoverapp.com](https://dropoverapp.com/) |
| Dropshelf | 目前免费 | 边缘滑出多 shelf，但基本停更 | [pilotmoon.com](https://pilotmoon.com/dropshelf/) |
| FilePane | $4.99（MAS） | 拖拽触发快捷动作面板（压缩/转换/分享/改名），规则驱动、明确不做 AI | [gadgethacks](https://macos.gadgethacks.com/how-to/make-drag-drop-way-more-useful-your-mac-0162720/) |

结论：纯 shelf 赛道 Yoink/Dropover 双寡头，体验打磨极成熟，**不值得正面硬卷**。

### 拖放动作/自动化
- **Dropzone 4**：核心免费；Pro 一次性 $35 或订阅（$1.99/月）——[Aptonic 官方博客](https://aptonic.com/blog/dropzone-4-non-mac-app-store-version-released)。定位"自动化中枢"，与暂存相邻而非同一赛道。

### 剪贴板管理
| 产品 | 价格 | 要点 | 来源 |
|---|---|---|---|
| Paste | $29.99/年，**无买断** | iCloud 跨端同步、Pinboard、团队协作；Paste 6（2025-09 大改版）；2025-11 集成 Apple Intelligence（图片 OCR 搜索） | [TextExpander 2026 横评](https://textexpander.com/blog/best-clipboard-managers) |
| Maccy | 开源免费（MAS 付费为捐赠） | 轻量、键盘优先、本地隐私、自动忽略密码管理器内容；无 iOS/无 AI | [txuriberri 2026-06](https://txuriberri.com/is-maccy-open-source/) |
| CopyClip 2 | $14.99 一次性 | 菜单栏轻量、pin/搜索/私有模式 | [cleanclip 横评](https://cleanclip.cc/articles/15-best-mac-clipboard-manager-apps-comparison-and-features) |
| CleanClip / PastePal | $12.99 一次性 / 免费+$14.99 | 新晋中价位选手 | [talkbitz 2026-07](https://talkbitz.com/best-clipboard-managers/) |

**重大变量：macOS 26 Tahoe（2025-09-15 发布）已在 Spotlight 内置剪贴板历史**（⌘Space→⌘4；默认关闭；保留 8 小时，26.1 延长至最多 7 天；无 pin、无同步、图片支持不稳定）——[Mac Observer](https://www.macobserver.com/tips/how-to/use-clipboard-history-on-macos-tahoe/)。"记住最近几条"已被系统免费解决，第三方价值必须上移到**持久归档、组织、搜索、同步、自动化**。

### 截图
- **CleanShot X**：$29 一次性（含 1 年更新，续期 $19/年）；Cloud Pro $8/用户/月。滚动截图、录屏/GIF、标注、OCR、云链接，4.8.2 起加 AI 辅助——[CursorClip 对比 2026-06](https://cursorclip.com/blog/cleanshot-x-alternatives-mac/)
- **Shottr**：$12 一次性，OCR 强、轻量
- **TextSniper**：$9.99 专用 OCR

结论：截图"拍摄+标注"赛道 CleanShot X 统治力强，但**"截图的归集与管理"（自动整理、OCR 可搜索）是相对空白**，原版 Unclutter 也没有。

### 快速笔记
| 产品 | 价格 | 要点 |
|---|---|---|
| SideNotes | $20 一次性 | 屏幕侧边滑入、Markdown、任务、iCloud、Shortcuts、AppleScript，有 iOS 版 |
| Tot | Mac 免费（IAP）；iOS $19.99 | 7 个彩色圆点草稿纸，极简；Tot 2.0（2025-08）加 checkbox/智能 bullets |
| Tyke | 免费 | 2.8MB 极简菜单栏草稿纸，多年停滞 |
| Antinote | $5 买断 | 草稿纸+计算/换算 |

## 三、市场趋势（2024–2026）

1. **系统层蚕食基础功能**：Tahoe 内置剪贴板历史 + Spotlight Quick Actions，正在吸收 Alfred/Raycast 的基础能力。
2. **AI 成为头部标配**：Paste 集成 Apple Intelligence（2025-11）、CleanShot X AI 辅助（4.8.2）；开源领域几乎空白。
3. **OCR 普及化**：Shottr、CleanShot X、TextSniper、Paste 都把 OCR 当核心卖点；macOS Vision 框架让本地 OCR 零成本可得。
4. **订阅疲劳明显**：Paste $29.99/年是最常见吐槽点；买断制/免费工具（Maccy、Shottr、SideNotes）口碑更好。**开源+免费本身就是差异化武器。**
5. **Shortcuts/自动化集成成标配**：Yoink、Dropover、SideNotes、Tot 均支持。
6. **用户最看重的点**：唤出速度与键盘流、隐藏式设计不打扰、本地隐私（剪贴板含敏感数据，开源可审计是加分项）、iCloud 同步（苹果生态刚需）、买断定价。

## 四、开源同类项目（GitHub API 实测，2026-07-17）

| 项目 | Stars | 活跃度 | 说明 |
|---|---|---|---|
| p0deje/Maccy | 20,748 | 极活跃 | 开源剪贴板成功案例：免费+MAS 捐赠模式 |
| hluk/CopyQ | 12,010 | 极活跃 | 跨平台，功能重 |
| Clipy/Clipy | 8,777 | 仍在维护 | 更新慢 |
| 开源文件 shelf（Dropi、shelfish、Perch 等 8 个仓库） | 全部 ≤3 | — | **无主导者** |
| Unclutter 式三合一开源实现 | — | — | **未发现知名项目，UnclutterPlus 几乎是该形态唯一开源实现** |

启示：Maccy 证明了"单一功能做到极致+开源"可获 2 万 star；文件 shelf 开源项目虽多但无一做起来——说明**单点 shelf 开源没有吸引力，而"三合一整合+开源"这个生态位是空的**。

## 五、UnclutterPlus 差异化机会与功能优先级

### 值得做的机会点
1. **"开源版 Unclutter"定位本身**：该形态无开源竞品，原版 $19.99 闭源且已进维护期，这是最强叙事。
2. **iCloud 同步**：原版用户第一大抱怨点，用 CloudKit 免费做出来即杀手级差异。
3. **截图管理（不是截图工具）**：自动归集截图目录 + 本地 OCR 全文索引 + 快速拖拽复用。原版没有，CleanShot X 不管"事后管理"。
4. **AI/本地智能**：剪贴板语义搜索、截图 OCR 索引、笔记总结——macOS 26 的 Foundation Models 框架可本地零成本调用，契合隐私叙事；开源领域空白。
5. **Tahoe 后的生存空间**：系统剪贴板无 pin、无组织、7 天即焚——做"持久化+组织+搜索"正好补位。
6. **剪贴板合并粘贴**：原版用户点名要、无人做好的小功能。

### 不值得卷的
- 纯文件 shelf 单点工具（Yoink/Dropover 体验壁垒高，开源同类全灭）
- 截图拍摄/标注/录屏（CleanShot X + 系统截图夹击）
- 全功能笔记（Tot/SideNotes/Bear 红海）
- 跨平台（Maccy 证明 Mac 单平台也能成）

### 建议优先级

**P0（立足基本盘，对齐原版体验并修其短板）**
- 三合一面板稳定性与性能（原版 changelog 全是崩溃/内存修复，把"稳定轻快"做成对比卖点）
- 剪贴板：持久历史、pin、纯文本粘贴、应用排除规则、密码管理器内容自动忽略（对齐 Maccy 基线）
- 文件暂存：拖入拖出、Quick Look 预览、Finder 揭示
- 笔记：Markdown 速记 + 全文搜索
- 全局快捷键 + 键盘优先操作流
- 中文本地化（原版有中文，中文圈传播度高 = 天然受众）

**P1（建立差异化）**
- iCloud/CloudKit 同步（直击原版最大痛点）
- 截图管理面板：自动归集 + Vision 本地 OCR 搜索
- Shortcuts / App Intents 集成（竞品标配）
- 剪贴板智能：高频片段统计、多项合并粘贴
- 菜单栏迷你笔记（Tot 式快速入口）

**P2（前沿布局）**
- Apple Intelligence / Foundation Models 本地总结与语义搜索（"隐私友好的 AI"，与 Paste 的云路线错位竞争）
- Obsidian / Markdown 导出（延续现有 AI 聚类总结方向的产物落地）
- Raycast 扩展联动
- 截图 → 笔记/文件面板的一键流转动线

### 数据可靠性备注
- Unclutter 4.6 评分为官网自述，未独立核实。
- Yoink 价格有 $7.99（appleworld 2026-06）与 $8.99（TheSweetBits 2025）两个口径，或因地区/调价而异。
- Dropover 确切 IAP 金额未拿到一手来源，仅确认"免费 + Pro 内购 + Setapp 内"。
