import Foundation

/// 统一笔记存储实现 - 包装现有的存储系统以符合统一协议
final class UnifiedNoteStorage: UnifiedStorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex
    
    // MARK: - Properties
    
    private let shardedStorage: ShardedStorage<Note>
    private let configuration: StorageConfiguration
    private let cacheManager: NoteCacheManager
    
    // 内存索引缓存
    private var cachedIndexes: [NoteIndex]?
    private let indexLock = NSLock()
    
    // MARK: - Initialization
    
    init(configuration: StorageConfiguration) {
        self.configuration = configuration
        
        // 使用分片存储作为底层实现
        self.shardedStorage = ShardedStorage<Note>(
            baseURL: configuration.baseURL.appendingPathComponent("Notes"),
            strategy: .byMonth
        )

        self.cacheManager = NoteCacheManager(maxSize: 100)
    }
    
    // MARK: - UnifiedStorageProtocol Implementation
    
    func create(_ items: [Note]) async throws {
        // 为每个笔记计算索引信息
        let notesWithIndexes = items.map { note in
            let index = NoteIndex(from: note)
            return (note: note, index: index)
        }
        
        // 先创建笔记内容
        for (note, _) in notesWithIndexes {
            try await shardedStorage.create(note)
        }

        // 缓存新创建的笔记
        for note in items {
            cacheManager.cache(note)
        }
        
        // 确保缓存已初始化
        indexLock.lock()
        let needInit = cachedIndexes == nil
        indexLock.unlock()
        
        if needInit {
            _ = try? await getAllIndexes()
        }
        
        // 更新内存索引缓存 (此时缓存应该已初始化)
        indexLock.lock()
        if cachedIndexes != nil {
            for note in items {
                // 检查是否已存在（避免重复添加）
                if !cachedIndexes!.contains(where: { $0.id == note.id }) {
                    let index = NoteIndex(from: note)
                    cachedIndexes?.append(index)
                }
            }
        }
        indexLock.unlock()
    }
    
    func read(id: UUID) async throws -> Note? {
        // 先检查缓存
        if let cachedNote = cacheManager.get(id: id) {
            return cachedNote
        }
        
        if let note = try await shardedStorage.read(id: id) {
            // 缓存读取到的笔记
            cacheManager.cache(note)
            return note
        } else {
            return nil
        }
    }
    
    func readBatch(ids: [UUID]) async throws -> [Note] {
        var items: [Note] = []
        for id in ids {
            if let item = try await shardedStorage.read(id: id) {
                items.append(item)
            }
        }
        // 缓存读取到的笔记
        for note in items {
            cacheManager.cache(note)
        }
        return items
    }
    
    func update(_ items: [Note]) async throws {
        // 更新笔记内容
        for note in items {
            try await shardedStorage.create(note)
        }

        // 更新缓存
        for note in items {
            cacheManager.cache(note)
        }
        
        // 更新内存索引缓存
        indexLock.lock()
        if var indexes = cachedIndexes {
            for note in items {
                if let idx = indexes.firstIndex(where: { $0.id == note.id }) {
                    indexes[idx] = NoteIndex(from: note)
                }
            }
            cachedIndexes = indexes
        }
        indexLock.unlock()
    }
    
    func delete(ids: [UUID]) async throws {
        try await shardedStorage.deleteBatch(ids: ids)

        // 从缓存中删除
        for id in ids {
            cacheManager.remove(id: id)
        }
        
        // 更新内存索引缓存
        indexLock.lock()
        if var indexes = cachedIndexes {
            indexes.removeAll { ids.contains($0.id) }
            cachedIndexes = indexes
        }
        indexLock.unlock()
    }
    
    func search(query: String, limit: Int? = nil) async throws -> [NoteIndex] {
        // 1. 使用内存索引缓存过滤
        if let indexes = cachedIndexes {
            let lowercasedQuery = query.lowercased()
            let filtered = indexes.filter { index in
                if query.isEmpty { return true }
                return index.titleLowercased.contains(lowercasedQuery) ||
                       index.previewTextLowercased.contains(lowercasedQuery) ||
                       index.tagsLowercased.contains { $0.contains(lowercasedQuery) }
            }
            if let limit = limit {
                return Array(filtered.prefix(limit))
            }
            return filtered
        }

        // 2. 如果缓存为空，触发一次全量加载以初始化缓存
        if cachedIndexes == nil {
            _ = try? await getAllIndexes(limit: nil, offset: nil)
            // 递归调用一次以使用新加载的缓存
            return try await search(query: query, limit: limit)
        }

        // 3. 最后回退到基础存储的搜索
        if let searchResult = try await shardedStorage.search(query: query) as? [NoteIndex] {
            if let limit = limit {
                return Array(searchResult.prefix(limit))
            }
            return searchResult
        }
        return []
    }
    
    func getAllIndexes(limit: Int? = nil, offset: Int? = nil) async throws -> [NoteIndex] {
        // 1. 如果内存索引缓存可用，直接使用
        if let indexes = cachedIndexes {
            var result = indexes
            if let offset = offset {
                result = Array(result.dropFirst(offset))
            }
            if let limit = limit {
                result = Array(result.prefix(limit))
            }
            return result
        }
        
        // 2. 否则从基础存储获取，并初始化缓存
        let allResult = try await shardedStorage.getAllIndexes()
        
        // 初始化缓存
        indexLock.lock()
        cachedIndexes = allResult
        indexLock.unlock()
        
        var result = allResult
        
        // 应用分页
        if let offset = offset {
            result = Array(result.dropFirst(offset))
        }
        if let limit = limit {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    func filter(by predicate: @escaping (NoteIndex) -> Bool, limit: Int? = nil) async throws -> [NoteIndex] {
        var indexes = try await getAllIndexes()
        indexes = indexes.filter(predicate)
        
        if let limit = limit {
            indexes = Array(indexes.prefix(limit))
        }
        
        return indexes
    }
    
    func count() async throws -> Int {
        // 从全量查询中计算
        let indexes = try await getAllIndexes()
        return indexes.count
    }
    
    func clear() async throws {
        try await shardedStorage.clear()

        // 清空缓存
        cacheManager.clear()
        
        // 清空内存索引缓存
        indexLock.lock()
        cachedIndexes = []
        indexLock.unlock()
    }
    
    func getStatistics() async throws -> StorageStatistics {
        let count = try await shardedStorage.getAllIndexes().count
        
        // 计算存储大小
        let storageURL = configuration.baseURL.appendingPathComponent("Notes")
        let totalSize = Self.calculateDirectorySize(at: storageURL)
        
        return StorageStatistics(
            totalItems: count,
            totalSize: totalSize,
            cacheSize: cacheManager.count,
            lastModified: Date(),
            storageType: .sharded
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return size
        }
        
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }
        
        return size
    }
}

// MARK: - Note Cache Manager

/// 笔记缓存管理器
private final class NoteCacheManager {
    private var cache: [UUID: CachedNote] = [:]
    private let maxSize: Int
    private let accessQueue = DispatchQueue(label: "note.cache.access", qos: .userInitiated)
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func cache(_ note: Note) {
        accessQueue.async {
            let cachedNote = CachedNote(
                note: note,
                lastAccessed: Date()
            )
            
            self.cache[note.id] = cachedNote
            
            // 如果缓存超过最大大小，删除最久未访问的项目
            if self.cache.count > self.maxSize {
                self.evictOldest()
            }
        }
    }
    
    func get(id: UUID) -> Note? {
        accessQueue.sync {
            guard var cachedNote = cache[id] else { return nil }
            
            // 更新访问时间
            cachedNote.lastAccessed = Date()
            cache[id] = cachedNote
            
            return cachedNote.note
        }
    }
    
    func remove(id: UUID) {
        accessQueue.async {
            self.cache.removeValue(forKey: id)
        }
    }
    
    func clear() {
        accessQueue.async {
            self.cache.removeAll()
        }
    }
    
    var count: Int {
        accessQueue.sync { cache.count }
    }
    
    private func evictOldest() {
        guard cache.count > maxSize else { return }
        
        // 找到最久未访问的项目
        let sortedByAccess = cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let itemsToRemove = sortedByAccess.prefix(cache.count - maxSize)
        
        for (id, _) in itemsToRemove {
            cache.removeValue(forKey: id)
        }
    }
}

// MARK: - Cached Note

private struct CachedNote {
    let note: Note
    var lastAccessed: Date
}

// MARK: - Compatibility Extensions

/// 扩展Note以符合StorageIndex协议
extension Note: StorageIndex {
    typealias SortKey = Date
    
    var sortKey: Date {
        modifiedAt
    }
}
