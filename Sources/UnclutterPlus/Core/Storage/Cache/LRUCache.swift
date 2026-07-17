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
        var lastAccessTimestamp: Int = 0

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

    private var accessTimestamp: Int = 0

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
        accessTimestamp += 1
        node.lastAccessTimestamp = accessTimestamp

        // 移动到头部（最近使用）
        moveToHead(node)

        return node.value
    }

    /// 设置缓存项
    func set(_ key: Key, _ value: Value) {
        if let existing = cache[key] {
            existing.value = value
            existing.accessCount += 1
            accessTimestamp += 1
            existing.lastAccessTimestamp = accessTimestamp
            moveToHead(existing)
        } else {
            let node = Node(key: key, value: value)
            cache[key] = node
            addToHead(node)
            currentSize += 1

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
        let evictedCount = currentSize
        cache.removeAll()
        head = nil
        tail = nil
        currentSize = 0
        evictionCount += evictedCount
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
