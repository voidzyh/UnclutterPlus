import Foundation
import SwiftUI
import Combine

/// 统一笔记服务 - 纯数据层：CRUD / 索引 / 搜索 / 缓存
/// UI 状态（搜索词、排序、选择、对话框等）由 ModernNotesViewModel 持有
@MainActor
final class NotesService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 所有笔记索引（轻量级，常驻内存）
    @Published private(set) var noteIndexes: [NoteIndex] = []
    
    // MARK: - Private Properties
    
    private let storage: any UnifiedStorageProtocol<Note, NoteIndex>
    
    // LRU 缓存完整笔记内容（限制最多 100 个，优化内存使用）
    private let noteCache: LRUCache<UUID, Note>
    
    /// 初始索引加载任务（变更操作需等待其完成，避免竞态覆盖）
    private var initialLoadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// 使用默认配置初始化
    convenience init() {
        self.init(storage: UnifiedNoteStorage(
            configuration: StorageConfiguration.default
        ))
    }
    
    /// 使用指定的存储初始化（支持依赖注入）
    init(storage: any UnifiedStorageProtocol<Note, NoteIndex>) {
        self.storage = storage
        
        // 初始化 LRU 缓存（最多 100 个笔记）
        self.noteCache = LRUCache(maxSize: 100)
        
        // 异步加载索引
        initialLoadTask = Task {
            await loadNoteIndexes()
        }
    }
    
    /// 等待初始索引加载完成（变更操作前调用，避免与初始加载竞态）
    private func awaitInitialLoad() async {
        await initialLoadTask?.value
    }
    
    // MARK: - Public Methods
    
    /// 加载所有笔记索引
    func loadNoteIndexes() async {
        do {
            let indexes = try await storage.getAllIndexes(limit: nil, offset: nil)
            noteIndexes = indexes
        } catch {
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
        do {
            if let note = try await storage.read(id: id) {
                await noteCache.set(id, note)
                return note
            } else {
                return nil
            }
        } catch {
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
    
    /// 创建新笔记
    func createNote(title: String, content: String = "", tags: [String] = []) async -> Bool {
        await awaitInitialLoad()

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

        do {
            try await storage.create([note])
            
            // 优化：手动更新内存索引，而不是重新加载所有索引
            // 这避免了在大数据量下的 O(N) 全量读取，将复杂度降低到 O(1)
            let newIndex = NoteIndex(from: note)
            noteIndexes.append(newIndex)
            
            await noteCache.set(note.id, note)
            return true
        } catch {
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
        await awaitInitialLoad()

        var updatedNote = note

        // 更新内容
        if let newContent = content {
            updatedNote.update(content: newContent)
        } else {
            updatedNote.updatedAt = Date()
        }

        do {
            try await storage.update([updatedNote])
            
            // 更新缓存（LRU）
            await noteCache.set(note.id, updatedNote)

            // 更新索引（重新加载以确保索引是最新的）
            await loadNoteIndexes()
            return true
        } catch {
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
        await awaitInitialLoad()

        do {
            try await storage.delete(ids: [note.id])
            
            // 清理缓存（LRU）
            await noteCache.remove(note.id)

            // 重新加载索引
            await loadNoteIndexes()
            return true
        } catch {
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
        await awaitInitialLoad()

        let ids = notes.map { $0.id }
        
        do {
            try await storage.delete(ids: ids)
            
            // 清理缓存（LRU）
            for note in notes {
                await noteCache.remove(note.id)
            }

            // 重新加载索引
            await loadNoteIndexes()
            return true
        } catch {
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
        await awaitInitialLoad()

        var updatedNote = note
        updatedNote.isFavorite.toggle()
        updatedNote.updatedAt = Date()

        do {
            try await storage.update([updatedNote])
            
            // 更新缓存（LRU）
            await noteCache.set(note.id, updatedNote)

            // 更新索引（只更新相关的索引项）
            if let index = noteIndexes.firstIndex(where: { $0.id == note.id }) {
                noteIndexes[index] = NoteIndex(from: updatedNote)
            }
            return true
        } catch {
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
        // 1. 优先使用内存中的索引进行快速搜索（如果 noteIndexes 已加载）
        if !noteIndexes.isEmpty {
            if query.isEmpty {
                return noteIndexes
            }

            let lowercasedQuery = query.lowercased()
            var matchedIDs = Set<UUID>()
            var contentCandidateIDs: [UUID] = []

            for index in noteIndexes {
                let isMetadataHit = index.titleLowercased.contains(lowercasedQuery) ||
                    index.previewTextLowercased.contains(lowercasedQuery) ||
                    index.tagsLowercased.contains(where: { $0.contains(lowercasedQuery) })

                if isMetadataHit {
                    matchedIDs.insert(index.id)
                } else {
                    contentCandidateIDs.append(index.id)
                }
            }

            if !contentCandidateIDs.isEmpty {
                do {
                    let notes = try await storage.readBatch(ids: contentCandidateIDs)
                    for note in notes where note.content.localizedCaseInsensitiveContains(query) {
                        matchedIDs.insert(note.id)
                    }
                } catch {
                    GlobalErrorHandler.shared.handle(
                        error,
                        context: "搜索笔记正文",
                        showAlert: false
                    )
                }
            }

            return noteIndexes.filter { matchedIDs.contains($0.id) }
        }
        
        // 2. 如果内存为空（极少情况），回退到存储层搜索
        do {
            return try await storage.search(query: query, limit: nil)
        } catch {
            // 搜索失败不应打断用户，静默记录错误
            GlobalErrorHandler.shared.handle(
                error,
                context: "搜索笔记 [关键词: \(query)]",
                showAlert: false
            )
            return []
        }
    }
    
    /// 获取笔记统计信息
    func getStatistics() async -> NoteStatistics {
        do {
            let stats = try await storage.getStatistics()
            return NoteStatistics(
                totalNotes: stats.totalItems,
                favoriteNotes: noteIndexes.filter { $0.isFavorited }.count,
                totalWords: noteIndexes.reduce(0) { $0 + $1.wordCount },
                averageWordsPerNote: stats.totalItems > 0 ? noteIndexes.reduce(0) { $0 + $1.wordCount } / stats.totalItems : 0,
                storageSize: stats.totalSize,
                storageType: stats.storageType.rawValue
            )
        } catch {
            // 静默记录错误，返回默认统计信息
            GlobalErrorHandler.shared.handle(
                error,
                context: "获取笔记统计信息",
                showAlert: false
            )
            return NoteStatistics(totalNotes: 0, favoriteNotes: 0, totalWords: 0, averageWordsPerNote: 0, storageSize: 0, storageType: "unknown")
        }
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
