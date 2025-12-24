import SwiftUI
import Combine
import MarkdownUI

// 简单的对话框视图 - 移出 ViewBuilder
struct NoteDialogView: View {
    let title: String
    let message: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
            HStack {
                Button("Cancel", action: onCancel)
                Button("Create", action: onConfirm)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

/// 现代化笔记视图 - 改进的交互体验和流畅动画
struct ModernNotesView: View {
    @StateObject private var viewModel = ModernNotesViewModel()
    @Namespace private var notesNamespace
    
    // 状态管理
    @State private var selectedNote: Note?
    @State private var searchText: String = ""
    @State private var showingNewNoteDialog = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isCreatingNew = false
    
    // 动画状态
    @State private var itemsOpacity: Double = 1.0
    @State private var headerBlur: CGFloat = 0
    @State private var sidebarWidth: CGFloat = 300
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            if viewModel.viewLayout == .sidebar {
                sidebarView
                    .frame(width: sidebarWidth)
                    .background(Color(NSColor.controlBackgroundColor))
            }
            
            // 主内容区域
            mainContentView
        }
        .sheet(isPresented: $showingNewNoteDialog, content: {
            NoteDialogView(
                title: "New Note",
                message: "Create a new note",
                onConfirm: {
                    viewModel.createNote()
                    showingNewNoteDialog = false
                },
                onCancel: {
                    showingNewNoteDialog = false
                }
            )
        })
        .onAppear {
            viewModel.loadInitialData()
        }
    }
    
    // MARK: - 侧边栏视图
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            modernHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
                .background(Color.accentColor.opacity(0.1))
            
            // 统计信息
            if let stats = viewModel.statistics {
                statisticsView(stats: stats)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            
            // 笔记列表
            notesListView
        }
    }
    
    // MARK: - 主内容视图
    
    private var mainContentView: some View {
        Group {
            if let note = selectedNote ?? viewModel.selectedNote {
                noteEditorView(note: note)
            } else if isCreatingNew {
                newNoteEditorView
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 现代化头部
    
    private var modernHeader: some View {
        VStack(spacing: 12) {
            // 主要工具栏
            HStack(spacing: 12) {
                // 搜索栏
                modernSearchBar
                
                Spacer()
                
                // 新建笔记按钮
                newNoteButton
            }
            
            // 视图模式切换
            viewModeSelector
        }
    }
    
    // MARK: - 现代化搜索栏
    
    private var modernSearchBar: some View {
        HStack(spacing: 8) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundColor(.secondary)
            
            // 搜索输入
            TextField("Search notes...", text: $searchText)
                .font(.body)
                .textFieldStyle(.plain)
                .onSubmit {
                    viewModel.searchText = searchText
                }
                .onChange(of: searchText) { oldValue, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.searchText = newValue
                    }
                }
            
            // 清除按钮
            if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                        viewModel.searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 新建笔记按钮
    
    private var newNoteButton: some View {
        Button(action: {
            showingNewNoteDialog = true
        }) {
            Image(systemName: "square.and.pencil")
                .font(.title3)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
    
    // MARK: - 视图模式选择器
    
    private var viewModeSelector: some View {
        Picker("View Mode", selection: $viewModel.viewLayout) {
            ForEach(ViewLayout.allCases, id: \.self) { layout in
                Image(systemName: layout.systemImage)
                    .tag(layout)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - 统计视图
    
    private func statisticsView(stats: NoteStatistics) -> some View {
        HStack(spacing: 16) {
            StatisticCard(title: "Total", value: "\(stats.totalNotes)", icon: "note.text", color: .blue)
            StatisticCard(title: "Favorites", value: "\(stats.favoriteNotes)", icon: "star.fill", color: .yellow)
            StatisticCard(title: "Words", value: "\(stats.totalWords)", icon: "character.textbox", color: .green)
        }
    }
    
    // MARK: - 笔记列表视图
    
    private var notesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // 笔记列表
                    ForEach(viewModel.filteredNotes) { note in
                        NoteListItemView(
                            note: NoteIndex(from: note),
                            isSelected: selectedNote?.id == note.id || viewModel.selectedNote?.id == note.id,
                            isMultiSelected: viewModel.selectedNoteIds.contains(note.id),
                            showSelectionMode: viewModel.isMultiSelectMode,
                            onSelect: {
                                selectNote(note)
                            },
                            onDelete: {
                                viewModel.deleteNote(note)
                            },
                            onToggleFavorite: {
                                viewModel.toggleFavorite(note)
                            },
                            onToggleSelection: {
                                viewModel.toggleSelection(note)
                            }
                        )
                        .id(note.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.filteredNotes.count)
                    }
                    
                    // 空状态
                    if viewModel.filteredNotes.isEmpty {
                        emptyNotesStateView
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
        }
    }
    
    // MARK: - 笔记编辑器视图
    
    private func noteEditorView(note: Note) -> some View {
        VStack(spacing: 0) {
            // 编辑器工具栏
            editorToolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
                .background(Color.accentColor.opacity(0.1))
            
            // 编辑器内容
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题输入
                    TextField("Note Title", text: Binding(
                        get: { note.title },
                        set: { newTitle in
                            if var updatedNote = viewModel.selectedNote {
                                updatedNote.title = newTitle
                                viewModel.updateSelectedNote(title: newTitle)
                                viewModel.selectedNote = updatedNote
                            }
                        }
                    ))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // 标签输入
                    tagsInputView(note: note)
                        .padding(.horizontal, 16)
                    
                    // 内容编辑器
                    TextEditor(text: Binding(
                        get: { note.content },
                        set: { newContent in
                            if var updatedNote = viewModel.selectedNote {
                                updatedNote.content = newContent
                                viewModel.updateSelectedNote(content: newContent)
                                viewModel.selectedNote = updatedNote
                            }
                        }
                    ))
                    .font(.body)
                    .frame(minHeight: 400)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    // 预览区域
                    if !note.content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.headline)
                                .padding(.horizontal, 16)
                            
                            Markdown(note.content)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 新笔记编辑器视图
    
    private var newNoteEditorView: some View {
        VStack(spacing: 0) {
            // 编辑器工具栏
            editorToolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
                .background(Color.accentColor.opacity(0.1))
            
            // 新笔记内容
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题输入
                    TextField("Note Title", text: $viewModel.newNoteTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    // 标签输入
                    tagsInputView(note: Note(title: viewModel.newNoteTitle, content: ""))
                        .padding(.horizontal, 16)
                    
                    // 内容输入
                    TextEditor(text: $viewModel.newNoteContent)
                        .font(.body)
                        .frame(minHeight: 400)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    
                    // 预览区域
                    if !viewModel.newNoteContent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.headline)
                                .padding(.horizontal, 16)
                            
                            Markdown(viewModel.newNoteContent)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 编辑器工具栏
    
    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // 保存状态
            if viewModel.isSaving {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            Spacer()
            
            // 格式工具
            ForEach(MarkdownTool.allCases, id: \.self) { tool in
                ToolButton(tool: tool) {
                    applyMarkdownTool(tool)
                }
            }
            
            Divider()
                .padding(.horizontal, 4)
            
            // 格式按钮
            ForEach(MarkdownFormat.allCases, id: \.self) { format in
                FormatButton(format: format) {
                    applyMarkdownFormat(format)
                }
            }
        }
    }
    
    // MARK: - 标签输入视图
    
    private func tagsInputView(note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // 当前标签
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(note.tags, id: \.self) { tag in
                            TagView(tag: tag, isSelected: true) {
                                // 移除标签逻辑
                                if var updatedNote = viewModel.selectedNote {
                                    updatedNote.tags.removeAll { $0 == tag }
                                    viewModel.updateSelectedNote(tags: updatedNote.tags)
                                    viewModel.selectedNote = updatedNote
                                }
                            }
                        }
                    }
                }
                .frame(height: 30)
            }
            
            // 添加新标签
            HStack(spacing: 8) {
                TextField("Add tag...", text: $viewModel.newNoteTag)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                
                Button("Add") {
                    if !viewModel.newNoteTag.isEmpty {
                        if var updatedNote = viewModel.selectedNote {
                            if !updatedNote.tags.contains(viewModel.newNoteTag) {
                                updatedNote.tags.append(viewModel.newNoteTag)
                                viewModel.updateSelectedNote(tags: updatedNote.tags)
                                viewModel.selectedNote = updatedNote
                            }
                        }
                        viewModel.newNoteTag = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No Note Selected")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Select a note from the sidebar or create a new one")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create New Note") {
                showingNewNoteDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空笔记状态视图
    
    private var emptyNotesStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No Notes")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Create your first note to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create Note") {
                showingNewNoteDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - 事件处理
    
    private func selectNote(_ note: Note) {
        selectedNote = note
        viewModel.selectNote(note)
    }
    
    private func applyMarkdownTool(_ tool: MarkdownTool) {
        // 实现Markdown工具逻辑
        logger.info("Applying tool: \(tool.title)", category: "ModernNotesView")
    }
    
    private func applyMarkdownFormat(_ format: MarkdownFormat) {
        // 实现Markdown格式逻辑
        logger.info("Applying format: \(format.title)", category: "ModernNotesView")
    }
}

// MARK: - 偏好键

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 统计卡片组件

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - 工具按钮

struct ToolButton: View {
    let tool: MarkdownTool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: tool.icon)
                .font(.body)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(tool.title)
    }
}

// MARK: - 格式按钮

struct FormatButton: View {
    let format: MarkdownFormat
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(format.title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(format.title)
    }
}

// MARK: - 辅助类型

enum MarkdownTool: String, CaseIterable {
    case bold = "bold"
    case italic = "italic"
    case strikethrough = "strikethrough"
    case link = "link"
    case image = "image"
    case code = "code"
    case quote = "quote"
    case list = "list"
    case numberedList = "numberedList"
    case heading = "heading"
    
    var title: String {
        switch self {
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .strikethrough: return "Strikethrough"
        case .link: return "Link"
        case .image: return "Image"
        case .code: return "Code"
        case .quote: return "Quote"
        case .list: return "List"
        case .numberedList: return "Numbered List"
        case .heading: return "Heading"
        }
    }
    
    var icon: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .strikethrough: return "strikethrough"
        case .link: return "link"
        case .image: return "photo"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .quote: return "quote.opening"
        case .list: return "list.bullet"
        case .numberedList: return "list.number"
        case .heading: return "textformat"
        }
    }
}

enum MarkdownFormat: String, CaseIterable {
    case h1 = "H1"
    case h2 = "H2"
    case h3 = "H3"
    case paragraph = "Paragraph"
    
    var title: String { rawValue }
}

// MARK: - 扩展 ModernNotesViewModel

extension ModernNotesViewModel {
    var newNoteContent: String {
        get { "" }
        set { }
    }
    
    var newNoteTag: String {
        get { "" }
        set { }
    }
}

// MARK: - 预览

struct ModernNotesView_Previews: PreviewProvider {
    static var previews: some View {
        ModernNotesView()
            .frame(width: 1200, height: 800)
    }
}
