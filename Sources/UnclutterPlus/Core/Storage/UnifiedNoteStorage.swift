import Foundation

/// 统一笔记存储实现 - 包装现有的存储系统以符合统一协议
final class UnifiedNoteStorage: UnifiedStorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex
    
    // MARK: - Properties
    
    private let shardedStorage: ShardedStorage<Note>
    private let indexDatabase: IndexDatabase?
    private let configuration: StorageConfiguration
    private let cacheManager: NoteCacheManager
    
    // MARK: - Initialization
    
    init(configuration: StorageConfiguration) {
        self.configuration = configuration
        
        // 使用分片存储作为底层实现
        self.shardedStorage = ShardedStorage<Note>(
            baseURL: configuration.baseURL.appendingPathComponent("Notes"),
            strategy: .byMonth
        )
        self.indexDatabase = nil
        
        self.cacheManager = NoteCacheManager(maxSize: 100)
    }
    
    // MARK: - UnifiedStorageProtocol Implementation
    
    func create(_ items: [Note]) async -> Result<Void, StorageOperationError> {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    // 为每个笔记计算索引信息
                    let notesWithIndexes = items.map { note in
                        let index = NoteIndex(from: note)
                        return (note: note, index: index)
                    }
                    
                    // 先创建笔记内容
                    for (note, _) in notesWithIndexes {
                        try await shardedStorage.create(note)
                    }
                    
                    // 如果有索引数据库，更新索引
                    if let indexDB = indexDatabase {
                        for (_, index) in notesWithIndexes {
                            do {
                                try await indexDB.upsertNoteIndex(index)
                            } catch {
                                print("Warning: Failed to update index for note: \(error)")
                            }
                        }
                    }
                    
                    // 缓存新创建的笔记
                    for note in items {
                        cacheManager.cache(note)
                    }
                    
                    continuation.resume(returning: .success(()))
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func read(id: UUID) async -> Result<Note?, StorageOperationError> {
        // 先检查缓存
        if let cachedNote = cacheManager.get(id: id) {
            return .success(cachedNote)
        }
        
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    if let note = try await shardedStorage.read(id: id) {
                        // 缓存读取到的笔记
                        cacheManager.cache(note)
                        continuation.resume(returning: .success(note))
                    } else {
                        continuation.resume(returning: .success(nil))
                    }
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func readBatch(ids: [UUID]) async -> Result<[Note], StorageOperationError> {
        return await withCheckedContinuation { continuation in
            Task {
                do {
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
                    continuation.resume(returning: .success(items))
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func update(_ items: [Note]) async -> Result<Void, StorageOperationError> {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    // 更新笔记内容
                    for note in items {
                        try await shardedStorage.create(note)
                    }
                    
                    // 如果有索引数据库，更新索引
                    if let indexDB = indexDatabase {
                        for note in items {
                            let index = NoteIndex(from: note)
                            do {
                                try await indexDB.upsertNoteIndex(index)
                            } catch {
                                print("Warning: Failed to update index for note: \(error)")
                            }
                        }
                    }
                    
                    // 更新缓存
                    for note in items {
                        cacheManager.cache(note)
                    }
                    
                    continuation.resume(returning: .success(()))
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func delete(ids: [UUID]) async -> Result<Void, StorageOperationError> {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    try await shardedStorage.deleteBatch(ids: ids)
                    
                    // 如果有索引数据库，删除索引
                    if let indexDB = indexDatabase {
                        for id in ids {
                            do {
                                try await indexDB.deleteNoteIndex(id: id)
                            } catch {
                                print("Warning: Failed to delete index for note: \(error)")
                            }
                        }
                    }
                    
                    // 从缓存中删除
                    for id in ids {
                        cacheManager.remove(id: id)
                    }
                    
                    continuation.resume(returning: .success(()))
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func search(query: String, limit: Int? = nil) async -> Result<[NoteIndex], StorageOperationError> {
        // 如果有索引数据库，使用全文搜索
        if let indexDB = indexDatabase {
            return await withCheckedContinuation { continuation in
                Task {
                    do {
                        let indexes = try await indexDB.searchNotes(query: query)
                        let limitedIndexes = if let limit = limit {
                            Array(indexes.prefix(limit))
                        } else {
                            indexes
                        }
                        continuation.resume(returning: .success(limitedIndexes))
                    } catch {
                        let storageError = Self.mapError(error)
                        continuation.resume(returning: .failure(storageError))
                    }
                }
            }
        }
        
        // 否则使用基础存储的搜索
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    if let searchResult = try await shardedStorage.search(query: query) as? [NoteIndex] {
                        let limitedResult = if let limit = limit {
                            Array(searchResult.prefix(limit))
                        } else {
                            searchResult
                        }
                        continuation.resume(returning: .success(limitedResult))
                    } else {
                        continuation.resume(returning: .success([]))
                    }
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func getAllIndexes(limit: Int? = nil, offset: Int? = nil) async -> Result<[NoteIndex], StorageOperationError> {
        // 如果有索引数据库，直接从数据库获取
        if let indexDB = indexDatabase {
            return await withCheckedContinuation { continuation in
                Task {
                    do {
                        let indexes = try await indexDB.getAllNoteIndexes()
                        var result = indexes
                        
                        // 应用分页
                        if let offset = offset {
                            result = Array(result.dropFirst(offset))
                        }
                        if let limit = limit {
                            result = Array(result.prefix(limit))
                        }
                        
                        continuation.resume(returning: .success(result))
                    } catch {
                        let storageError = Self.mapError(error)
                        continuation.resume(returning: .failure(storageError))
                    }
                }
            }
        }
        
        // 否则从基础存储获取
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    let allResult = try await shardedStorage.getAllIndexes()
                    var result = allResult
                    
                    // 应用分页
                    if let offset = offset {
                        result = Array(result.dropFirst(offset))
                    }
                    if let limit = limit {
                        result = Array(result.prefix(limit))
                    }
                    
                    continuation.resume(returning: .success(result))
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func filter(by predicate: @escaping (NoteIndex) -> Bool, limit: Int? = nil) async -> Result<[NoteIndex], StorageOperationError> {
        let result = await getAllIndexes()
        
        switch result {
        case .success(var indexes):
            indexes = indexes.filter(predicate)
            
            if let limit = limit {
                indexes = Array(indexes.prefix(limit))
            }
            
            return .success(indexes)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func count() async -> Result<Int, StorageOperationError> {
        // 如果有索引数据库，直接查询计数
        if let indexDB = indexDatabase {
            return await withCheckedContinuation { continuation in
                Task {
                    let count = await indexDB.getNoteCount()
                    continuation.resume(returning: .success(count))
                }
            }
        }
        
        // 否则从全量查询中计算
        let result = await getAllIndexes()
        switch result {
        case .success(let indexes):
            return .success(indexes.count)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func clear() async -> Result<Void, StorageOperationError> {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    try await shardedStorage.clear()
                    
                    // 如果有索引数据库，清空索引
                    if let indexDB = indexDatabase {
                        try await indexDB.clearNoteIndexes()
                    }
                    
                    // 清空缓存
                    cacheManager.clear()
                    
                    continuation.resume(returning: .success(()))
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    func getStatistics() async -> Result<StorageStatistics, StorageOperationError> {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    let count = try await shardedStorage.getAllIndexes().count
                    
                    // 计算存储大小
                    let storageURL = configuration.baseURL.appendingPathComponent("Notes")
                    let totalSize = Self.calculateDirectorySize(at: storageURL)
                    
                    let stats = StorageStatistics(
                        totalItems: count,
                        totalSize: totalSize,
                        cacheSize: cacheManager.count,
                        lastModified: Date(),
                        storageType: indexDatabase != nil ? .modern : .sharded
                    )
                    
                    continuation.resume(returning: .success(stats))
                } catch {
                    let storageError = Self.mapError(error)
                    continuation.resume(returning: .failure(storageError))
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private static func mapError(_ error: Error) -> StorageOperationError {
        if let storageError = error as? StorageError {
            switch storageError {
            case .notFound:
                return .itemNotFound(id: UUID()) // 泛化处理
            case .corrupted:
                return .corruptedData(location: "notes")
            case .diskFull:
                return .diskFull(requiredSpace: 0)
            case .unknown(let underlyingError):
                return .unknown(underlying: underlyingError)
            case .invalidData:
                return .corruptedData(location: "notes")
            case .permissionDenied:
                return .unauthorized(accessPath: "notes")
            }
        }
        
        // 处理其他类型错误
        if error.localizedDescription.contains("disk") || error.localizedDescription.contains("space") {
            return .diskFull(requiredSpace: 0)
        } else if error.localizedDescription.contains("corrupt") {
            return .corruptedData(location: "notes")
        } else {
            return .unknown(underlying: error)
        }
    }
    
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


