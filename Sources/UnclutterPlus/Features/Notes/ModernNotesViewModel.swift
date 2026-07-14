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

    // AI 整理状态
    @Published var isAIOrganizing = false
    @Published var aiOrganizeError: String?
    @Published var lastAIAction: String?
    
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

    // MARK: - AI 整理

    /// AI 润色/重写当前笔记正文。
    func aiOrganize(action: OrganizeAction) {
        guard let note = selectedNote else { return }
        runAI(actionLabel: label(for: action)) { service in
            let result = try await service.organize(
                content: note.content,
                instruction: OrganizeInstruction(action: action)
            )
            return result
        } apply: { result in
            self.updateSelectedNote(content: result.content)
        }
    }

    /// AI 生成标题与摘要（摘要插入正文顶部）。
    func aiGenerateTitleAndSummary() {
        guard let note = selectedNote else { return }
        runAI(actionLabel: "titleAndSummary") { service in
            try await service.organize(
                content: note.content,
                instruction: OrganizeInstruction(action: .titleAndSummary)
            )
        } apply: { result in
            var newContent = note.content
            if let summary = result.summary {
                // 在正文顶部插入摘要区块
                newContent = "> \(summary)\n\n" + newContent
            }
            self.updateSelectedNote(
                title: result.title,
                content: newContent,
                tags: result.tags.isEmpty ? nil : result.tags
            )
        }
    }

    /// AI 自动打标签。
    func aiAutoTag() {
        guard let note = selectedNote else { return }
        runAI(actionLabel: "autoTag") { service in
            try await service.organize(
                content: note.content,
                instruction: OrganizeInstruction(
                    action: .autoTag,
                    context: "已有标签：" + note.tags.joined(separator: "、")
                )
            )
        } apply: { result in
            // 合并已有标签与 AI 建议标签（去重）
            let merged = Array(Set(note.tags + result.tags)).sorted()
            self.updateSelectedNote(tags: merged)
        }
    }

    /// 批量 AI 整理多条笔记（润色正文）。
    func aiBatchOrganize(notes: [Note]) {
        guard !notes.isEmpty, AIServiceFactory.isConfigured else {
            aiOrganizeError = AIServiceFactory.isConfigured ? nil : "AI 服务未配置"
            return
        }
        guard let service = AIServiceFactory.makeService() else {
            aiOrganizeError = "无法创建 AI 服务"
            return
        }
        isAIOrganizing = true
        aiOrganizeError = nil
        Task { [weak self] in
            guard let self else { return }
            defer { self.isAIOrganizing = false }
            for note in notes {
                if Task.isCancelled { break }
                do {
                    let result = try await service.organize(
                        content: note.content,
                        instruction: OrganizeInstruction(action: .polish)
                    )
                    var updated = note
                    updated.content = result.content
                    updated.updatedAt = Date()
                    self.notesManager.updateNote(updated)
                } catch {
                    logger.error("批量整理笔记「\(note.title)」失败：\(error.localizedDescription)", category: "NotesAI")
                }
            }
            self.lastAIAction = "batchOrganize"
        }
    }

    /// 导出当前笔记到 Obsidian。
    func exportToObsidian(_ note: Note) {
        do {
            let result = try ObsidianExporter.exportNote(
                title: note.title,
                content: note.content,
                tags: note.tags,
                openInObsidian: true
            )
            logger.info("笔记已导出到 Obsidian：\(result.fileURL.path)", category: "NotesAI")
            lastAIAction = "exported"
        } catch {
            aiOrganizeError = error.localizedDescription
        }
    }

    // MARK: - AI 辅助

    /// 统一的 AI 调用包装：配置检查 + 状态管理 + 结果应用。
    private func runAI(
        actionLabel: String,
        perform: @escaping (AIService) async throws -> OrganizeResult,
        apply: @escaping (OrganizeResult) -> Void
    ) {
        guard AIServiceFactory.isConfigured else {
            aiOrganizeError = "AI 服务未配置，请在偏好设置中配置"
            return
        }
        guard let service = AIServiceFactory.makeService() else {
            aiOrganizeError = "无法创建 AI 服务"
            return
        }
        isAIOrganizing = true
        aiOrganizeError = nil
        Task { [weak self] in
            guard let self else { return }
            defer { self.isAIOrganizing = false }
            do {
                let result = try await perform(service)
                self.lastAIAction = actionLabel
                apply(result)
            } catch {
                self.aiOrganizeError = error.localizedDescription
            }
        }
    }

    private func label(for action: OrganizeAction) -> String {
        switch action {
        case .polish: return "polish"
        case .rewrite: return "rewrite"
        case .titleAndSummary: return "titleAndSummary"
        case .autoTag: return "autoTag"
        }
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

