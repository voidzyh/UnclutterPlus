import Foundation

/// 统一笔记存储实现 - 包装分片存储以符合统一协议（actor 并发模型）
///
/// 内存索引缓存由 actor 隔离，无需 NSLock；
/// 首次访问时从分片存储全量加载索引并常驻内存（笔记规模可控）。
actor UnifiedNoteStorage: UnifiedStorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex

    // MARK: - Properties

    private let shardedStorage: ShardedStorage<Note>
    private let configuration: StorageConfiguration

    // 内存索引缓存（actor 隔离）
    private var cachedIndexes: [NoteIndex]?

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
        // 先创建笔记内容
        for note in items {
            try await shardedStorage.create(note)
        }

        // 确保索引缓存已初始化（首次访问时加载）
        if cachedIndexes == nil {
            _ = try? await getAllIndexes()
        }

        // 追加新索引（防重复；getAllIndexes 抛错时以空数组兜底）
        if cachedIndexes == nil {
            cachedIndexes = []
        }
        for note in items {
            let exists = cachedIndexes?.contains(where: { $0.id == note.id }) ?? false
            if !exists {
                cachedIndexes?.append(NoteIndex(from: note))
            }
        }
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
        if var indexes = cachedIndexes {
            for note in items {
                if let idx = indexes.firstIndex(where: { $0.id == note.id }) {
                    indexes[idx] = NoteIndex(from: note)
                }
            }
            cachedIndexes = indexes
        }
    }

    func delete(ids: [UUID]) async throws {
        try await shardedStorage.deleteBatch(ids: ids)

        // 更新内存索引缓存
        if var indexes = cachedIndexes {
            indexes.removeAll { ids.contains($0.id) }
            cachedIndexes = indexes
        }
    }

    func search(query: String, limit: Int? = nil) async throws -> [NoteIndex] {
        // 使用内存索引缓存过滤（未初始化时先加载）
        let indexes = try await getAllIndexes()

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
        cachedIndexes = allResult

        var result = allResult
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
        cachedIndexes = []
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
