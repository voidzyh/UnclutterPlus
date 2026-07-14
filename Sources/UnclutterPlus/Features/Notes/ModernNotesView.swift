import SwiftUI
import Combine
import MarkdownUI

/// 现代化笔记视图 - 改进的交互体验和流畅动画
struct ModernNotesView: View {
    @StateObject private var viewModel = ModernNotesViewModel()
    @Namespace private var notesNamespace
    
    // 状态管理
    @State private var selectedNote: Note?
    @State private var searchText: String = ""
    @State private var isCreatingNew = false
    
    // 侧边栏列可见性
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - 左侧笔记列表 (List Panel)
            VStack(spacing: 0) {
                // 统计条
                if let stats = viewModel.statistics {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ModernStatChip(icon: "doc.text", label: "Total", value: "\(stats.totalNotes)", color: .blue)
                            ModernStatChip(icon: "star.fill", label: "Favorites", value: "\(stats.favoriteNotes)", color: .yellow)
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    }
                    .background(ModernDesignSystem.shared.color(.bgCanvas))
                }
                
                // 笔记列表
                notesList
            }
            .background(ModernDesignSystem.shared.color(.bgCanvas))
            .navigationTitle("Notes")
            // 使用原生 Searchable
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search notes...")
            // 使用原生 Toolbar
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        viewModel.createNote()
                        searchText = ""
                    }) {
                        Label("Create Note", systemImage: "square.and.pencil")
                    }
                }
            }
        } detail: {
            // MARK: - 右侧编辑器区域
            ZStack(alignment: .topTrailing) {
                ModernDesignSystem.shared.color(.bgSurface)
                    .ignoresSafeArea()

                if let note = selectedNote ?? viewModel.selectedNote {
                    NoteEditorWrapper(note: note) { updatedNote in
                        if let index = viewModel.notes.firstIndex(where: { $0.id == updatedNote.id }) {
                            viewModel.notes[index] = updatedNote
                            if selectedNote?.id == updatedNote.id {
                                selectedNote = updatedNote
                            }
                        }
                    }
                    .id(note.id)
                    .transition(.opacity)

                    // AI 整理 + Obsidian 导出 菜单
                    aiMenu(for: note)
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                } else {
                    emptyStateView
                }
            }
        }
        .onAppear {
            viewModel.loadInitialData()
        }
        .onChange(of: searchText) { _, newValue in
             viewModel.searchText = newValue
        }
    }
    
    // MARK: - AI 菜单

    /// AI 整理 + Obsidian 导出 的下拉菜单。
    @ViewBuilder
    private func aiMenu(for note: Note) -> some View {
        Menu {
            Section("notes.ai.organize".localized) {
                Button("notes.ai.polish".localized) {
                    viewModel.selectNote(note)
                    viewModel.aiOrganize(action: .polish)
                }
                Button("notes.ai.rewrite".localized) {
                    viewModel.selectNote(note)
                    viewModel.aiOrganize(action: .rewrite)
                }
                Button("notes.ai.title_summary".localized) {
                    viewModel.selectNote(note)
                    viewModel.aiGenerateTitleAndSummary()
                }
                Button("notes.ai.auto_tag".localized) {
                    viewModel.selectNote(note)
                    viewModel.aiAutoTag()
                }
            }

            Section {
                Button("notes.ai.export_obsidian".localized) {
                    viewModel.exportToObsidian(note)
                }
            }

            if viewModel.isAIOrganizing {
                Section { Button("notes.ai.working".localized) {}.disabled(true) }
            }
        } label: {
            Image(systemName: viewModel.isAIOrganizing ? "sparkles" : "sparkles")
                .font(.system(size: 14))
                .rotationEffect(.degrees(viewModel.isAIOrganizing ? 360 : 0))
                .animation(viewModel.isAIOrganizing
                           ? .linear(duration: 1).repeatForever(autoreverses: false)
                           : .default,
                           value: viewModel.isAIOrganizing)
        }
        .menuStyle(.borderlessButton)
        .help("notes.ai.organize".localized)
    }

    // MARK: - 笔记列表
    
    private var notesList: some View {
        List(selection: $selectedNote) {
            if viewModel.filteredNotes.isEmpty {
                Text("No notes found")
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredNotes) { note in
                    NoteListRow(
                        note: note,
                        isSelected: isNoteSelected(note),
                        onSelect: { selectNote(note) },
                        onToggleFavorite: { viewModel.toggleFavorite(note) },
                        onDelete: {
                            viewModel.deleteNote(note)
                            if selectedNote?.id == note.id {
                                selectedNote = nil
                            }
                        }
                    )
                    // 适配 List 选择机制
                    .tag(note)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - 空状态
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
                .opacity(0.5)
            
            Text("Select a note or create new one")
                .font(.title2)
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
            
            Button("Create Note") {
                viewModel.createNote()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isNoteSelected(_ note: Note) -> Bool {
        return selectedNote?.id == note.id || viewModel.selectedNote?.id == note.id
    }
    
    private func selectNote(_ note: Note) {
        withAnimation(ModernDesignSystem.Motion.snap) {
            selectedNote = note
            viewModel.selectNote(note)
        }
    }
}

// MARK: - Editor Wrapper

struct NoteEditorWrapper: View {
    let note: Note
    let onSave: (Note) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor Toolbar
            HStack {
                Text(note.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(ModernDesignSystem.shared.color(.bgSurface))
            
            Divider()
            
            NoteEditorView(note: note, onUpdate: onSave)
        }
    }
}

// MARK: - Note List Row

struct NoteListRow: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : ModernDesignSystem.shared.color(.textPrimary))
                    .lineLimit(1)
                
                Text(note.content.isEmpty ? "No content" : note.content.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : ModernDesignSystem.shared.color(.textSecondary))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isHovered || isSelected || note.isFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(note.isFavorite ? .yellow : (isSelected ? .white.opacity(0.7) : .secondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(note.isFavorite ? "Unfavorite" : "Favorite", action: onToggleFavorite)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
