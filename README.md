# UnclutterPlus

[English](#english) | [中文](#中文)

---

## English

A modern macOS productivity app inspired by Unclutter, featuring enhanced Markdown note-taking capabilities.

### Features

#### 🗂️ File Management
- **Temporary File Storage**: Drag and drop files for quick temporary storage
- **Smart File Icons**: Automatic file type recognition with appropriate icons
- **Quick Access**: Right-click context menus for opening files and showing in Finder
- **File Size Display**: Visual file size information

#### 📋 Clipboard History
- **Multi-format Support**: Text, images, and file clipboard history
- **Smart Search**: Search through clipboard history
- **Persistent Storage**: Text clipboard items persist between app launches
- **Quick Copy**: One-click to copy items back to clipboard

#### 📝 Enhanced Notes with Markdown
- **Full Markdown Support**: Complete Markdown syntax support with live preview
- **Syntax Highlighting**: Code blocks with syntax highlighting
- **Real-time Preview**: Split-view editor with instant Markdown rendering
- **Markdown Toolbar**: Quick access buttons for common Markdown formatting
- **Auto-save**: Notes automatically save as you type
- **Smart Preview**: Generates text previews from Markdown content

#### 🖥️ System Integration
- **Smart Gesture Trigger**: Scroll wheel or two-finger swipe down at screen top edge to activate, prevents accidental triggers
- **Multi-Screen Support**: Intelligent screen layout detection with adaptive window positioning
- **Menu Bar Integration**: Clean menu bar icon with quick access
- **Enhanced Animations**: Optimized slide-in/out animations with transparency effects
- **Window Management**: Configurable window priority and focus handling

### Installation

#### Requirements
- macOS 12.0 or later
- Xcode 14.0 or later (for building from source)

#### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/voidzyh/UnclutterPlus.git
cd UnclutterPlus
```

2. Build with Swift Package Manager:
```bash
swift build -c release
```

3. Or open in Xcode and build:
```bash
open Package.swift
```

### Usage

1. **Activation**: Move your mouse to the top edge of the screen, then scroll wheel or swipe down with two fingers
2. **Navigation**: Use the three tabs (Files, Clipboard, Notes)
3. **Files**: Drag and drop files for temporary storage
4. **Clipboard**: Automatic clipboard history with search
5. **Notes**: Create and edit Markdown notes with live preview

---

## 中文

一款现代化的 macOS 生产力应用，灵感来源于 Unclutter，具有增强的 Markdown 笔记功能。

### 功能特性

#### 🗂️ 文件管理
- **临时文件存储**：拖拽文件进行快速临时存储
- **智能文件图标**：自动识别文件类型并显示相应图标
- **快速访问**：右键菜单支持打开文件和在访达中显示
- **文件大小显示**：可视化文件大小信息

#### 📋 剪贴板历史
- **多格式支持**：支持文本、图片和文件的剪贴板历史
- **智能搜索**：在剪贴板历史中搜索内容
- **持久存储**：文本剪贴板项目在应用重启后保持
- **快速复制**：一键将历史项目复制回剪贴板

#### 📝 增强的 Markdown 笔记
- **完整 Markdown 支持**：支持完整的 Markdown 语法和实时预览
- **语法高亮**：代码块语法高亮显示
- **实时预览**：分屏编辑器，即时 Markdown 渲染
- **Markdown 工具栏**：常用 Markdown 格式的快速访问按钮
- **自动保存**：输入时自动保存笔记
- **智能预览**：从 Markdown 内容生成文本预览

#### 🖥️ 系统集成
- **智能手势触发**：屏幕顶部边缘滚轮或双指下滑激活，避免误触发
- **多屏幕支持**：智能检测屏幕布局，自适应窗口位置
- **菜单栏集成**：简洁的菜单栏图标，快速访问
- **增强动画**：优化的滑入滑出动画，支持透明度变化
- **窗口管理**：可配置的窗口优先级和焦点处理

### 安装说明

#### 系统要求
- macOS 12.0 或更高版本
- Xcode 14.0 或更高版本（从源码构建时需要）

#### 从源码构建

1. 克隆仓库：
```bash
git clone https://github.com/voidzyh/UnclutterPlus.git
cd UnclutterPlus
```

2. 使用 Swift Package Manager 构建：
```bash
swift build -c release
```

3. 或在 Xcode 中打开并构建：
```bash
open Package.swift
```

### 使用方法

1. **激活应用**：将鼠标移动到屏幕顶部边缘，然后滚动滚轮或双指向下滑动
2. **标签导航**：使用三个标签页（文件、剪贴板、笔记）
3. **文件功能**：拖拽文件进行临时存储
4. **剪贴板功能**：自动剪贴板历史记录，支持搜索
5. **笔记功能**：创建和编辑 Markdown 笔记，支持实时预览

### 技术架构

应用基于以下技术构建：
- **SwiftUI**：现代声明式 UI 框架
- **Swift Markdown**：苹果官方 Markdown 解析库
- **MarkdownUI**：高级 Markdown 渲染和语法高亮
- **AppKit 集成**：原生 macOS 功能，如菜单栏和窗口管理

### 贡献

欢迎贡献代码！请随时提交问题、功能请求或拉取请求。

### 许可证

本项目基于 MIT 许可证 - 详见 LICENSE 文件。

---

**注意**：这是一个个人生产力工具。请确保了解本地存储的数据内容。