import SwiftUI
import AppKit

struct NoteEditorView: View {
    let note: Note
    let onUpdate: (Note) -> Void
    
    @State private var title: String
    @State private var content: String
    @State private var showPreview = true
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    @State private var saveTimer: Timer?
    
    init(note: Note, onUpdate: @escaping (Note) -> Void) {
        self.note = note
        self.onUpdate = onUpdate
        self._title = State(initialValue: note.title)
        self._content = State(initialValue: note.content)
    }
    
    // 监听 note 的变化并更新状态
    private func updateStateFromNote() {
        if title != note.title {
            title = note.title
        }
        if content != note.content {
            content = note.content
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题编辑和工具栏
            VStack(spacing: 8) {
                HStack {
                    TextField("Note title", text: $title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .textFieldStyle(.plain)
                        .focused($isTitleFocused)
                        .onSubmit {
                            saveNote()
                        }
                    
                    Spacer()
                    
                    // 预览切换按钮
                    Button(action: { showPreview.toggle() }) {
                        Image(systemName: showPreview ? "eye.slash" : "eye")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .help(showPreview ? "Hide Preview" : "Show Preview")
                }
                
                // Markdown 工具栏
                MarkdownToolbar { action in
                    insertMarkdown(action)
                }
                .disabled(false)  // 确保按钮可点击
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
            
            // 编辑器和预览区域
            HStack(spacing: 0) {
                // 左侧：文本编辑器
                VStack(alignment: .leading, spacing: 0) {
                    AppKitTextEditor(
                        text: $content,
                        font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                    ) { newText in
                        // 在文本变化时保存
                        saveNoteDebounced()
                    }
                    .padding()
                }
                .frame(maxWidth: showPreview ? .infinity : nil)
                
                if showPreview {
                    Divider()
                    
                    // 右侧：简化预览
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preview")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            Text(renderMarkdown(content))
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                }
            }
        }
        .onChange(of: title) { _, _ in
            saveNoteDebounced()
        }
        .onAppear {
            updateStateFromNote()
        }
        .onChange(of: note.id) { _, _ in
            updateStateFromNote()
        }
    }
    
    private func saveNote() {
        var updatedNote = note
        updatedNote.title = title.isEmpty ? "Untitled" : title
        updatedNote.content = content
        onUpdate(updatedNote)
    }
    
    private func saveNoteDebounced() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            saveNote()
        }
    }
    
    private func insertMarkdown(_ action: MarkdownAction) {
        switch action {
        case .bold:
            insertAroundSelection("**", "**")
        case .italic:
            insertAroundSelection("*", "*")
        case .strikethrough:
            insertAroundSelection("~~", "~~")
        case .code:
            insertAroundSelection("`", "`")
        case .link:
            insertAroundSelection("[", "](url)")
        case .header1:
            insertAtLineStart("# ")
        case .header2:
            insertAtLineStart("## ")
        case .header3:
            insertAtLineStart("### ")
        case .bulletList:
            insertAtLineStart("- ")
        case .numberedList:
            insertAtLineStart("1. ")
        case .taskList:
            insertAtLineStart("- [ ] ")
        case .quote:
            insertAtLineStart("> ")
        case .codeBlock:
            insertAroundSelection("\n```\n", "\n```\n")
        }
    }
    
    private func insertAroundSelection(_ prefix: String, _ suffix: String) {
        // 简化实现：在内容末尾插入
        content += prefix + "text" + suffix
    }
    
    private func insertAtLineStart(_ prefix: String) {
        // 简化实现：在内容末尾插入新行
        if !content.isEmpty && !content.hasSuffix("\n") {
            content += "\n"
        }
        content += prefix + "text"
    }
    
    private func renderMarkdown(_ markdown: String) -> String {
        // 简化的 Markdown 渲染，只处理基本格式
        var result = markdown
        
        // 处理标题
        result = result.replacingOccurrences(of: "# ", with: "📝 ")
        result = result.replacingOccurrences(of: "## ", with: "📝 ")
        result = result.replacingOccurrences(of: "### ", with: "📝 ")
        
        // 处理列表
        result = result.replacingOccurrences(of: "- ", with: "• ")
        result = result.replacingOccurrences(of: "* ", with: "• ")
        
        // 处理任务列表
        result = result.replacingOccurrences(of: "- [ ] ", with: "☐ ")
        result = result.replacingOccurrences(of: "- [x] ", with: "☑ ")
        result = result.replacingOccurrences(of: "- [X] ", with: "☑ ")
        
        // 处理引用
        result = result.replacingOccurrences(of: "> ", with: "❝ ")
        
        return result
    }
}

enum MarkdownAction {
    case bold, italic, strikethrough, code, link
    case header1, header2, header3
    case bulletList, numberedList, taskList
    case quote, codeBlock
}

struct MarkdownToolbar: View {
    let onAction: (MarkdownAction) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            HStack {
                ToolbarButton("B", weight: .bold, action: .bold)
                ToolbarButton("I", action: .italic)
                ToolbarButton("S", strikethrough: true, action: .strikethrough)
                ToolbarButton("`", monospaced: true, action: .code)
            }
            
            Divider()
                .frame(height: 16)
            
            HStack {
                ToolbarButton("H1", action: .header1)
                ToolbarButton("H2", action: .header2)
                ToolbarButton("H3", action: .header3)
            }
            
            Divider()
                .frame(height: 16)
            
            HStack {
                ToolbarIconButton("list.bullet", action: .bulletList)
                ToolbarIconButton("list.number", action: .numberedList)
                ToolbarIconButton("checklist", action: .taskList)
            }
            
            Divider()
                .frame(height: 16)
            
            HStack {
                ToolbarIconButton("quote.bubble", action: .quote)
                ToolbarIconButton("curlybraces", action: .codeBlock)
                ToolbarIconButton("link", action: .link)
            }
            
            Spacer()
        }
    }
    
    private func ToolbarButton(
        _ text: String,
        weight: Font.Weight = .regular,
        style: Font.TextStyle = .body,
        strikethrough: Bool = false,
        monospaced: Bool = false,
        action: MarkdownAction
    ) -> some View {
        Button(action: { onAction(action) }) {
            Text(text)
                .font(monospaced ? .system(.body, design: .monospaced) : .system(.body))
                .strikethrough(strikethrough)
                .frame(minWidth: 24, minHeight: 24)
        }
        .buttonStyle(.borderless)
    }
    
    private func ToolbarIconButton(_ systemName: String, action: MarkdownAction) -> some View {
        Button(action: { onAction(action) }) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .frame(minWidth: 24, minHeight: 24)
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    NoteEditorView(
        note: Note(title: "Sample Note", content: "# Hello\n\nThis is **bold** text."),
        onUpdate: { _ in }
    )
    .frame(width: 800, height: 400)
}