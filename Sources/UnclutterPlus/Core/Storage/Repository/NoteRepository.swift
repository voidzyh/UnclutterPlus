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
    @Published var sortOption: NoteSortOption = .dateModified

    /// 是否升序
    @Published var isAscending: Bool = false

    // MARK: - Private Properties

    private let storage: any UnifiedStorageProtocol<Note, NoteIndex>
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
                index.previewText.lowercased().contains(searchLower) ||
                index.tags.contains { $0.lowercased().contains(searchLower) }
            }
        }

        // 排序
        filtered.sort { first, second in
            // 收藏的笔记总是在前面
            if first.isFavorited && !second.isFavorited {
                return true
            } else if !first.isFavorited && second.isFavorited {
                return false
            }

            let result: Bool
            switch sortOption {
            case .dateModified:
                result = first.modifiedAt > second.modifiedAt
            case .dateCreated:
                result = first.createdAt > second.createdAt
            case .title:
                result = first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            case .tagCount:
                result = first.tags.count > second.tags.count
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
        self.storage = StorageFactory.createModernNoteStorage()
        
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
            let indexes = try await storage.getAllIndexes(limit: nil, offset: nil)
            await MainActor.run {
                self.noteIndexes = indexes
            }
        } catch {
            logger.error("Failed to load note indexes: \(error)", category: "Service")
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
            logger.error("Failed to load note \(id): \(error)", category: "Service")
        }

        return nil
    }

    /// 创建新笔记
    func createNote(title: String, content: String = "", tags: Set<String> = []) async -> Note? {
        let note = Note(title: title, content: content, tags: Array(tags))

        do {
            try await storage.create([note])
            let index = NoteIndex(from: note)

            await MainActor.run {
                self.noteIndexes.insert(index, at: 0)
                self.noteCache[note.id] = note
            }

            return note
        } catch {
            logger.error("Failed to create note: \(error)", category: "Service")
            return nil
        }
    }

    /// 更新笔记
    func updateNote(_ note: Note) async {
        var updatedNote = note
        updatedNote.updatedAt = Date()
        // 更新缓存值会在保存时自动处理

        do {
            try await storage.update([updatedNote])
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
            logger.error("Failed to update note: \(error)", category: "Service")
        }
    }

    /// 删除笔记
    func deleteNote(_ note: Note) async {
        do {
            try await storage.delete(ids: [note.id])

            await MainActor.run {
                self.noteIndexes.removeAll { $0.id == note.id }
                self.noteCache.removeValue(forKey: note.id)
                if self.selectedNote?.id == note.id {
                    self.selectedNote = nil
                }
            }
        } catch {
            logger.error("Failed to delete note: \(error)", category: "Service")
        }
    }

    /// 批量删除笔记
    func deleteNotes(_ notes: [Note]) async {
        let ids = notes.map { $0.id }

        do {
            try await storage.delete(ids: ids)

            await MainActor.run {
                self.noteIndexes.removeAll { ids.contains($0.id) }
                ids.forEach { self.noteCache.removeValue(forKey: $0) }
                if let selectedId = self.selectedNote?.id, ids.contains(selectedId) {
                    self.selectedNote = nil
                }
            }
        } catch {
            logger.error("Failed to delete notes: \(error)", category: "Service")
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
            return try await storage.search(query: query, limit: nil)
        } catch {
            logger.error("Failed to search notes: \(error)", category: "Service")
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
            logger.error("Failed to clear all notes: \(error)", category: "Service")
        }
    }
}
