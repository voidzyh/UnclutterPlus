import Foundation
import Combine

/// 笔记数据仓库 - 统一的数据访问层
@MainActor
class NoteRepository: ObservableObject {
    // MARK: - Published Properties

    /// 所有笔记索引（轻量级，常驻内存）
    @Published private(set) var noteIndexes: [NoteIndex] = []

    /// 当前选中的笔记（完整数据）
    @Published var selectedNote: Note?

    /// 搜索文本
    @Published var searchText: String = ""

    /// 排序选项
    @Published var sortOption: NotesSortOption = .modified

    /// 是否升序
    @Published var isAscending: Bool = false

    // MARK: - Private Properties

    private let storage: ModernNoteStorage
    private let config = StorageConfiguration.default
    private var cancellables = Set<AnyCancellable>()

    // 缓存完整笔记内容（避免重复加载）
    private var noteCache: [UUID: Note] = [:]

    // MARK: - Computed Properties

    /// 过滤和排序后的笔记索引
    var filteredIndexes: [NoteIndex] {
        var filtered = noteIndexes

        // 搜索过滤
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { index in
                index.title.lowercased().contains(searchLower) ||
                index.preview.lowercased().contains(searchLower) ||
                index.tags.contains { $0.lowercased().contains(searchLower) }
            }
        }

        // 排序
        filtered.sort { first, second in
            // 收藏的笔记总是在前面
            if first.isFavorite && !second.isFavorite {
                return true
            } else if !first.isFavorite && second.isFavorite {
                return false
            }

            let result: Bool
            switch sortOption {
            case .modified:
                result = first.modifiedAt > second.modifiedAt
            case .created:
                result = first.createdAt > second.createdAt
            case .title:
                result = first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            case .wordCount:
                result = first.wordCount > second.wordCount
            }

            return isAscending ? !result : result
        }

        return filtered
    }

    /// 所有标签
    var allTags: Set<String> {
        Set(noteIndexes.flatMap { $0.tags })
    }

    // MARK: - Initialization

    init() {
        // 使用 StorageFactory 创建现代化存储
        // We need to cast it to ModernNoteStorage
        if let modernStorage = StorageFactory.createModernNoteStorage() as? ModernNoteStorage {
            self.storage = modernStorage
        } else {
            // Fallback - create directly
            do {
                self.storage = try ModernNoteStorage(configuration: StorageConfiguration.default)
            } catch {
                fatalError("Failed to initialize storage: \(error)")
            }
        }
        setupBindings()

        Task {
            await loadIndexes()
        }
    }

    private func setupBindings() {
        // 监听搜索和排序变化
        Publishers.CombineLatest3($searchText, $sortOption, $isAscending)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 加载所有笔记索引
    func loadIndexes() async {
        do {
            let indexes = try await storage.getAllIndexes()
            await MainActor.run {
                self.noteIndexes = indexes
            }
        } catch {
            print("❌ Failed to load note indexes: \(error)")
        }
    }

    /// 获取完整笔记内容
    func getNote(id: UUID) async -> Note? {
        // 检查缓存
        if let cached = noteCache[id] {
            return cached
        }

        // 从存储加载
        do {
            if let note = try await storage.read(id: id) {
                noteCache[id] = note
                return note
            }
        } catch {
            print("❌ Failed to load note \(id): \(error)")
        }

        return nil
    }

    /// 创建新笔记
    func createNote(title: String, content: String = "", tags: Set<String> = []) async -> Note? {
        let note = Note(title: title, content: content, tags: tags)

        do {
            try await storage.create(note)
            let index = NoteIndex(from: note)

            await MainActor.run {
                self.noteIndexes.insert(index, at: 0)
                self.noteCache[note.id] = note
            }

            return note
        } catch {
            print("❌ Failed to create note: \(error)")
            return nil
        }
    }

    /// 更新笔记
    func updateNote(_ note: Note) async {
        var updatedNote = note
        updatedNote.modifiedAt = Date()
        updatedNote.updateCachedValues()

        do {
            try await storage.update(updatedNote)
            let newIndex = NoteIndex(from: updatedNote)

            await MainActor.run {
                // 更新索引
                if let index = self.noteIndexes.firstIndex(where: { $0.id == note.id }) {
                    self.noteIndexes[index] = newIndex
                }
                // 更新缓存
                self.noteCache[note.id] = updatedNote
            }
        } catch {
            print("❌ Failed to update note: \(error)")
        }
    }

    /// 删除笔记
    func deleteNote(_ note: Note) async {
        do {
            try await storage.delete(id: note.id)

            await MainActor.run {
                self.noteIndexes.removeAll { $0.id == note.id }
                self.noteCache.removeValue(forKey: note.id)
                if self.selectedNote?.id == note.id {
                    self.selectedNote = nil
                }
            }
        } catch {
            print("❌ Failed to delete note: \(error)")
        }
    }

    /// 批量删除笔记
    func deleteNotes(_ notes: [Note]) async {
        let ids = notes.map { $0.id }

        do {
            try await storage.deleteBatch(ids: ids)

            await MainActor.run {
                self.noteIndexes.removeAll { ids.contains($0.id) }
                ids.forEach { self.noteCache.removeValue(forKey: $0) }
                if let selectedId = self.selectedNote?.id, ids.contains(selectedId) {
                    self.selectedNote = nil
                }
            }
        } catch {
            print("❌ Failed to delete notes: \(error)")
        }
    }

    /// 切换收藏状态
    func toggleFavorite(_ note: Note) async {
        var updatedNote = note
        updatedNote.isFavorite.toggle()
        await updateNote(updatedNote)
    }

    /// 搜索笔记
    func searchNotes(query: String) async -> [NoteIndex] {
        do {
            return try await storage.search(query: query)
        } catch {
            print("❌ Failed to search notes: \(error)")
            return []
        }
    }

    /// 清空所有笔记
    func clearAll() async {
        do {
            try await storage.clear()

            await MainActor.run {
                self.noteIndexes.removeAll()
                self.noteCache.removeAll()
                self.selectedNote = nil
            }
        } catch {
            print("❌ Failed to clear all notes: \(error)")
        }
    }
}

// MARK: - Temporary Storage Implementation

/// 临时存储实现（用于测试，后续会被真实实现替换）
private class TemporaryNoteStorage: StorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex

    private var notes: [UUID: Note] = [:]
    private let queue = DispatchQueue(label: "temp.storage", attributes: .concurrent)

    init(configuration: StorageConfiguration) {}

    func create(_ item: Note) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                self.notes[item.id] = item
                continuation.resume()
            }
        }
    }

    func read(id: UUID) async throws -> Note? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.notes[id])
            }
        }
    }

    func readBatch(ids: [UUID]) async throws -> [Note] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let items = ids.compactMap { self.notes[$0] }
                continuation.resume(returning: items)
            }
        }
    }

    func update(_ item: Note) async throws {
        try await create(item)
    }

    func delete(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                self.notes.removeValue(forKey: id)
                continuation.resume()
            }
        }
    }

    func deleteBatch(ids: [UUID]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                ids.forEach { self.notes.removeValue(forKey: $0) }
                continuation.resume()
            }
        }
    }

    func search(query: String) async throws -> [NoteIndex] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let filtered = self.notes.values.filter { note in
                    note.title.localizedCaseInsensitiveContains(query) ||
                    note.content.localizedCaseInsensitiveContains(query)
                }
                let indexes = filtered.map { NoteIndex(from: $0) }
                continuation.resume(returning: indexes)
            }
        }
    }

    func list(limit: Int, offset: Int) async throws -> [NoteIndex] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let allNotes = Array(self.notes.values)
                    .sorted { $0.modifiedAt > $1.modifiedAt }
                let page = Array(allNotes.dropFirst(offset).prefix(limit))
                let indexes = page.map { NoteIndex(from: $0) }
                continuation.resume(returning: indexes)
            }
        }
    }

    func getAllIndexes() async throws -> [NoteIndex] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let indexes = self.notes.values.map { NoteIndex(from: $0) }
                continuation.resume(returning: indexes)
            }
        }
    }

    func clear() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                self.notes.removeAll()
                continuation.resume()
            }
        }
    }
}