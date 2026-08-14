import Foundation

/// 统一笔记存储实现 - 包装现有的存储系统以符合统一协议
final class UnifiedNoteStorage: UnifiedStorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex
    
    // MARK: - Properties
    
    private let shardedStorage: ShardedStorage<Note>
    private let configuration: StorageConfiguration
    
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
        return try await shardedStorage.read(id: id)
    }
    
    func readBatch(ids: [UUID]) async throws -> [Note] {
        var items: [Note] = []
        for id in ids {
            if let item = try await shardedStorage.read(id: id) {
                items.append(item)
            }
        }
        return items
    }
    
    func update(_ items: [Note]) async throws {
        // 更新笔记内容
        for note in items {
            try await shardedStorage.create(note)
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
            cacheSize: 0,
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

// MARK: - Compatibility Extensions

/// 扩展Note以符合StorageIndex协议
extension Note: StorageIndex {
    typealias SortKey = Date
    
    var sortKey: Date {
        modifiedAt
    }
}
