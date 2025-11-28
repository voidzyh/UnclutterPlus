import Foundation
import Combine
import SwiftUI
import MarkdownUI

/// 现代化笔记视图模型 - 改进的交互体验和流畅动画
@MainActor
final class ModernNotesViewModel: ObservableObject {
    // MARK: - 发布属性
    
    @Published var notes: [Note] = []
    @Published var filteredNotes: [Note] = []
    @Published var selectedNote: Note?
    @Published var searchText: String = "" {
        didSet {
            debouncedSearch.send(searchText)
        }
    }
    
    @Published var isSearching = false
    @Published var sortOption: NoteSortOption = .dateModified
    @Published var isAscending = false
    @Published var showingNewNoteDialog = false
    @Published var newNoteTitle = ""
    @Published var newNoteTags: Set<String> = []
    
    // 统计信息
    @Published var statistics: NoteStatistics?
    
    // 状态管理
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: NotesError?
    
    // 多选模式
    @Published var isMultiSelectMode = false
    @Published var selectedNoteIds: Set<UUID> = []
    
    // 视图模式
    @Published var viewLayout: ViewLayout = .sidebar
    @Published var sidebarWidth: CGFloat = 300
    
    // MARK: - 私有属性
    
    private let notesManager = NotesManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let debouncedSearch = PassthroughSubject<String, Never>()
    
    // 搜索防抖
    private let searchDebounceInterval: TimeInterval = 0.3
    
    // 性能优化
    private var searchTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    
    // MARK: - 初始化
    
    init() {
        setupBindings()
        setupDebouncedSearch()
        loadInitialData()
    }
    
    // MARK: - 私有方法
    
    private func setupBindings() {
        notesManager.$notes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notes in
                self?.notes = notes
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    private func setupDebouncedSearch() {
        debouncedSearch
            .debounce(for: .seconds(searchDebounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    func loadInitialData() {
        Task {
            await refresh()
        }
    }
    
    private func applyFilters() {
        filterTask?.cancel()
        filterTask = Task { @MainActor in
            var items = notes
            
            // 应用搜索过滤
            if !searchText.isEmpty {
                items = items.filter { note in
                    note.title.localizedCaseInsensitiveContains(searchText) ||
                    note.content.localizedCaseInsensitiveContains(searchText) ||
                    note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
            
            // 应用排序
            items = sortNotes(items)
            
            // 更新过滤结果
            filteredNotes = items
            
            // 更新统计信息
            updateStatistics()
        }
    }
    
    private func updateStatistics() {
        let totalNotes = notes.count
        let favoriteNotes = notes.filter { $0.isFavorite }.count
        let totalWords = notes.reduce(0) { $0 + $1.wordCount }
        let averageWords = totalNotes > 0 ? totalWords / totalNotes : 0
        let storageSize = Int64(totalWords * 8) // 粗略估计
        
        statistics = NoteStatistics(
            totalNotes: totalNotes,
            favoriteNotes: favoriteNotes,
            totalWords: totalWords,
            averageWordsPerNote: averageWords,
            storageSize: storageSize,
            storageType: "Local"
        )
    }
    
    // MARK: - 公共方法
    
    func createNote() {
        guard !newNoteTitle.isEmpty else { return }
        
        let note = Note(
            title: newNoteTitle,
            content: "",
            tags: Array(newNoteTags),
            isPinned: false,
            isFavorite: false
        )
        
        notesManager.createNote(
            title: note.title,
            content: note.content,
            tags: note.tags
        )
        
        // 重置新笔记状态
        newNoteTitle = ""
        newNoteTags.removeAll()
        showingNewNoteDialog = false
    }
    
    func updateSelectedNote(title: String? = nil, content: String? = nil, tags: [String]? = nil) {
        guard let note = selectedNote else { return }
        
        isSaving = true
        
        saveTask?.cancel()
        saveTask = Task {
            var updatedNote = note
            if let title = title {
                updatedNote.title = title
            }
            if let content = content {
                updatedNote.content = content
            }
            if let tags = tags {
                updatedNote.tags = tags
            }
            updatedNote.updatedAt = Date()
            
            notesManager.updateNote(updatedNote)
            await MainActor.run {
                selectedNote = updatedNote
                self.isSaving = false
            }
        }
    }
    
    func deleteNote(_ note: Note) {
        notesManager.deleteNote(note)
        if selectedNote?.id == note.id {
            selectedNote = nil
        }
    }
    
    func togglePin(_ note: Note) {
        notesManager.togglePin(note)
    }
    
    func toggleFavorite(_ note: Note) {
        notesManager.toggleFavorite(note)
    }
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        await notesManager.refresh()
    }
    
    func clearSearch() {
        searchText = ""
    }
    
    func selectNote(_ note: Note) {
        selectedNote = note
    }
    
    func deselectNote() {
        selectedNote = nil
    }
    
    func toggleSelection(_ note: Note) {
        if selectedNoteIds.contains(note.id) {
            selectedNoteIds.remove(note.id)
        } else {
            selectedNoteIds.insert(note.id)
        }
    }
    
    func deleteSelectedNotes() {
        for noteId in selectedNoteIds {
            if let note = notes.first(where: { $0.id == noteId }) {
                notesManager.deleteNote(note)
            }
        }
        selectedNoteIds.removeAll()
        isMultiSelectMode = false
    }
    
    func selectAllNotes() {
        selectedNoteIds = Set(notes.map { $0.id })
    }
    
    func deselectAllNotes() {
        selectedNoteIds.removeAll()
    }
    
    // MARK: - 排序和过滤
    
    private func sortNotes(_ items: [Note]) -> [Note] {
        var sortedItems = items
        
        switch sortOption {
        case .dateCreated:
            sortedItems.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            sortedItems.sort { $0.updatedAt > $1.updatedAt }
        case .title:
            sortedItems.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .tagCount:
            sortedItems.sort { $0.tags.count > $1.tags.count }
        }
        
        if !isAscending {
            sortedItems.reverse()
        }
        
        return sortedItems
    }
    
    // MARK: - 类型切换方法
    
    func setSortOption(_ option: NoteSortOption) {
        sortOption = option
    }
    
    func toggleSortOrder() {
        isAscending.toggle()
    }
    
    func setViewLayout(_ layout: ViewLayout) {
        viewLayout = layout
    }
    
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            selectedNoteIds.removeAll()
        }
    }
}

// MARK: - 辅助类型

