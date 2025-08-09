import SwiftUI

struct NotesView: View {
    // 使用 ObservedObject 而不是 StateObject，因为我们使用单例
    @ObservedObject private var notesManager = NotesManager.shared
    @State private var selectedNote: Note?
    @State private var showingNewNoteDialog = false
    @State private var newNoteTitle = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧：笔记列表
            VStack(spacing: 0) {
                // 搜索和新建按钮
                HStack {
                    Button(action: { showingNewNoteDialog = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New Note")
                    
                    Spacer()
                    
                    Text("\(notesManager.notes.count) notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Divider()
                
                // 笔记列表
                if notesManager.notes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("No notes yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Create First Note") {
                            showingNewNoteDialog = true
                        }
                        .buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 1) {  // 使用 VStack 替代 LazyVStack
                            ForEach(notesManager.notes) { note in
                                NoteListItemView(
                                    note: note,
                                    isSelected: selectedNote?.id == note.id
                                ) {
                                    // 切换笔记时立即响应
                                    if selectedNote?.id != note.id {  // 避免重复选中
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedNote = note
                                        }
                                    }
                                } onDelete: {
                                    if selectedNote?.id == note.id {
                                        selectedNote = nil
                                    }
                                    notesManager.deleteNote(note)
                                }
                            }
                        }
                        .padding(.vertical, 1)  // 添加小间距避免边缘点击问题
                    }
                }
            }
            .frame(width: 250)
            .background(.regularMaterial)
            .zIndex(1)  // 提高列表的 z-index 优先级
            
            Divider()
            
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
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Select a note to edit")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Choose a note from the sidebar or create a new one")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingNewNoteDialog) {
            NewNoteDialog(
                noteTitle: $newNoteTitle,
                onCreate: { title in
                    let note = notesManager.createNote(title: title.isEmpty ? "Untitled" : title)
                    selectedNote = note
                    newNoteTitle = ""
                    showingNewNoteDialog = false
                },
                onCancel: {
                    newNoteTitle = ""
                    showingNewNoteDialog = false
                }
            )
        }
    }
}

struct NoteListItemView: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
            
            Text(note.preview)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .lineLimit(2)
            
            Text(note.modifiedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.6) : .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle()
                .fill(isSelected ? Color.accentColor : 
                      isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())  // 确保整个区域可点击
        .onHover { hovering in
            isHovered = hovering
        }
        // 使用同时响应的点击手势
        .onTapGesture {
            onSelect()
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // 备用点击处理
                    onSelect()
                }
        )
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct NewNoteDialog: View {
    @Binding var noteTitle: String
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Note")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Note Title:")
                    .font(.subheadline)
                
                TextField("Enter note title...", text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        onCreate(noteTitle)
                    }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    onCreate(noteTitle)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
        .padding(20)
        .frame(width: 300)
        .background(.regularMaterial)
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    NotesView()
        .frame(width: 800, height: 250)
}
#endif