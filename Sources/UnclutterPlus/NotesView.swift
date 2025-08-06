import SwiftUI

struct NotesView: View {
    @StateObject private var notesManager = NotesManager()
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
                        LazyVStack(spacing: 1) {
                            ForEach(notesManager.notes) { note in
                                NoteListItemView(
                                    note: note,
                                    isSelected: selectedNote?.id == note.id
                                ) {
                                    selectedNote = note
                                } onDelete: {
                                    if selectedNote?.id == note.id {
                                        selectedNote = nil
                                    }
                                    notesManager.deleteNote(note)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 250)
            .background(.regularMaterial)
            
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
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .onTapGesture {
            onSelect()
        }
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

#Preview {
    NotesView()
        .frame(width: 800, height: 250)
}