import Foundation
import Combine

// MARK: - 缓存项协议

/// 缓存项协议
protocol CacheItem: Identifiable {
    associatedtype Key: Hashable
    associatedtype Value
    
    var key: Key { get }
    var value: Value { get }
    var lastAccessed: Date { get set }
    var createdAt: Date { get }
    var accessCount: Int { get set }
    var size: Int { get } // 缓存项大小（字节）
}

// MARK: - 缓存统计信息

/// 缓存统计信息
struct CacheStatistics: Sendable {
    let totalItems: Int
    let totalSize: Int64
    let hitRate: Double
    let missRate: Double
    let averageAccessTime: TimeInterval
    let lastCleanup: Date
    let cacheType: String
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var description: String {
        """
        缓存统计:
        - 项目总数: \(totalItems)
        - 总大小: \(formattedSize)
        - 命中率: \(String(format: "%.2f%%", hitRate * 100))
        - 失误率: \(String(format: "%.2f%%", missRate * 100))
        - 平均访问时间: \(String(format: "%.3fms", averageAccessTime * 1000))
        - 最后清理: \(lastCleanup)
        - 缓存类型: \(cacheType)
        """
    }
}

// MARK: - 智能缓存管理器

/// 智能缓存管理器 - 支持多级缓存、LRU策略和自动清理
@MainActor
final class IntelligentCacheManager<Key: Hashable, Value: Sendable>: ObservableObject {
    // MARK: - Properties
    
    // 配置
    private let config: CacheConfiguration
    private let cacheName: String
    
    // 存储
    private var primaryCache: [Key: CacheEntry] = [:] // L1缓存 - 内存
    private var secondaryCache: [Key: CacheEntry] = [:] // L2缓存 - 磁盘（未来扩展）
    private var accessQueue = DispatchQueue(label: "cache.access", qos: .userInitiated)
    private var cleanupQueue = DispatchQueue(label: "cache.cleanup", qos: .utility)
    
    // 统计
    private var hitCount: Int64 = 0
    private var missCount: Int64 = 0
    private var totalAccessTime: TimeInterval = 0
    private var accessCount: Int64 = 0
    
    // 定时器
    private var cleanupTimer: Timer?
    private var lastCleanup: Date = Date()
    
    // 发布器
    @Published private(set) var statistics: CacheStatistics
    
    // MARK: - Initialization
    
    init(
        name: String = "Cache",
        config: CacheConfiguration = CacheConfiguration.default
    ) {
        self.cacheName = name
        self.config = config
        self._statistics = Published(initialValue: CacheStatistics(
            totalItems: 0,
            totalSize: 0,
            hitRate: 0,
            missRate: 0,
            averageAccessTime: 0,
            lastCleanup: Date(),
            cacheType: name
        ))
        
        setupTimer()
        print("🗄️ Cache manager '\(name)' initialized with config: \(config)")
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// 获取缓存项
    func get(_ key: Key) -> Value? {
        let startTime = Date()
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.accessCount += 1
            
            // 先检查主缓存
            if let entry = self.primaryCache[key] {
                if self.isValid(entry) {
                    self.updateAccessInfo(for: key)
                    self.recordHit()
                    self.recordAccessTime(startTime)
                } else {
                    // 缓存项已过期，删除
                    self.remove(key)
                    self.recordMiss()
                }
            } else {
                self.recordMiss()
            }
            
            // 更新统计信息
            self.updateStatistics()
        }
        
        return primaryCache[key]?.value
    }
    
    /// 设置缓存项
    func set(_ key: Key, _ value: Value) {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            let entry = CacheEntry(
                key: key,
                value: value,
                createdAt: Date(),
                lastAccessed: Date(),
                accessCount: 1,
                size: self.calculateSize(for: value)
            )
            
            // 如果超过最大大小，先清理
            if self.shouldEvict(for: entry.size) {
                self.evictLRU()
            }
            
            self.primaryCache[key] = entry
            
            // 检查是否需要持久化
            if self.config.enablePersistence {
                self.persistToDisk(key: key, value: value)
            }
            
            self.updateStatistics()
        }
    }
    
    /// 移除缓存项
    func remove(_ key: Key) {
        accessQueue.async { [weak self] in
            self?.primaryCache.removeValue(forKey: key)
            self?.secondaryCache.removeValue(forKey: key)
            self?.updateStatistics()
        }
    }
    
    /// 清空缓存
    func clear() {
        accessQueue.async { [weak self] in
            self?.primaryCache.removeAll()
            self?.secondaryCache.removeAll()
            self?.updateStatistics()
        }
    }
    
    /// 预热缓存
    func warmup(_ items: [(Key, Value)]) {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (key, value) in items {
                if self.primaryCache.count >= self.config.maxItems {
                    self.evictLRU()
                }
                
                let entry = CacheEntry(
                    key: key,
                    value: value,
                    createdAt: Date(),
                    lastAccessed: Date(),
                    accessCount: 1,
                    size: self.calculateSize(for: value)
                )
                
                self.primaryCache[key] = entry
            }
            
            self.updateStatistics()
            print("🔥 Cache '\(self.cacheName)' warmed up with \(items.count) items")
        }
    }
    
    /// 获取缓存统计
    func getStatistics() -> CacheStatistics {
        statistics
    }
    
    /// 强制清理过期缓存
    func cleanupExpired() {
        cleanupQueue.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            let expiredKeys = self.primaryCache.keys.filter { key in
                if let entry = self.primaryCache[key] {
                    return !self.isValid(entry)
                }
                return false
            }
            
            for key in expiredKeys {
                self.primaryCache.removeValue(forKey: key)
            }
            
            self.lastCleanup = now
            self.updateStatistics()
            
            print("🧹 Cache '\(self.cacheName)' cleaned up \(expiredKeys.count) expired items")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupTimer() {
        if config.autoCleanupInterval > 0 {
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: config.autoCleanupInterval, repeats: true) { [weak self] _ in
                self?.cleanupExpired()
            }
        }
    }
    
    private func isValid(_ entry: CacheEntry) -> Bool {
        let now = Date()
        
        // 检查过期时间
        if let expiryTime = config.expiryTime {
            if now.timeIntervalSince(entry.createdAt) > expiryTime {
                return false
            }
        }
        
        // 检查最后访问时间
        if let staleTime = config.staleTime {
            if now.timeIntervalSince(entry.lastAccessed) > staleTime {
                return false
            }
        }
        
        return true
    }
    
    private func updateAccessInfo(for key: Key) {
        guard var entry = primaryCache[key] else { return }
        
        entry.lastAccessed = Date()
        entry.accessCount += 1
        primaryCache[key] = entry
    }
    
    private func shouldEvict(for newItemSize: Int) -> Bool {
        let currentSize = getTotalSize()
        
        // 检查是否超过最大大小
        if currentSize + newItemSize > config.maxMemorySize {
            return true
        }
        
        // 检查是否超过最大项目数
        if primaryCache.count >= config.maxItems {
            return true
        }
        
        return false
    }
    
    private func evictLRU() {
        guard !primaryCache.isEmpty else { return }
        
        // 找到最久未访问的项目
        let sortedEntries = primaryCache.values.sorted { $0.lastAccessed < $1.lastAccessed }
        
        if let lruEntry = sortedEntries.first {
            primaryCache.removeValue(forKey: lruEntry.key)
            print("🗑️ Evicted LRU item: \(lruEntry.key)")
        }
    }
    
    private func calculateSize(for value: Value) -> Int {
        // 简化的大小计算，实际应用中可以使用更精确的方法
        return MemoryLayout<Value>.size
    }
    
    private func getTotalSize() -> Int {
        return primaryCache.values.reduce(0) { $0 + $1.size }
    }
    
    private func persistToDisk(key: Key, value: Value) {
        // 未来实现：将不常用的数据持久化到磁盘
        // 这里可以扩展为二级缓存系统
    }
    
    // MARK: - Statistics
    
    private func recordHit() {
        hitCount += 1
    }
    
    private func recordMiss() {
        missCount += 1
    }
    
    private func recordAccessTime(_ startTime: Date) {
        let accessTime = Date().timeIntervalSince(startTime)
        totalAccessTime += accessTime
    }
    
    private func updateStatistics() {
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0
        let missRate = 1.0 - hitRate
        let averageAccessTime = accessCount > 0 ? totalAccessTime / Double(accessCount) : 0
        
        statistics = CacheStatistics(
            totalItems: primaryCache.count,
            totalSize: Int64(getTotalSize()),
            hitRate: hitRate,
            missRate: missRate,
            averageAccessTime: averageAccessTime,
            lastCleanup: lastCleanup,
            cacheType: cacheName
        )
    }
}

// MARK: - 缓存配置

/// 缓存配置
struct CacheConfiguration {
    let maxItems: Int // 最大项目数
    let maxMemorySize: Int // 最大内存使用（字节）
    let expiryTime: TimeInterval? // 过期时间（秒）
    let staleTime: TimeInterval? // 停滞时间（秒）
    let autoCleanupInterval: TimeInterval // 自动清理间隔（秒）
    let enablePersistence: Bool // 启用持久化
    let enableCompression: Bool // 启用压缩
    let enableEncryption: Bool // 启用加密
    
    static let `default` = CacheConfiguration(
        maxItems: 1000,
        maxMemorySize: 50 * 1024 * 1024, // 50MB
        expiryTime: 300, // 5分钟
        staleTime: 600, // 10分钟
        autoCleanupInterval: 60, // 1分钟
        enablePersistence: false,
        enableCompression: false,
        enableEncryption: false
    )
    
    static let development = CacheConfiguration(
        maxItems: 500,
        maxMemorySize: 20 * 1024 * 1024, // 20MB
        expiryTime: 120, // 2分钟
        staleTime: 300, // 5分钟
        autoCleanupInterval: 30, // 30秒
        enablePersistence: false,
        enableCompression: false,
        enableEncryption: false
    )
    
    static let production = CacheConfiguration(
        maxItems: 5000,
        maxMemorySize: 100 * 1024 * 1024, // 100MB
        expiryTime: 600, // 10分钟
        staleTime: 1800, // 30分钟
        autoCleanupInterval: 300, // 5分钟
        enablePersistence: true,
        enableCompression: true,
        enableEncryption: true
    )
}

// MARK: - 缓存条目

private struct CacheEntry {
    let key: AnyHashable // 使用AnyHashable支持不同类型的Key
    let value: Any // 使用Any支持不同类型的Value
    let createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
    let size: Int
    
    init<Key: Hashable, Value>(key: Key, value: Value, createdAt: Date, lastAccessed: Date, accessCount: Int, size: Int) {
        self.key = key
        self.value = value
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
        self.size = size
    }
}

// MARK: - 专用缓存管理器

/// 笔记缓存管理器
typealias NotesCacheManager = IntelligentCacheManager<UUID, Note>

/// 剪贴板缓存管理器
typealias ClipboardCacheManager = IntelligentCacheManager<UUID, ClipboardItem>

/// 搜索结果缓存管理器
typealias SearchResultCacheManager = IntelligentCacheManager<String, [NoteIndex]>

// MARK: - 全局缓存实例

/// 全局缓存管理器实例
@MainActor
final class GlobalCacheManager: ObservableObject {
    static let shared = GlobalCacheManager()
    
    let notesCache: NotesCacheManager
    let clipboardCache: ClipboardCacheManager
    let searchCache: SearchResultCacheManager
    
    private init() {
        let config = CacheConfiguration.production
        
        self.notesCache = NotesCacheManager(name: "Notes", config: config)
        self.clipboardCache = ClipboardCacheManager(name: "Clipboard", config: config)
        self.searchCache = SearchResultCacheManager(name: "SearchResults", config: CacheConfiguration(
            maxItems: 200,
            maxMemorySize: 10 * 1024 * 1024, // 10MB
            expiryTime: 60, // 1分钟
            staleTime: 120, // 2分钟
            autoCleanupInterval: 30, // 30秒
            enablePersistence: false,
            enableCompression: false,
            enableEncryption: false
        ))
        
        print("🌐 Global cache manager initialized")
    }
    
    /// 获取所有缓存统计
    func getAllStatistics() -> [String: CacheStatistics] {
        return [
            "Notes": notesCache.getStatistics(),
            "Clipboard": clipboardCache.getStatistics(),
            "SearchResults": searchCache.getStatistics()
        ]
    }
    
    /// 清空所有缓存
    func clearAllCaches() {
        notesCache.clear()
        clipboardCache.clear()
        searchCache.clear()
        
        print("🧹 All caches cleared")
    }
    
    /// 预热常用缓存
    func warmupCaches() {
        // 预热笔记缓存
        Task {
            // 这里可以加载常用笔记
            print("🔥 Warming up caches...")
        }
    }
}

// MARK: - 缓存使用示例

extension IntelligentCacheManager {
    /// 安全地获取值（带错误处理）
    func safeGet(_ key: Key) -> Result<Value?, Error> {
        do {
            let value = get(key)
            return .success(value)
        } catch {
            return .failure(error)
        }
    }
    
    /// 安全地设置值（带错误处理）
    func safeSet(_ key: Key, _ value: Value) -> Result<Void, Error> {
        do {
            set(key, value)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    /// 获取或设置（不存在时创建）
    func getOrSet(_ key: Key, _ factory: () throws -> Value) rethrows -> Value {
        if let existingValue = get(key) {
            return existingValue
        }
        
        let newValue = try factory()
        set(key, newValue)
        return newValue
    }
}
