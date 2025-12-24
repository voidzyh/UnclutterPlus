import Foundation

/// 全局缓存管理器 - 负责管理系统级缓存
@MainActor
public final class GlobalCacheManager {
    public static let shared = GlobalCacheManager()

    // 缓存配置
    private var l1Capacity: Int = 10
    private var l2Capacity: Int = 100
    private var searchCapacity: Int = 50

    // 缓存统计
    private var l1Hits: Int = 0
    private var l1Misses: Int = 0
    private var l2Hits: Int = 0
    private var l2Misses: Int = 0

    private init() {
        logger.info("全局缓存管理器初始化完成", category: "Performance")
    }

    // MARK: - Public Methods

    /// 清空所有缓存
    public func clearCache() {
        l1Hits = 0
        l1Misses = 0
        l2Hits = 0
        l2Misses = 0
        logger.info("全局缓存已清空", category: "Performance")
    }

    /// 获取缓存大小
    public func getCacheSize() -> Int64 {
        // 估算缓存大小（基于条目数量）
        let totalEntries = l1Capacity + l2Capacity + searchCapacity
        return Int64(totalEntries * 1024) // 假设每个条目平均 1KB
    }

    /// 获取缓存统计信息
    public func getCacheStatistics() -> GlobalCacheStatistics {
        let totalHits = l1Hits + l2Hits
        let totalMisses = l1Misses + l2Misses
        let totalRequests = totalHits + totalMisses

        let hitRate = totalRequests > 0 ? Double(totalHits) / Double(totalRequests) : 0.0
        let missRate = totalRequests > 0 ? Double(totalMisses) / Double(totalRequests) : 0.0

        return GlobalCacheStatistics(
            totalSize: getCacheSize(),
            hitRate: hitRate,
            missRate: missRate,
            entryCount: l1Capacity + l2Capacity + searchCapacity
        )
    }

    /// 记录 L1 缓存命中
    public func recordL1Hit() {
        l1Hits += 1
    }

    /// 记录 L1 缓存未命中
    public func recordL1Miss() {
        l1Misses += 1
    }

    /// 记录 L2 缓存命中
    public func recordL2Hit() {
        l2Hits += 1
    }

    /// 记录 L2 缓存未命中
    public func recordL2Miss() {
        l2Misses += 1
    }

    /// 动态调整缓存大小
    public func adjustSize(l1: Int, l2: Int, search: Int) {
        l1Capacity = l1
        l2Capacity = l2
        searchCapacity = search
        logger.info("缓存大小已调整 - L1: \(l1), L2: \(l2), Search: \(search)", category: "Performance")
    }

    /// 根据命中率优化缓存配置
    public func optimizeBasedOnHitRate() {
        let stats = getCacheStatistics()

        if stats.hitRate < 0.5 {
            // 命中率低于 50%，增加缓存大小
            let newL1 = min(l1Capacity * 2, 50)
            let newL2 = min(l2Capacity * 2, 200)
            adjustSize(l1: newL1, l2: newL2, search: searchCapacity)
            logger.info("命中率较低 (\(String(format: "%.1f%%", stats.hitRate * 100)))，增加缓存大小", category: "Performance")
        } else if stats.hitRate > 0.9 {
            // 命中率高于 90%，可以减少缓存以节省内存
            let newL1 = max(l1Capacity / 2, 5)
            let newL2 = max(l2Capacity / 2, 50)
            adjustSize(l1: newL1, l2: newL2, search: searchCapacity)
            logger.info("命中率高 (\(String(format: "%.1f%%", stats.hitRate * 100)))，减少缓存大小", category: "Performance")
        } else {
            logger.info("命中率正常 (\(String(format: "%.1f%%", stats.hitRate * 100)))，保持当前配置", category: "Performance")
        }
    }

    /// 获取当前 L1 缓存容量
    public var currentL1Capacity: Int { l1Capacity }

    /// 获取当前 L2 缓存容量
    public var currentL2Capacity: Int { l2Capacity }

    /// 获取当前搜索缓存容量
    public var currentSearchCapacity: Int { searchCapacity }
}

/// 全局缓存统计信息
public struct GlobalCacheStatistics {
    public let totalSize: Int64
    public let hitRate: Double
    public let missRate: Double
    public let entryCount: Int

    public init(totalSize: Int64, hitRate: Double, missRate: Double, entryCount: Int) {
        self.totalSize = totalSize
        self.hitRate = hitRate
        self.missRate = missRate
        self.entryCount = entryCount
    }

    /// 格式化的描述
    public var description: String {
        """
        缓存统计:
        - 总大小: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
        - 命中率: \(String(format: "%.1f%%", hitRate * 100))
        - 未命中率: \(String(format: "%.1f%%", missRate * 100))
        - 缓存条目: \(entryCount)
        """
    }
}
