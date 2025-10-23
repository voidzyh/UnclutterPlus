# Magic MCP 使用指南 - UnclutterPlus UI 优化

## 📋 概述

Magic MCP 是一个强大的 UI 组件生成工具,可以从 21st.dev 库中获取现代化的设计模式,帮助快速创建和优化 SwiftUI 组件。

---

## 🔧 配置状态

### 当前状态
```bash
# 您正在执行的配置命令:
claude mcp add magic --scope user \
  --env API_KEY="0682e2a69415ecdfc4d9677094146b5925efd593b0c881dda185434e89b9d2a4" \
  -- npx -y @21st-dev/magic@latest
```

### 验证配置
配置完成后,您可以通过以下方式验证:

```bash
# 检查 MCP 服务器状态
claude mcp list

# 应该看到 magic 服务器已启用
```

---

## 🎨 UnclutterPlus UI 优化计划

### 优先级 1: PreferencesView 现代化

**当前问题**:
- 界面较为传统
- 缺少视觉反馈
- 没有响应式动画

**Magic MCP 优化方案**:
```swift
// 使用 Magic MCP 创建现代化设置面板
/ui 创建一个设置面板组件,包含:
- 分组的设置选项卡
- 流畅的切换动画
- 现代化的开关组件
- 可视化的滑块控件
- 拖拽排序的标签页配置
```

**预期改进**:
- ✅ 更直观的视觉层次
- ✅ 流畅的交互动画
- ✅ 更好的用户体验
- ✅ 符合 macOS 设计规范

### 优先级 2: ClipboardView 增强

**优化目标**:
```swift
/ui 创建剪贴板项目卡片组件:
- 卡片式布局
- 悬停效果
- 快速操作按钮
- 类型标签
- 使用计数徽章
```

**设计要求**:
- 支持文本、图片、文件三种类型
- 鼠标悬停显示操作按钮
- 视觉区分已固定项目
- 平滑的展开/收起动画

### 优先级 3: FilesView 可视化

**优化目标**:
```swift
/ui 创建文件网格卡片组件:
- 文件类型图标
- 文件大小显示
- 拖拽上传区域
- 网格/列表切换
- 收藏标记
```

**交互优化**:
- 拖拽上传视觉反馈
- 文件预览悬浮层
- 批量操作模式
- 上下文菜单

### 优先级 4: NotesView 编辑器

**优化目标**:
```swift
/ui 创建 Markdown 编辑器组件:
- 工具栏按钮
- 实时预览面板
- 语法高亮
- 标签管理
- 侧边栏导航
```

---

## 🚀 具体使用示例

### 示例 1: 创建设置卡片组件

**命令**:
```
/ui 创建一个设置卡片,包含标题、描述和切换开关
```

**Magic MCP 会返回**:
```swift
struct SettingsCard: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }
}
```

### 示例 2: 优化现有组件

**命令**:
```
/21 refine PreferencesView 使其更现代化,添加分组和动画
```

**Magic MCP 会**:
1. 分析现有 PreferencesView 代码
2. 提供优化建议
3. 生成改进后的代码
4. 保持功能一致性

### 示例 3: 创建自定义控件

**命令**:
```
/ui 创建一个延迟时间选择器,使用滑块,显示实时预览
```

**应用场景**:
- 替换 PreferencesView 中的延迟设置
- 添加视觉反馈
- 提升用户体验

---

## 📖 Magic MCP 命令参考

### 基础命令

| 命令 | 用途 | 示例 |
|------|------|------|
| `/ui` | 创建新组件 | `/ui 创建登录表单` |
| `/21` | 从 21st.dev 搜索 | `/21 卡片布局` |
| `/21 refine` | 优化现有组件 | `/21 refine MyView` |

### 高级用法

```bash
# 指定框架和样式
/ui 创建一个 SwiftUI 卡片组件,使用 SF Symbols 图标

# 多个组件组合
/ui 创建包含标题、副标题和操作按钮的列表项

# 响应式设计
/ui 创建自适应布局的网格组件,支持 compact 和 regular 尺寸
```

---

## 🎯 UnclutterPlus 专用模板

### 模板 1: 功能卡片
```swift
// 用于 PreferencesView 的设置项
/ui 创建一个设置功能卡片:
- 左侧图标 (SF Symbol)
- 标题和描述文本
- 右侧切换开关
- 背景使用 .regularMaterial
- 圆角 12pt
- 悬停效果
```

### 模板 2: 文件项
```swift
// 用于 FilesView 的文件显示
/ui 创建一个文件项组件:
- 文件类型图标 (大图标)
- 文件名 (可编辑)
- 文件大小和日期
- 右键菜单支持
- 拖拽手势
- 选中状态高亮
```

### 模板 3: 剪贴板卡片
```swift
// 用于 ClipboardView 的历史项
/ui 创建一个剪贴板历史卡片:
- 内容预览区域
- 来源应用图标
- 时间戳显示
- 使用次数徽章
- 悬停显示操作按钮 (复制、删除、固定)
- 支持固定/未固定视觉区分
```

---

## 🔄 集成流程

### 步骤 1: 生成组件
```bash
# 使用 Magic MCP 生成组件代码
/ui [您的需求描述]
```

### 步骤 2: 创建文件
```bash
# 在适当位置创建新文件
Sources/UnclutterPlus/Components/[ComponentName].swift
```

### 步骤 3: 集成到项目
```swift
// 在现有 View 中使用新组件
import SwiftUI

struct PreferencesView: View {
    var body: some View {
        VStack {
            // 使用 Magic MCP 生成的组件
            SettingsCard(
                title: "Files",
                description: "Enable file management",
                isEnabled: $config.isFilesEnabled
            )
        }
    }
}
```

### 步骤 4: 测试和调整
```bash
# 运行项目查看效果
swift run

# 根据需要微调
/21 refine SettingsCard 添加阴影效果
```

---

## 💡 最佳实践

### 1. 渐进式优化
```
❌ 不要: 一次性重写整个 View
✅ 推荐: 逐个组件优化,保持功能稳定
```

### 2. 保持一致性
```swift
// 定义统一的设计令牌
struct DesignTokens {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 8
}

// 在所有 Magic MCP 生成的组件中使用
```

### 3. 可复用组件
```swift
// 创建通用组件库
Sources/UnclutterPlus/Components/
├── Cards/
│   ├── SettingsCard.swift
│   ├── FileCard.swift
│   └── ClipboardCard.swift
├── Controls/
│   ├── CustomSlider.swift
│   └── CustomToggle.swift
└── Layouts/
    ├── GridLayout.swift
    └── ListLayout.swift
```

### 4. 保留 ViewModel
```swift
// Magic MCP 生成的组件应该使用现有的 ViewModel
struct FilesCard: View {
    @ObservedObject var viewModel: FilesViewModel
    let file: TempFile

    var body: some View {
        // Magic MCP 生成的 UI
        // 但数据和逻辑来自 ViewModel
    }
}
```

---

## 🎨 设计指南

### macOS 风格规范

**颜色**:
- 背景: `.regularMaterial` 或 `.thickMaterial`
- 文本: `.primary`, `.secondary`
- 强调: `.accentColor`

**圆角**:
- 卡片: 12pt
- 按钮: 8pt
- 输入框: 6pt

**间距**:
- 组间距: 16pt
- 元素间距: 8pt
- 内边距: 12-16pt

**动画**:
```swift
.animation(.easeInOut(duration: 0.2), value: someState)
```

---

## 📚 参考资源

### 21st.dev 组件库
- [设置面板](https://21st.dev/components/settings)
- [卡片布局](https://21st.dev/components/cards)
- [表单控件](https://21st.dev/components/forms)

### SwiftUI 最佳实践
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SwiftUI by Example](https://www.hackingwithswift.com/quick-start/swiftui)

---

## 🚦 下一步行动

配置完成 Magic MCP 后,建议按以下顺序优化:

### Week 1: PreferencesView
1. 创建设置卡片组件
2. 优化标签页选择器
3. 美化滑块控件
4. 添加视觉反馈

### Week 2: FilesView & ClipboardView
1. 设计文件卡片
2. 实现拖拽区域
3. 优化剪贴板列表
4. 添加快速操作

### Week 3: NotesView
1. 增强编辑器工具栏
2. 改进预览面板
3. 优化标签管理
4. 完善侧边栏

---

## ✅ 验收标准

优化完成后的标准:
- ✅ 符合 macOS Human Interface Guidelines
- ✅ 所有动画流畅 (60fps)
- ✅ 保持原有功能完整性
- ✅ 代码可维护性良好
- ✅ 用户体验显著提升

---

**文档版本**: v1.0
**创建时间**: 2025-10-23
**状态**: 等待 Magic MCP 配置完成

**注意**: 本指南将在 Magic MCP 配置完成后立即可用。请在配置完成后告知我,我将协助您开始 UI 优化工作。
