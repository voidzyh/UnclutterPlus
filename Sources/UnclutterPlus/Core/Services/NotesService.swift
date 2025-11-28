import Foundation
import SwiftUI
import Combine

/// 统一笔记服务 - 合并Manager和Repository功能
@MainActor
final class NotesService: ObservableObject {
    
    // MARK: - Published Properties (UI状态)
    
    /// 所有笔记索引（轻量级，常驻内存）
    @Published private(set) var noteIndexes: [NoteIndex] = []
    
    /// 当前选中的笔记（完整数据）
    @Published var selectedNote: Note?
    
    /// 搜索文本
    @Published var searchText: String = ""
    
    /// 排序选项
    @Published var sortOption: NoteSortOption = .dateModified
    
    /// 是否升序
    @Published var isAscending: Bool = false
    
    /// 视图布局模式
    @Published var viewLayout: ViewLayout = .sidebar
    
    /// 多选模式标志
    @Published var isMultiSelectMode: Bool = false
    
    /// 选中的笔记 ID 集合（多选时使用）
    @Published var selectedNoteIds: Set<UUID> = []
    
    /// 显示新笔记对话框标志
    @Published var showingNewNoteDialog: Bool = false
    
    /// 新笔记标题
    @Published var newNoteTitle: String = ""
    
    /// 新笔记标签
    @Published var newNoteTags: Set<String> = []
    
    /// 侧边栏宽度
    @Published var sidebarWidth: CGFloat = 300
    
    /// 显示标签编辑器标志
    @Published var showingTagEditor: Bool = false
    
    /// 当前正在编辑的笔记内容（缓存，避免频繁保存）
    @Published var editingContent: String = ""
    
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    private let storage: UnifiedNoteStorage
    private var cancellables = Set<AnyCancellable>()
    private var saveWorkItem: DispatchWorkItem?
    
    // 缓存完整笔记内容（避免重复加载）
    private var noteCache: [UUID: Note] = [:]
    
    // 防抖动定时器
    private let debounceInterval: TimeInterval = 0.3
    
    // MARK: - Computed Properties
    
    /// 过滤和排序后的笔记索引
    var filteredNotes: [NoteIndex] {
        var filtered = noteIndexes
        
        // 搜索过滤
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter { index in
                index.title.lowercased().contains(query) ||
                index.previewText.lowercased().contains(query) ||
                index.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        // 按排序选项排序
        filtered.sort { (lhs: NoteIndex, rhs: NoteIndex) in
            let ascending = isAscending
            
            switch sortOption {
            case .dateModified:
                return ascending ? lhs.modifiedAt < rhs.modifiedAt : lhs.modifiedAt > rhs.modifiedAt
            case .dateCreated:
                return ascending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
            case .title:
                return ascending ? lhs.title.lowercased() < rhs.title.lowercased() : lhs.title.lowercased() > rhs.title.lowercased()
            case .tagCount:
                return ascending ? lhs.tags.count < rhs.tags.count : lhs.tags.count > rhs.tags.count
            }
        }
        
        return filtered
    }
    
    /// 所有标签（去重）
    var allTags: Set<String> {
        var tags: Set<String> = []
        for index in noteIndexes {
            tags.formUnion(index.tags)
        }
        return tags
    }
    
    /// 收藏笔记数量
    var favoriteNotesCount: Int {
        noteIndexes.filter { $0.isFavorited }.count
    }
    
    /// 总笔记数量
    var totalNotesCount: Int {
        noteIndexes.count
    }
    
    // MARK: - Initialization
    
    init(storage: UnifiedNoteStorage? = nil) {
        // 使用提供的存储或创建默认存储
        if let storage = storage {
            self.storage = storage
        } else {
            self.storage = UnifiedNoteStorage(
                configuration: StorageConfiguration.default
            )
        }
        
        setupBindings()
        setupObservers()
        
        // 异步加载索引
        Task {
            await loadNoteIndexes()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // 监听搜索和排序变化，使用防抖动
        Publishers.CombineLatest4(
            $searchText,
            $sortOption,
            $isAscending,
            $noteIndexes
        )
        .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        
        // 监听选中笔记变化，加载完整内容
        $selectedNote
            .filter { $0 != nil }
            .sink { [weak self] note in
                Task {
                    if let noteId = note?.id {
                        await self?.loadFullNoteContent(for: noteId)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupObservers() {
        // 监听内容变化，自动保存
        $editingContent
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] content in
                guard let noteId = self?.selectedNote?.id else { return }
                self?.autoSaveContent(content, for: noteId)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 加载所有笔记索引
    func loadNoteIndexes() async {
        isLoading = true
        defer { isLoading = false }
        
        let result = await storage.getAllIndexes()
        switch result {
        case .success(let indexes):
            noteIndexes = indexes
        case .failure(let error):
            print("❌ Failed to load note indexes: \(error)")
            // 显示用户友好的错误提示
            await showErrorAlert("加载笔记失败", error.localizedDescription)
        }
    }
    
    /// 加载完整笔记内容（不设置为选中）
    func loadNote(for id: UUID) async -> Note? {
        // 检查缓存
        if let cached = noteCache[id] {
            return cached
        }
        
        // 从存储加载
        let result = await storage.read(id: id)
        switch result {
        case .success(let note):
            if let note = note {
                noteCache[id] = note
                return note
            } else {
                return nil
            }
        case .failure(let error):
            print("❌ Failed to load note \(id): \(error)")
            return nil
        }
    }
    
    /// 加载完整笔记内容
    func loadFullNoteContent(for id: UUID) async {
        // 检查缓存
        if let cached = noteCache[id] {
            selectedNote = cached
            editingContent = cached.content
            return
        }
        
        // 从存储加载
        let result = await storage.read(id: id)
        switch result {
        case .success(let note):
            if let note = note {
                noteCache[id] = note
                selectedNote = note
                editingContent = note.content
            } else {
                await showErrorAlert("加载失败", "笔记内容不存在")
            }
        case .failure(let error):
            print("❌ Failed to load note \(id): \(error)")
            await showErrorAlert("加载失败", error.localizedDescription)
        }
    }
    
    /// 创建新笔记
    func createNote(title: String, content: String = "", tags: [String] = []) async -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await showErrorAlert("创建失败", "笔记标题不能为空")
            return false
        }
        
        let note = Note(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content,
            tags: tags
        )
        
        let result = await storage.create([note])
        switch result {
        case .success:
            // 重新加载索引以获取最新的索引信息
            await loadNoteIndexes()
            selectedNote = note
            noteCache[note.id] = note
            return true
        case .failure(let error):
            print("❌ Failed to create note: \(error)")
            await showErrorAlert("创建失败", error.localizedDescription)
            return false
        }
    }
    
    /// 更新笔记
    func updateNote(_ note: Note, content: String? = nil) async -> Bool {
        var updatedNote = note
        
        // 更新内容
        if let newContent = content {
            updatedNote.content = newContent

        }
        
        // 更新时间戳
        updatedNote.updatedAt = Date()
        
        let result = await storage.update([updatedNote])
        switch result {
        case .success:
            // 更新缓存
            noteCache[note.id] = updatedNote
            if selectedNote?.id == note.id {
                selectedNote = updatedNote
            }
            
            // 更新索引（重新加载以确保索引是最新的）
            await loadNoteIndexes()
            return true
        case .failure(let error):
            print("❌ Failed to update note: \(error)")
            await showErrorAlert("保存失败", error.localizedDescription)
            return false
        }
    }
    
    /// 删除笔记
    func deleteNote(_ note: Note) async -> Bool {
        let result = await storage.delete(ids: [note.id])
        switch result {
        case .success:
            // 清理缓存
            noteCache.removeValue(forKey: note.id)
            
            // 如果删除的是当前选中的笔记，清除选择
            if selectedNote?.id == note.id {
                selectedNote = nil
                editingContent = ""
            }
            
            // 重新加载索引
            await loadNoteIndexes()
            return true
        case .failure(let error):
            print("❌ Failed to delete note: \(error)")
            await showErrorAlert("删除失败", error.localizedDescription)
            return false
        }
    }
    
    /// 批量删除笔记
    func deleteNotes(_ notes: [Note]) async -> Bool {
        let ids = notes.map { $0.id }
        let result = await storage.delete(ids: ids)
        switch result {
        case .success:
            // 清理缓存
            for note in notes {
                noteCache.removeValue(forKey: note.id)
            }
            
            // 如果删除的是当前选中的笔记，清除选择
            if let selectedNoteId = selectedNote?.id, ids.contains(selectedNoteId) {
                selectedNote = nil
                editingContent = ""
            }
            
            // 重新加载索引
            await loadNoteIndexes()
            return true
        case .failure(let error):
            print("❌ Failed to delete notes: \(error)")
            await showErrorAlert("批量删除失败", error.localizedDescription)
            return false
        }
    }
    
    /// 切换收藏状态
    func toggleFavorite(_ note: Note) async -> Bool {
        var updatedNote = note
        updatedNote.isFavorite.toggle()
        updatedNote.updatedAt = Date()
        
        let result = await storage.update([updatedNote])
        switch result {
        case .success:
            noteCache[note.id] = updatedNote
            if selectedNote?.id == note.id {
                selectedNote = updatedNote
            }
            
            // 更新索引（只更新相关的索引项）
            if let index = noteIndexes.firstIndex(where: { $0.id == note.id }) {
                noteIndexes[index] = NoteIndex(from: updatedNote)
            }
            return true
        case .failure(let error):
            print("❌ Failed to toggle favorite: \(error)")
            await showErrorAlert("操作失败", error.localizedDescription)
            return false
        }
    }
    
    /// 搜索笔记
    func searchNotes(query: String) async -> [NoteIndex] {
        let result = await storage.search(query: query, limit: nil)
        switch result {
        case .success(let indexes):
            return indexes
        case .failure(let error):
            print("❌ Failed to search notes: \(error)")
            await showErrorAlert("搜索失败", error.localizedDescription)
            return []
        }
    }
    
    /// 清空搜索
    func clearSearch() {
        searchText = ""
    }
    
    /// 重置筛选和排序
    func resetFilters() {
        searchText = ""
        sortOption = .dateModified
        isAscending = false
    }
    
    // MARK: - Private Methods
    
    /// 自动保存内容（防抖动）
    private func autoSaveContent(_ content: String, for noteId: UUID) {
        // 取消之前的保存任务
        saveWorkItem?.cancel()
        
        // 创建新的保存任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  let note = self.noteCache[noteId] else { return }
            
            Task {
                await self.updateNote(note, content: content)
            }
        }
        
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    /// 显示错误提示（简化版）
    private func showErrorAlert(_ title: String, _ message: String) async {
        // 在实际应用中，这里应该显示用户界面错误提示
        // 现在使用print作为占位符
        print("🚨 \(title): \(message)")
    }
    
    /// 获取笔记统计信息
    func getStatistics() async -> NoteStatistics {
        let result = await storage.getStatistics()
        switch result {
        case .success(let stats):
            return NoteStatistics(
                totalNotes: stats.totalItems,
                favoriteNotes: noteIndexes.filter { $0.isFavorited }.count,
                totalWords: noteIndexes.reduce(0) { $0 + $1.wordCount },
                averageWordsPerNote: stats.totalItems > 0 ? noteIndexes.reduce(0) { $0 + $1.wordCount } / stats.totalItems : 0,
                storageSize: stats.totalSize,
                storageType: stats.storageType.rawValue
            )
        case .failure(let error):
            print("❌ Failed to get statistics: \(error)")
            return NoteStatistics(totalNotes: 0, favoriteNotes: 0, totalWords: 0, averageWordsPerNote: 0, storageSize: 0, storageType: "unknown")
        }
    }
    
    deinit {
        // 取消所有待处理的保存任务
        saveWorkItem?.cancel()
        cancellables.removeAll()
    }
}

// MARK: - 笔记统计信息

struct NoteStatistics: Codable {
    let totalNotes: Int
    let favoriteNotes: Int
    let totalWords: Int
    let averageWordsPerNote: Int
    let storageSize: Int64
    let storageType: String
    
    var formattedStorageSize: String {
        ByteCountFormatter.string(fromByteCount: storageSize, countStyle: .file)
    }
    
    var description: String {
        """
        笔记统计:
        - 总笔记: \(totalNotes)
        - 收藏笔记: \(favoriteNotes)
        - 总字数: \(totalWords)
        - 平均字数: \(averageWordsPerNote)
        - 存储大小: \(formattedStorageSize)
        - 存储类型: \(storageType)
        """
    }
}


