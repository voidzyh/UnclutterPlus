import SwiftUI
import AppKit
import MarkdownUI
import Splash

enum EditorMode: String, CaseIterable {
    case edit = "Edit"
    case preview = "Preview"
    case both = "Both"
    
    var systemImage: String {
        switch self {
        case .edit: return "pencil"
        case .preview: return "eye"
        case .both: return "rectangle.split.2x1"
        }
    }
}

struct NoteEditorView: View {
    let note: Note
    let onUpdate: (Note) -> Void
    
    @State private var title: String
    @State private var content: String
    @State private var editorMode: EditorMode = .both
    @State private var showOutline = false
    @State private var isSaving = false
    @State private var saveStatus: String = ""
    @ObservedObject private var prefs = Preferences.shared
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    @State private var saveTimer: Timer?
    @State private var selectedHeading: String? = nil
    
    init(note: Note, onUpdate: @escaping (Note) -> Void) {
        self.note = note
        self.onUpdate = onUpdate
        self._title = State(initialValue: note.title)
        self._content = State(initialValue: note.content)
    }
    
    // 监听 note 的变化并更新状态
    private func updateStateFromNote() {
        // 保存当前状态以避免不必要的更新
        let needsUpdate = title != note.title || content != note.content
        if needsUpdate {
            title = note.title
            content = note.content
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentSection
        }
        .onChange(of: title) { _, _ in 
            saveNoteDebounced()
        }
        .onChange(of: content) { _, _ in 
            saveNoteDebounced()
        }
        .onAppear { updateStateFromNote() }
        .onChange(of: note.id) { _, _ in
            saveTimer?.invalidate()
            updateStateFromNote()
        }
        // preferences are synced via Preferences.shared
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            // 标题和状态栏
            HStack {
                TextField("Note title", text: $title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit { saveNote() }
                    .onChange(of: isTitleFocused) { oldValue, newValue in
                        WindowManager.shared.setEditingNote(newValue)
                    }

                Spacer()
                
                // 笔记统计信息
                HStack(spacing: 12) {
                    Label("\(note.wordCount)", systemImage: "textformat.abc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .help("\(note.wordCount) \("note.words".localized), \(note.characterCount) \("note.characters".localized)")
                    
                    if note.readingTime > 0 {
                        Label("\(note.readingTime) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .help("阅读时间估计")
                    }
                    
                    // 保存状态
                    if isSaving {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("保存中...")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    } else if !saveStatus.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                            Text(saveStatus)
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                }
            }
            
            // 工具栏
            HStack {
                // 视图模式选择
                Picker("", selection: $editorMode) {
                    ForEach(EditorMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .labelsHidden()
                
                Spacer()
                
                // 大纲切换
                if !note.headings.isEmpty {
                    Button(action: { showOutline.toggle() }) {
                        Image(systemName: showOutline ? "list.bullet.rectangle" : "list.bullet.rectangle.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.borderless)
                    .help(showOutline ? "隐藏大纲" : "显示大纲")
                }
                
                // Markdown 工具栏
                MarkdownToolbar { action in
                    insertMarkdown(action)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var contentSection: some View {
        HStack(spacing: 0) {
            // 主编辑区域
            Group {
                switch editorMode {
                case .edit:
                    editOnlyView
                case .preview:
                    previewOnlyView
                case .both:
                    splitView
                }
            }
            
            // 大纲侧边栏
            if showOutline && !note.headings.isEmpty {
                Divider()
                outlineView
            }
        }
    }
    
    @ViewBuilder
    private var editOnlyView: some View {
        VStack(spacing: 0) {
            AppKitTextEditor(
                text: $content,
                font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ) { _ in
                saveNoteDebounced()
            }
            .focused($isContentFocused)
            .onChange(of: isContentFocused) { oldValue, newValue in
                WindowManager.shared.setEditingNote(newValue)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var previewOnlyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if content.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("开始编写你的笔记")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("切换到编辑模式或分屏模式开始编写")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    Markdown(content, baseURL: prefs.enableBaseURL ? URL(string: prefs.baseURLString) : nil)
                        .markdownTheme(prefs.markdownTheme.toMarkdownUITheme())
                        .markdownCodeSyntaxHighlighter(
                            .splash(theme: prefs.codeHighlightTheme.toSplashTheme(fontSize: 14))
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private var splitView: some View {
        HStack(spacing: 0) {
            // 左侧编辑器
            VStack(spacing: 0) {
                HStack {
                    Text("编辑")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                
                AppKitTextEditor(
                    text: $content,
                    font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                ) { _ in
                    saveNoteDebounced()
                }
                .focused($isContentFocused)
                .padding()
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // 右侧预览
            VStack(spacing: 0) {
                HStack {
                    Text("预览")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if content.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "eye")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                
                                Text("预览将在这里显示")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else {
                            Markdown(content, baseURL: prefs.enableBaseURL ? URL(string: prefs.baseURLString) : nil)
                                .markdownTheme(prefs.markdownTheme.toMarkdownUITheme())
                                .markdownCodeSyntaxHighlighter(
                                    .splash(theme: prefs.codeHighlightTheme.toSplashTheme(fontSize: 13))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
    }
    
    @ViewBuilder
    private var outlineView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("大纲")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showOutline = false }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(note.headings, id: \.self) { heading in
                        OutlineItemView(
                            heading: heading,
                            isSelected: selectedHeading == heading
                        ) {
                            selectedHeading = heading
                            // TODO: 实现跳转到对应标题
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 200)
        .background(.regularMaterial)
    }
    
    private func saveNote() {
                        let newTitle = title.isEmpty ? "note.untitled".localized : title
        if note.title != newTitle || note.content != content {
            isSaving = true
            
            var updatedNote = note
            updatedNote.title = newTitle
            updatedNote.content = content
            onUpdate(updatedNote)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                saveStatus = "已保存"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    saveStatus = ""
                }
            }
        }
    }
    
    private func saveNoteDebounced() {
        saveTimer?.invalidate()
        saveStatus = ""
        
        // 使用设置中的自动保存间隔
        let interval = prefs.notesAutoSaveInterval
        saveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            self.saveNote()
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
    
    // 使用 MarkdownUI 后不再需要手写 renderMarkdown
}

enum MarkdownAction {
    case bold, italic, strikethrough, code, link
    case header1, header2, header3
    case bulletList, numberedList, taskList
    case quote, codeBlock
}

// Theme enums moved to MarkdownPreferences.swift

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
        weight: SwiftUI.Font.Weight = .regular,
        style: SwiftUI.Font.TextStyle = .body,
        strikethrough: Bool = false,
        monospaced: Bool = false,
        action: MarkdownAction
    ) -> some View {
        Button(action: { onAction(action) }) {
            Text(text)
                .font(monospaced ? SwiftUI.Font.system(.body, design: .monospaced) : SwiftUI.Font.system(.body))
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

struct OutlineItemView: View {
    let heading: String
    let isSelected: Bool
    let onTap: () -> Void
    
    private var level: Int {
        let trimmed = heading.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix(while: { $0 == "#" }).count
        return max(1, min(6, level))
    }
    
    private var text: String {
        let trimmed = heading.trimmingCharacters(in: .whitespaces)
        return String(trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(level == 1 ? .headline : level == 2 ? .subheadline : .caption)
                    .fontWeight(level <= 2 ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat((level - 1) * 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    NoteEditorView(
        note: Note(title: "Sample Note", content: "# Hello\n\nThis is **bold** text."),
        onUpdate: { _ in }
    )
    .frame(width: 1000, height: 600)
}
#endif