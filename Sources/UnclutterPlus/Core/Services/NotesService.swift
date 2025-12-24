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

    // LRU 缓存完整笔记内容（限制最多 100 个，优化内存使用）
    private let noteCache: LRUCache<UUID, Note>
    
    // 防抖动定时器
    private let debounceInterval: TimeInterval = 0.3
    
    // MARK: - Computed Properties
    
    /// 过滤和排序后的笔记索引
    var filteredNotes: [NoteIndex] {
        var filtered = noteIndexes
        
        // 搜索过滤（使用预计算的小写版本优化性能）
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter { index in
                index.titleLowercased.contains(query) ||
                index.previewTextLowercased.contains(query) ||
                index.tagsLowercased.contains { $0.contains(query) }
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
                return ascending ? lhs.titleLowercased < rhs.titleLowercased : lhs.titleLowercased > rhs.titleLowercased
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

        // 初始化 LRU 缓存（最多 100 个笔记）
        self.noteCache = LRUCache(maxSize: 100)

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
            // 使用全局错误处理器处理错误
            GlobalErrorHandler.shared.handle(
                error,
                context: "加载笔记索引",
                showAlert: true
            )
        }
    }
    
    /// 加载完整笔记内容（不设置为选中）
    func loadNote(for id: UUID) async -> Note? {
        // 检查缓存（LRU）
        if let cached = await noteCache.get(id) {
            return cached
        }

        // 从存储加载
        let result = await storage.read(id: id)
        switch result {
        case .success(let note):
            if let note = note {
                await noteCache.set(id, note)
                return note
            } else {
                return nil
            }
        case .failure(let error):
            // 静默处理错误，只记录日志
            GlobalErrorHandler.shared.handle(
                error,
                context: "加载笔记 [ID: \(id.uuidString.prefix(8))]",
                showAlert: false  // 不显示对话框，避免打扰用户
            )
            return nil
        }
    }

    /// 获取笔记（loadNote的别名，用于兼容性）
    func getNote(id: UUID) async -> Note? {
        return await loadNote(for: id)
    }

    /// 获取所有笔记（用于测试）
    func getAllNotes() async -> [Note] {
        var allNotes: [Note] = []
        for index in noteIndexes {
            if let note = await loadNote(for: index.id) {
                allNotes.append(note)
            }
        }
        return allNotes
    }

    /// 加载完整笔记内容
    func loadFullNoteContent(for id: UUID) async {
        // 检查缓存（LRU）
        if let cached = await noteCache.get(id) {
            selectedNote = cached
            editingContent = cached.content
            return
        }

        // 从存储加载
        let result = await storage.read(id: id)
        switch result {
        case .success(let note):
            if let note = note {
                await noteCache.set(id, note)
                selectedNote = note
                editingContent = note.content
            } else {
                GlobalErrorHandler.shared.handle(
                    StorageError.notFound(id),
                    context: "加载完整笔记内容",
                    showAlert: true
                )
            }
        case .failure(let error):
            GlobalErrorHandler.shared.handle(
                error,
                context: "加载完整笔记内容 [ID: \(id.uuidString.prefix(8))]",
                showAlert: true
            )
        }
    }
    
    /// 创建新笔记
    func createNote(title: String, content: String = "", tags: [String] = []) async -> Bool {
        // 验证输入
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            GlobalErrorHandler.shared.handle(
                ValidationError.emptyTitle,
                context: "创建笔记",
                showAlert: true
            )
            return false
        }

        let note = Note(
            title: trimmedTitle,
            content: content,
            tags: tags
        )

        let result = await storage.create([note])
        switch result {
        case .success:
            // 重新加载索引以获取最新的索引信息
            await loadNoteIndexes()
            selectedNote = note
            await noteCache.set(note.id, note)
            return true
        case .failure(let error):
            GlobalErrorHandler.shared.handle(
                error,
                context: "创建笔记 [标题: \(trimmedTitle)]",
                showAlert: true
            )
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
            // 更新缓存（LRU）
            await noteCache.set(note.id, updatedNote)
            if selectedNote?.id == note.id {
                selectedNote = updatedNote
            }

            // 更新索引（重新加载以确保索引是最新的）
            await loadNoteIndexes()
            return true
        case .failure(let error):
            GlobalErrorHandler.shared.handle(
                error,
                context: "更新笔记 [标题: \(note.title)]",
                showAlert: true
            )
            return false
        }
    }
    
    /// 删除笔记
    func deleteNote(_ note: Note) async -> Bool {
        let result = await storage.delete(ids: [note.id])
        switch result {
        case .success:
            // 清理缓存（LRU）
            await noteCache.remove(note.id)

            // 如果删除的是当前选中的笔记，清除选择
            if selectedNote?.id == note.id {
                selectedNote = nil
                editingContent = ""
            }

            // 重新加载索引
            await loadNoteIndexes()
            return true
        case .failure(let error):
            GlobalErrorHandler.shared.handle(
                error,
                context: "删除笔记 [标题: \(note.title)]",
                showAlert: true
            )
            return false
        }
    }
    
    /// 批量删除笔记
    func deleteNotes(_ notes: [Note]) async -> Bool {
        let ids = notes.map { $0.id }
        let result = await storage.delete(ids: ids)
        switch result {
        case .success:
            // 清理缓存（LRU）
            for note in notes {
                await noteCache.remove(note.id)
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
            GlobalErrorHandler.shared.handle(
                error,
                context: "批量删除笔记 (\(notes.count) 条)",
                showAlert: true
            )
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
            // 更新缓存（LRU）
            await noteCache.set(note.id, updatedNote)
            if selectedNote?.id == note.id {
                selectedNote = updatedNote
            }

            // 更新索引（只更新相关的索引项）
            if let index = noteIndexes.firstIndex(where: { $0.id == note.id }) {
                noteIndexes[index] = NoteIndex(from: updatedNote)
            }
            return true
        case .failure(let error):
            GlobalErrorHandler.shared.handle(
                error,
                context: "切换收藏状态 [标题: \(note.title)]",
                showAlert: true
            )
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
            // 搜索失败不应打断用户，静默记录错误
            GlobalErrorHandler.shared.handle(
                error,
                context: "搜索笔记 [关键词: \(query)]",
                showAlert: false
            )
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
            guard let self = self else { return }

            Task {
                // 从缓存获取笔记（LRU）
                guard let note = await self.noteCache.get(noteId) else { return }
                _ = await self.updateNote(note, content: content)
            }
        }

        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
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
            // 静默记录错误，返回默认统计信息
            GlobalErrorHandler.shared.handle(
                error,
                context: "获取笔记统计信息",
                showAlert: false
            )
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


