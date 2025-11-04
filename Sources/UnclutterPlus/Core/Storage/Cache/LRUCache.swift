import Foundation

/// LRU (Least Recently Used) 缓存实现
actor LRUCache<Key: Hashable, Value> {
    // MARK: - Node Definition

    private class Node {
        var key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        var accessCount: Int = 0
        var lastAccessTime: Date = Date()

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    // MARK: - Properties

    private var cache: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    private let maxSize: Int
    private var currentSize: Int = 0

    // 统计信息
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0

    // MARK: - Initialization

    init(maxSize: Int) {
        self.maxSize = max(1, maxSize)
    }

    // MARK: - Public Methods

    /// 获取缓存项
    func get(_ key: Key) -> Value? {
        guard let node = cache[key] else {
            missCount += 1
            return nil
        }

        hitCount += 1
        node.accessCount += 1
        node.lastAccessTime = Date()

        // 移动到头部（最近使用）
        moveToHead(node)

        return node.value
    }

    /// 设置缓存项
    func set(_ key: Key, _ value: Value) {
        if let existing = cache[key] {
            // 更新现有节点
            existing.value = value
            existing.accessCount += 1
            existing.lastAccessTime = Date()
            moveToHead(existing)
        } else {
            // 创建新节点
            let node = Node(key: key, value: value)
            cache[key] = node
            addToHead(node)
            currentSize += 1

            // 超过大小限制，移除最少使用的项
            if currentSize > maxSize {
                evictLRU()
            }
        }
    }

    /// 移除缓存项
    func remove(_ key: Key) {
        guard let node = cache[key] else { return }

        removeNode(node)
        cache.removeValue(forKey: key)
        currentSize -= 1
    }

    /// 清空缓存
    func clear() {
        cache.removeAll()
        head = nil
        tail = nil
        currentSize = 0
        evictionCount += currentSize
    }

    /// 检查缓存中是否存在某个键
    func contains(_ key: Key) -> Bool {
        return cache[key] != nil
    }

    /// 获取缓存大小
    func size() -> Int {
        return currentSize
    }

    /// 获取所有键
    func keys() -> [Key] {
        return Array(cache.keys)
    }

    // MARK: - Statistics

    /// 获取缓存统计信息
    func getStatistics() -> CacheStatistics {
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0

        return CacheStatistics(
            hitCount: hitCount,
            missCount: missCount,
            hitRate: hitRate,
            evictionCount: evictionCount,
            currentSize: currentSize,
            maxSize: maxSize
        )
    }

    /// 重置统计信息
    func resetStatistics() {
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }

    // MARK: - Private Methods

    private func addToHead(_ node: Node) {
        node.prev = nil
        node.next = head

        head?.prev = node
        head = node

        if tail == nil {
            tail = node
        }
    }

    private func removeNode(_ node: Node) {
        let prev = node.prev
        let next = node.next

        if prev != nil {
            prev?.next = next
        } else {
            head = next
        }

        if next != nil {
            next?.prev = prev
        } else {
            tail = prev
        }

        node.prev = nil
        node.next = nil
    }

    private func moveToHead(_ node: Node) {
        guard node !== head else { return }

        removeNode(node)
        addToHead(node)
    }

    private func evictLRU() {
        guard let nodeToRemove = tail else { return }

        removeNode(nodeToRemove)
        cache.removeValue(forKey: nodeToRemove.key)
        currentSize -= 1
        evictionCount += 1
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    let evictionCount: Int
    let currentSize: Int
    let maxSize: Int

    var description: String {
        """
        Cache Statistics:
        - Hit Count: \(hitCount)
        - Miss Count: \(missCount)
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Eviction Count: \(evictionCount)
        - Current Size: \(currentSize)/\(maxSize)
        """
    }
}

// MARK: - Multi-Level Cache Manager

/// 多级缓存管理器
actor CacheManager {
    // L1 缓存：最近访问的完整对象（热数据）
    private let l1Cache: LRUCache<UUID, Any>

    // L2 缓存：索引信息（温数据）
    private let l2Cache: LRUCache<UUID, Any>

    // L3 缓存：搜索结果（查询缓存）
    private let searchCache: LRUCache<String, [Any]>

    init(l1Size: Int = 10, l2Size: Int = 100, searchSize: Int = 50) {
        self.l1Cache = LRUCache(maxSize: l1Size)
        self.l2Cache = LRUCache(maxSize: l2Size)
        self.searchCache = LRUCache(maxSize: searchSize)
    }

    // MARK: - Note Cache Operations

    /// 获取笔记（多级缓存查询）
    func getNote(id: UUID) async -> Note? {
        // L1: 检查完整对象缓存
        if let cached = await l1Cache.get(id) as? Note {
            print("CacheHit: L1: Note \(id)")
            return cached
        }

        // L2: 检查索引缓存
        if let index = await l2Cache.get(id) as? NoteIndex {
            print("CacheHit: L2: NoteIndex \(id)")
            // 这里需要从存储加载内容，但我们有索引信息
            return nil // 调用者需要加载完整内容
        }

        print("CacheMiss: Note \(id)")
        return nil
    }

    /// 缓存笔记
    func cacheNote(_ note: Note) async {
        await l1Cache.set(note.id, note)
        let index = NoteIndex(from: note)
        await l2Cache.set(note.id, index)
    }

    /// 缓存笔记索引
    func cacheNoteIndex(_ index: NoteIndex) async {
        await l2Cache.set(index.id, index)
    }

    /// 批量缓存笔记索引
    func cacheNoteIndexes(_ indexes: [NoteIndex]) async {
        for index in indexes {
            await l2Cache.set(index.id, index)
        }
    }

    // MARK: - Search Cache Operations

    /// 获取搜索结果
    func getSearchResults(query: String) async -> [NoteIndex]? {
        if let cached = await searchCache.get(query) as? [NoteIndex] {
            print("CacheHit: Search: \(query)")
            return cached
        }
        print("CacheMiss: Search: \(query)")
        return nil
    }

    /// 缓存搜索结果
    func cacheSearchResults(query: String, results: [NoteIndex]) async {
        await searchCache.set(query, results)
    }

    // MARK: - Cache Management

    /// 清空所有缓存
    func clearAll() async {
        await l1Cache.clear()
        await l2Cache.clear()
        await searchCache.clear()
    }

    /// 清空 L1 缓存
    func clearL1() async {
        await l1Cache.clear()
    }

    /// 清空搜索缓存
    func clearSearchCache() async {
        await searchCache.clear()
    }

    /// 获取缓存统计信息
    func getStatistics() async -> MultiLevelCacheStatistics {
        return MultiLevelCacheStatistics(
            l1: await l1Cache.getStatistics(),
            l2: await l2Cache.getStatistics(),
            search: await searchCache.getStatistics()
        )
    }

    /// 预热缓存
    func warmUp(notes: [Note]) async {
        for note in notes.prefix(10) { // L1 预热前 10 个
            await l1Cache.set(note.id, note)
        }

        for note in notes.prefix(100) { // L2 预热前 100 个索引
            let index = NoteIndex(from: note)
            await l2Cache.set(note.id, index)
        }
    }
}

// MARK: - Multi-Level Cache Statistics

struct MultiLevelCacheStatistics {
    let l1: CacheStatistics
    let l2: CacheStatistics
    let search: CacheStatistics

    var description: String {
        """
        Multi-Level Cache Statistics:

        L1 Cache (Hot Data):
        \(l1.description)

        L2 Cache (Warm Data):
        \(l2.description)

        Search Cache:
        \(search.description)
        """
    }

    var overallHitRate: Double {
        let totalHits = l1.hitCount + l2.hitCount + search.hitCount
        let totalRequests = totalHits + l1.missCount + l2.missCount + search.missCount
        return totalRequests > 0 ? Double(totalHits) / Double(totalRequests) : 0
    }
}

// MARK: - Cache-Aware Storage Wrapper

/// 带缓存的存储包装器
class CachedStorage<Storage: StorageProtocol>: StorageProtocol {
    typealias Item = Storage.Item
    typealias Index = Storage.Index

    private let storage: Storage
    private let cacheManager: CacheManager

    init(storage: Storage, cacheManager: CacheManager) {
        self.storage = storage
        self.cacheManager = cacheManager
    }

    func create(_ item: Item) async throws {
        try await storage.create(item)

        // 缓存新创建的项目
        if let note = item as? Note {
            await cacheManager.cacheNote(note)
        }
    }

    func read(id: UUID) async throws -> Item? {
        // 先查缓存
        if let note = await cacheManager.getNote(id: id) as? Item {
            return note
        }

        // 缓存未命中，从存储读取
        if let item = try await storage.read(id: id) {
            if let note = item as? Note {
                await cacheManager.cacheNote(note)
            }
            return item
        }

        return nil
    }

    func readBatch(ids: [UUID]) async throws -> [Item] {
        var results: [Item] = []
        var missingIds: [UUID] = []

        // 先从缓存获取
        for id in ids {
            if let cached = await cacheManager.getNote(id: id) as? Item {
                results.append(cached)
            } else {
                missingIds.append(id)
            }
        }

        // 批量加载缺失的项目
        if !missingIds.isEmpty {
            let loaded = try await storage.readBatch(ids: missingIds)
            results.append(contentsOf: loaded)

            // 缓存加载的项目
            for item in loaded {
                if let note = item as? Note {
                    await cacheManager.cacheNote(note)
                }
            }
        }

        return results
    }

    func update(_ item: Item) async throws {
        try await storage.update(item)

        // 更新缓存
        if let note = item as? Note {
            await cacheManager.cacheNote(note)
        }

        // 清除搜索缓存（因为内容已更改）
        await cacheManager.clearSearchCache()
    }

    func delete(id: UUID) async throws {
        try await storage.delete(id: id)

        // 从缓存中移除
        await cacheManager.clearAll() // 简单处理：清空所有缓存
    }

    func deleteBatch(ids: [UUID]) async throws {
        try await storage.deleteBatch(ids: ids)

        // 清空缓存
        await cacheManager.clearAll()
    }

    func search(query: String) async throws -> [Index] {
        // 先查缓存
        if let cached = await cacheManager.getSearchResults(query: query) as? [Index] {
            return cached
        }

        // 执行搜索
        let results = try await storage.search(query: query)

        // 缓存结果
        if let noteIndexes = results as? [NoteIndex] {
            await cacheManager.cacheSearchResults(query: query, results: noteIndexes)
        }

        return results
    }

    func list(limit: Int, offset: Int) async throws -> [Index] {
        return try await storage.list(limit: limit, offset: offset)
    }

    func getAllIndexes() async throws -> [Index] {
        let indexes = try await storage.getAllIndexes()

        // 缓存索引
        if let noteIndexes = indexes as? [NoteIndex] {
            await cacheManager.cacheNoteIndexes(noteIndexes)
        }

        return indexes
    }

    func clear() async throws {
        try await storage.clear()
        await cacheManager.clearAll()
    }
}