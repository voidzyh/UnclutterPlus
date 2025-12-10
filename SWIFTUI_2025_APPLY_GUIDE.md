# SwiftUI 2025 新特性应用指南 - UnclutterPlus

## 📱 SwiftUI 2025 (macOS 26) 最新特性总览

### 🎨 核心新特性

| 特性 | 版本 | 优先级 | 适用场景 |
|------|------|--------|----------|
| **Liquid Glass 设计语言** | macOS 26 | ⭐⭐⭐⭐⭐ | 整体UI现代化 |
| **原生 WebView** | macOS 26 | ⭐⭐⭐⭐ | 笔记链接预览 |
| **工具栏玻璃化** | macOS 26 | ⭐⭐⭐⭐ | 主窗口工具栏 |
| **TabView 增强** | macOS 26 | ⭐⭐⭐ | 标签页切换 |
| **TextEditor 富文本** | macOS 26 | ⭐⭐⭐⭐⭐ | Markdown 编辑 |
| **性能提升** | macOS 26 | ⭐⭐⭐⭐⭐ | 整体性能 |

---

## 🚀 UnclutterPlus 应用建议

### 1. Liquid Glass 设计语言 (⭐⭐⭐⭐⭐)

#### 1.1 整体界面现代化
```swift
// 应用 Liquid Glass 到主窗口
struct MainContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 标签页区域 - 使用 Liquid Glass
            GlassEffectContainer(spacing: 8) {
                TabView {
                    FilesView()
                        .glassEffectID("files", in: namespace)
                    ClipboardView()
                        .glassEffectID("clipboard", in: namespace)
                    NotesView()
                        .glassEffectID("notes", in: namespace)
                }
                .tabViewStyle(.glass)
            }
        }
        .background(
            // 全局 Liquid Glass 背景
            LiquidGlassBackground()
                .ignoresSafeArea()
        )
    }

    @Namespace var namespace
}
```

#### 1.2 按钮和控件升级
```swift
// 主操作按钮 - Liquid Glass 风格
struct ActionButtons: View {
    var body: some View {
        HStack(spacing: 12) {
            Button("Add") {
                // 添加操作
            }
            .buttonStyle(.glass)

            Button("Settings") {
                showSettings()
            }
            .buttonStyle(.glass)

            Button("Search") {
                // 搜索功能
            }
            .buttonStyle(.glass)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .glassEffect()  // 容器玻璃效果
        )
    }
}
```

#### 1.3 窗口面板优化
```swift
// 浮动窗口 Liquid Glass 化
struct FloatingPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            // 玻璃化标题栏
            HStack {
                Text("UnclutterPlus")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button("Close") {
                    // 关闭
                }
                .buttonStyle(.glass)
            }
            .padding()
            .background(
                LiquidGlassHeader()
            )

            // 内容区域
            ScrollView {
                MainContentView()
                    .padding()
            }
        }
        .frame(width: 800, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .liquidGlass()  // 应用 Liquid Glass
                .shadow(color: .black.opacity(0.1), radius: 20)
        )
    }
}
```

### 2. 原生 WebView 应用 (⭐⭐⭐⭐)

#### 2.1 笔记链接预览
```swift
// 笔记中的链接预览组件
struct LinkPreviewView: View {
    let url: URL
    @State private var webView: WebView?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let webView = webView {
                webView
                    .frame(height: 200)
                    .cornerRadius(12)
                    .glassEffect()
            } else {
                // 加载占位符
                LoadingPlaceholder()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .glassEffect()
        )
        .onAppear {
            loadWebView()
        }
    }

    private func loadWebView() {
        let webPage = WebPage {
            WebView(url: url)
        }
        webView = WebView(page: webPage)
    }
}
```

#### 2.2 帮助文档集成
```swift
// 应用内帮助系统
struct HelpView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Getting Started") {
                    NavigationLink("Quick Start") {
                        WebView(url: URL(string: "https://docs.unclutterplus.com/quickstart")!)
                    }
                    NavigationLink("Tutorial") {
                        WebView(url: URL(string: "https://docs.unclutterplus.com/tutorial")!)
                    }
                }
            }
        } detail: {
            WebView(url: URL(string: "https://docs.unclutterplus.com")!)
        }
        .navigationTitle("Help")
    }
}
```

### 3. 工具栏玻璃化 (⭐⭐⭐⭐)

#### 3.1 主工具栏升级
```swift
// 主窗口工具栏 Liquid Glass 化
struct MainToolbar: View {
    @State private var selectedTab = 0
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏区域
            HStack(spacing: 16) {
                // 标签页选择 - Liquid Glass 化
                HStack(spacing: 8) {
                    ForEach(["Files", "Clipboard", "Notes"], id: \.self) { tab in
                        Button(tab) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = getTabIndex(tab)
                            }
                        }
                        .buttonStyle(.glass)
                        .glassEffectID(tab.lowercased(), in: namespace)
                    }
                }

                Spacer()

                // 功能按钮组
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Add") { addItem() }
                        .buttonStyle(.glass)

                    Button("Search") { showSearch() }
                        .buttonStyle(.glass)

                    Button("Settings") { showSettings() }
                        .buttonStyle(.glass)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                // 工具栏玻璃背景
                Rectangle()
                    .fill(.clear)
                    .glassEffect()
            )
        }

        Divider()

        // 内容区域
        TabView(selection: $selectedTab) {
            FilesView()
                .tag(0)
                .glassEffectID("files", in: namespace)

            ClipboardView()
                .tag(1)
                .glassEffectID("clipboard", in: namespace)

            NotesView()
                .tag(2)
                .glassEffectID("notes", in: namespace)
        }
        .tabViewStyle(.glass)
    }
}
```

#### 3.2 工具栏分组
```swift
// 高级工具栏配置
struct AdvancedToolbar: View {
    var body: some View {
        VStack(spacing: 0) {
            // 主工具栏组
            Toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Back") { }
                        .buttonStyle(.glass)
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button("New") { }
                        .buttonStyle(.glass)

                    Button("Save") { }
                        .buttonStyle(.glass)
                }

                // 分隔符
                ToolbarSpacer()

                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Share") { }
                        .buttonStyle(.glass)

                    Button("Export") { }
                        .buttonStyle(.glass)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.glass, for: .navigationBar)

            // 内容
            mainContent
        }
    }
}
```

### 4. TextEditor 富文本增强 (⭐⭐⭐⭐⭐)

#### 4.1 Markdown 编辑器升级
```swift
// 富文本 Markdown 编辑器
struct RichTextEditor: View {
    @State private var content = ""
    @State private var isEditing = true
    @State private var selectedRange: Range<String.Index>?

    var body: some View {
        HStack(spacing: 0) {
            // 编辑器区域
            VStack(spacing: 0) {
                // 工具栏
                HStack(spacing: 8) {
                    Button("Bold") { addBold() }
                        .buttonStyle(.glass)

                    Button("Italic") { addItalic() }
                        .buttonStyle(.glass)

                    Button("Code") { addCode() }
                        .buttonStyle(.glass)

                    Spacer()

                    Button(isEditing ? "Preview" : "Edit") {
                        isEditing.toggle()
                    }
                    .buttonStyle(.glass)
                }
                .padding()
                .background(
                    Rectangle()
                        .glassEffect()
                )

                // 编辑器或预览
                if isEditing {
                    TextEditor(text: $content)
                        .font(.body)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .glassEffect()
                        )
                } else {
                    MarkdownView(content: content)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .glassEffect()
                        )
                }
            }

            // 分屏模式分隔线
            if isSplitView {
                Divider()
                    .background(.clear)
                    .frame(width: 1)
                    .glassEffect()
            }

            // 预览区域
            if isSplitView {
                MarkdownView(content: content)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .glassEffect()
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addBold() {
        // 实现粗体添加逻辑
        // 基于新的富文本API
    }

    private func addItalic() {
        // 实现斜体添加逻辑
    }

    private func addCode() {
        // 实现代码添加逻辑
    }
}
```

### 5. TabView 增强应用 (⭐⭐⭐)

#### 5.1 高级标签页样式
```swift
// 增强的标签页组件
struct EnhancedTabView: View {
    @State private var selectedTab = 0
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            // 自定义标签页选择器
            HStack(spacing: 12) {
                TabButton(
                    title: "Files",
                    systemImage: "folder",
                    isSelected: selectedTab == 0
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = 0
                    }
                }
                .glassEffectID("files", in: namespace)

                TabButton(
                    title: "Clipboard",
                    systemImage: "doc.on.clipboard",
                    isSelected: selectedTab == 1
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = 1
                    }
                }
                .glassEffectID("clipboard", in: namespace)

                TabButton(
                    title: "Notes",
                    systemImage: "note.text",
                    isSelected: selectedTab == 2
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = 2
                    }
                }
                .glassEffectID("notes", in: namespace)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .glassEffect()
            )

            // 内容区域
            ZStack {
                if selectedTab == 0 {
                    FilesView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .glassEffectID("files", in: namespace)
                } else if selectedTab == 1 {
                    ClipboardView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .glassEffectID("clipboard", in: namespace)
                } else {
                    NotesView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .glassEffectID("notes", in: namespace)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

---

## 📊 应用优先级建议

### 阶段1: 核心UI升级 (1-2天)
**高优先级特性**:
1. ✅ **Liquid Glass 按钮样式** - 替换所有现有按钮
2. ✅ **工具栏玻璃化** - 主窗口工具栏现代化
3. ✅ **TextEditor 富文本支持** - 笔记功能核心改进

### 阶段2: 交互体验提升 (2-3天)
**中等优先级特性**:
1. ✅ **TabView Liquid Glass 化** - 标签页切换动画
2. ✅ **glassEffectID 过渡动画** - 视图间流畅切换
3. ✅ **WebView 链接预览** - 笔记增强功能

### 阶段3: 高级特性 (3-5天)
**增强功能**:
1. ✅ **GlassEffectContainer 容器** - 整体界面统一
2. ✅ **ToolbarItemGroup 分组** - 工具栏组织优化
3. ✅ **富文本编辑增强** - Markdown 编辑器升级

---

## 💡 具体实现示例

### 1. 主窗口 Liquid Glass 化
```swift
// MainContentView.swift 升级
struct MainContentView: View {
    @Namespace var namespace

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏 - Liquid Glass
            headerView
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .liquidGlass()
                )

            Divider()

            // 内容区域
            contentView
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .liquidGlass()
        )
    }

    private var headerView: some View {
        HStack {
            // 标签页
            TabBar(namespace: namespace)

            Spacer()

            // 功能按钮
            HStack(spacing: 8) {
                Button("Add") { }
                    .buttonStyle(.glass)

                Button("Settings") { }
                    .buttonStyle(.glass)
            }
        }
    }

    private var contentView: some View {
        GlassEffectContainer(spacing: 12) {
            // 主要内容
            MainContent()
        }
    }
}
```

### 2. 笔记编辑器升级
```swift
// NotesView.swift 升级
struct NotesView: View {
    @State private var selectedNote: Note?
    @State private var isEditing = false
    @State private var content = ""

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            noteList
                .frame(width: 300)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .glassEffect()
                )

            Divider()
                .frame(width: 1)
                .background(.clear)

            // 编辑器区域
            editorArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noteList: some View {
        List(notes) { note in
            NoteRow(note: note) {
                selectedNote = note
            }
            .onTapGesture {
                selectedNote = note
            }
        }
        .listStyle(.plain)
    }

    private var editorArea: some View {
        VStack(spacing: 0) {
            // 编辑器工具栏
            editorToolbar
                .padding()
                .background(
                    Rectangle()
                        .glassEffect()
                )

            Divider()

            // 编辑器或预览
            if isEditing {
                RichTextEditor(
                    content: $content,
                    onSave: saveNote
                )
            } else {
                MarkdownView(content: content)
                    .padding()
            }
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 8) {
            Button("Bold") { addBold() }
                .buttonStyle(.glass)

            Button("Italic") { addItalic() }
                .buttonStyle(.glass)

            Spacer()

            Button(isEditing ? "Preview" : "Edit") {
                isEditing.toggle()
            }
            .buttonStyle(.glass)
        }
    }
}
```

---

## 🎯 预期效果

### 视觉效果提升
- ✅ **现代化界面**: Liquid Glass 带来全新视觉体验
- ✅ **流畅动画**: glassEffectID 实现无缝过渡
- ✅ **统一设计**: 整个应用视觉风格一致

### 功能性增强
- ✅ **富文本编辑**: 真正的富文本 Markdown 编辑
- ✅ **链接预览**: 原生 WebView 集成
- ✅ **工具栏优化**: 更高效的操作体验

### 性能改进
- ✅ **渲染性能**: SwiftUI 2025 渲染优化
- ✅ **滚动性能**: List 和滚动视图大幅提升
- ✅ **动画性能**: Liquid Glass 硬件加速

---

## 🚀 实施计划

### Week 1: 基础升级
- [ ] 升级到 Xcode 26 和 macOS 26
- [ ] 替换所有按钮样式为 .glass
- [ ] 工具栏玻璃化

### Week 2: 交互升级
- [ ] 实现 TabView Liquid Glass
- [ ] 添加 glassEffectID 过渡动画
- [ ] 工具栏分组优化

### Week 3: 功能增强
- [ ] 集成 WebView 链接预览
- [ ] TextEditor 富文本支持
- [ ] 整体测试和优化

### Week 4: 打磨完善
- [ ] 性能优化
- [ ] 用户体验测试
- [ ] 发布准备

通过这些升级，UnclutterPlus 将成为一个真正现代化、高性能的 macOS 应用！🎉
