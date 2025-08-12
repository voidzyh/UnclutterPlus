import SwiftUI

enum ViewLayout: String, CaseIterable {
    case sidebar = "Sidebar"
    case focus = "Focus"
    
    var systemImage: String {
        switch self {
        case .sidebar: return "sidebar.left"
        case .focus: return "doc.text"
        }
    }
}

struct NotesView: View {
    @ObservedObject private var notesManager = NotesManager.shared
    @State private var selectedNote: Note?
    @State private var showingNewNoteDialog = false
    @State private var newNoteTitle = ""
    @State private var newNoteTags: Set<String> = []
    @State private var viewLayout: ViewLayout = .sidebar
    @State private var isMultiSelectMode = false
    @State private var sidebarWidth: CGFloat = 300
    @State private var showingTagEditor = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search notes...", text: $notesManager.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 250)
                
                Spacer()
                
                // 布局选择
                Picker("Layout", selection: $viewLayout) {
                    ForEach(ViewLayout.allCases, id: \.self) { layout in
                        Image(systemName: layout.systemImage)
                            .tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .labelsHidden()
                
                // 排序和工具
                Menu {
                    Section("Sort by") {
                        ForEach(NotesSortOption.allCases, id: \.self) { option in
                            Button(action: { notesManager.sortOption = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if notesManager.sortOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { notesManager.isAscending.toggle() }) {
                        HStack {
                            Text(notesManager.isAscending ? "Ascending" : "Descending")
                            Spacer()
                            Image(systemName: notesManager.isAscending ? "arrow.up" : "arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                
                // 收藏按钮（针对选中的笔记）
                if let selectedNote = selectedNote {
                    Button(action: { 
                        notesManager.toggleFavorite(selectedNote)
                    }) {
                        Image(systemName: selectedNote.isFavorite ? "star.fill" : "star")
                            .foregroundColor(selectedNote.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(selectedNote.isFavorite ? "取消收藏" : "收藏")
                    
                    // 删除按钮（针对选中的笔记）
                    Button(action: { 
                        let noteToDelete = selectedNote
                        self.selectedNote = nil
                        notesManager.deleteNote(noteToDelete)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("删除笔记")
                }
                
                // 多选模式按钮
                Button(action: {
                    isMultiSelectMode.toggle()
                    if !isMultiSelectMode {
                        notesManager.deselectAll()
                    }
                }) {
                    Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(isMultiSelectMode ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(isMultiSelectMode ? "Exit selection mode" : "Enter selection mode")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            
            Divider()
            
            // 主要内容区域
            Group {
                switch viewLayout {
                case .sidebar:
                    sidebarLayout
                case .focus:
                    focusLayout
                }
            }
        }
        .sheet(isPresented: $showingNewNoteDialog) {
            NewNoteDialog(
                noteTitle: $newNoteTitle,
                noteTags: $newNoteTags,
                availableTags: notesManager.allTags,
                onCreate: { title, tags in
                    let note = notesManager.createNote(title: title.isEmpty ? "Untitled" : title, tags: tags)
                    selectedNote = note
                    newNoteTitle = ""
                    newNoteTags.removeAll()
                    showingNewNoteDialog = false
                },
                onCancel: {
                    newNoteTitle = ""
                    newNoteTags.removeAll()
                    showingNewNoteDialog = false
                }
            )
        }
    }
    
    @ViewBuilder
    private var sidebarLayout: some View {
        HStack(spacing: 0) {
            // 左侧：笔记列表
            VStack(spacing: 0) {
                // 新建笔记按钮
                NewNoteButton(action: { showingNewNoteDialog = true })
                
                Divider()
                
                // 统计信息
                HStack {
                    Text("\(notesManager.filteredNotes.count) notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !notesManager.searchText.isEmpty {
                        Text("(已筛选)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    if isMultiSelectMode && !notesManager.selectedNotes.isEmpty {
                        Text("\(notesManager.selectedNotes.count) 已选")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                Divider()
                
                // 笔记列表
                if notesManager.filteredNotes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: notesManager.searchText.isEmpty ? "note.text" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text(notesManager.searchText.isEmpty ? "No notes yet" : "No matching notes")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if notesManager.searchText.isEmpty {
                            Button("Create First Note") {
                                showingNewNoteDialog = true
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Text("Try a different search term")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(notesManager.filteredNotes) { note in
                                NoteListItemView(
                                    note: note,
                                    isSelected: selectedNote?.id == note.id,
                                    isMultiSelected: notesManager.selectedNotes.contains(note.id),
                                    showSelectionMode: isMultiSelectMode
                                ) {
                                    // 主操作
                                    if isMultiSelectMode {
                                        notesManager.toggleSelection(note)
                                    } else {
                                        if selectedNote?.id != note.id {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                selectedNote = note
                                            }
                                        }
                                    }
                                } onDelete: {
                                    if selectedNote?.id == note.id {
                                        selectedNote = nil
                                    }
                                    notesManager.deleteNote(note)
                                } onToggleFavorite: {
                                    notesManager.toggleFavorite(note)
                                } onToggleSelection: {
                                    notesManager.toggleSelection(note)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // 底部操作栏
                if isMultiSelectMode && !notesManager.selectedNotes.isEmpty {
                    Divider()
                    HStack {
                        Button("删除已选 (\(notesManager.selectedNotes.count))") {
                            let selectedNotes = notesManager.filteredNotes.filter { notesManager.selectedNotes.contains($0.id) }
                            notesManager.deleteNotes(selectedNotes)
                            if let selected = selectedNote, notesManager.selectedNotes.contains(selected.id) {
                                self.selectedNote = nil
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("全选") {
                            notesManager.selectAll()
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .frame(width: sidebarWidth)
            .background(.regularMaterial)
            
            // 分隔线和拖拽区域
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
                .overlay(
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 8)
                        .contentShape(Rectangle())
                        .cursor(.resizeLeftRight)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newWidth = sidebarWidth + value.translation.width
                                    sidebarWidth = max(200, min(500, newWidth))
                                }
                        )
                )
            
            // 右侧：笔记编辑器
            Group {
                if let selectedNote = selectedNote {
                    NoteEditorView(
                        note: selectedNote,
                        onUpdate: { updatedNote in
                            notesManager.updateNote(updatedNote)
                        }
                    )
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "note.text")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        
                        Text("Select a note to edit")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Choose a note from the sidebar to get started")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    @ViewBuilder
    private var focusLayout: some View {
        // 全屏编辑模式
        if let selectedNote = selectedNote {
            NoteEditorView(
                note: selectedNote,
                onUpdate: { updatedNote in
                    notesManager.updateNote(updatedNote)
                }
            )
        } else {
            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                
                Text("Focus Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Select a note from the toolbar to enter focus mode")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Browse Notes") {
                    viewLayout = .sidebar
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
}

struct NoteListItemView: View {
    let note: Note
    let isSelected: Bool
    let isMultiSelected: Bool
    let showSelectionMode: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleSelection: () -> Void
    
    @State private var isHovered = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 左侧选择框（多选模式）
            if showSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isMultiSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            // 收藏标识（非多选模式）
            if !showSelectionMode && note.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .yellow)
            }
            
            // 笔记内容
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 标签
                    if !note.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(note.tags.prefix(2)), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(isSelected ? .white.opacity(0.3) : .blue.opacity(0.2))
                                    )
                                    .foregroundColor(isSelected ? .white : .blue)
                            }
                        }
                    }
                }
                
                // 预览文本
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(.body)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // 元信息
                HStack {
                    Text(note.modifiedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                    
                    Text("\(note.wordCount) words")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                    
                    if note.readingTime > 1 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                        
                        Text("\(note.readingTime) min read")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isMultiSelected)
    }
    
    private var backgroundMaterial: Color {
        if isSelected {
            return .accentColor
        } else if isMultiSelected {
            return .accentColor.opacity(0.3)
        } else if isHovered {
            return .gray.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if isMultiSelected {
            return .accentColor
        } else if note.isFavorite {
            return .yellow.opacity(0.3)
        } else {
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected || isMultiSelected || note.isFavorite {
            return 1
        } else {
            return 0
        }
    }
}

struct NewNoteDialog: View {
    @Binding var noteTitle: String
    @Binding var noteTags: Set<String>
    let availableTags: [String]
    let onCreate: (String, Set<String>) -> Void
    let onCancel: () -> Void
    
    @State private var newTagName = ""
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Create New Note")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add a title and tags to organize your note")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                // 标题输入
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.headline)
                    
                    TextField("Enter note title...", text: $noteTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            onCreate(noteTitle, noteTags)
                        }
                }
                
                // 标签选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                    
                    // 已选标签
                    if !noteTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(Array(noteTags), id: \.self) { tag in
                                TagView(tag: tag, isSelected: true) {
                                    noteTags.remove(tag)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    
                    // 可用标签
                    if !availableTags.isEmpty {
                        Text("Available Tags:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 4) {
                            ForEach(availableTags, id: \.self) { tag in
                                if !noteTags.contains(tag) {
                                    TagView(tag: tag, isSelected: false) {
                                        noteTags.insert(tag)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 新标签输入
                    HStack {
                        TextField("Add new tag...", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !newTagName.isEmpty {
                                    noteTags.insert(newTagName.trimmingCharacters(in: .whitespacesAndNewlines))
                                    newTagName = ""
                                }
                            }
                        
                        Button("Add") {
                            if !newTagName.isEmpty {
                                noteTags.insert(newTagName.trimmingCharacters(in: .whitespacesAndNewlines))
                                newTagName = ""
                            }
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .controlSize(.large)
                
                Button("Create Note") {
                    onCreate(noteTitle, noteTags)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom)
        }
        .padding(24)
        .frame(width: 450)
        .background(.regularMaterial)
    }
}

struct TagView: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(tag)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .blue : .gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
}

struct FlowResult {
    var positions: [CGPoint] = []
    var sizes: [CGSize] = []
    var size: CGSize = .zero
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        self.size = CGSize(width: maxWidth, height: y + lineHeight)
    }
}

struct NewNoteButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: isHovered ? 4 : 2, y: 2)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isHovered ? 90 : 0))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("新建笔记")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("创建新的 Markdown 笔记")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
                    .offset(x: isHovered ? 2 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(isHovered ? 0.12 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor.opacity(isHovered ? 0.3 : 0.2), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    NotesView()
        .frame(width: 1000, height: 600)
}
#endif