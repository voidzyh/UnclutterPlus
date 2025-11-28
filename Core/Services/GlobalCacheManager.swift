import Foundation
import SwiftUI

/// 全局缓存管理器 - 统一所有缓存服务
@MainActor
final class GlobalCacheManager: ObservableObject {
    static let shared = GlobalCacheManager()
    
    // MARK: - Cache Instances
    
    /// 笔记缓存
    let notesCache: IntelligentCacheManager<UUID, Note>
    
    /// 剪贴板缓存
    let clipboardCache: IntelligentCacheManager<UUID, ClipboardItem>
    
    /// 搜索结果缓存
    let searchCache: IntelligentCacheManager<String, [NoteIndex]>
    
    /// 用户偏好缓存
    let preferencesCache: IntelligentCacheManager<String, Any>
    
    // MARK: - Performance Metrics
    
    @Published private(set) var cacheMetrics: CacheMetrics = CacheMetrics()
    
    // MARK: - Initialization
    
    private init() {
        print("🗄️ Initializing global cache manager...")
        
        // 创建笔记缓存
        let notesConfig = CacheConfiguration.production
        self.notesCache = IntelligentCacheManager<UUID, Note>(name: "NotesCache", config: notesConfig)
        
        // 创建剪贴板缓存
        let clipboardConfig = CacheConfiguration.development
        self.clipboardCache = IntelligentCacheManager<UUID, ClipboardItem>(name: "ClipboardCache", config: clipboardConfig)
        
        // 创建搜索缓存（短期缓存）
        let searchConfig = CacheConfiguration(
            maxItems: 200,
            maxMemorySize: 10 * 1024 * 1024, // 10MB
            expiryTime: 60, // 1分钟
            staleTime: 120, // 2分钟
            autoCleanupInterval: 30, // 30秒
            enablePersistence: false,
            enableCompression: false,
            enableEncryption: false
        )
        self.searchCache = IntelligentCacheManager<String, [NoteIndex]>(name: "SearchCache", config: searchConfig)
        
        // 创建用户偏好缓存
        let preferencesConfig = CacheConfiguration(
            maxItems: 100,
            maxMemorySize: 5 * 1024 * 1024, // 5MB
            expiryTime: 300, // 5分钟
            staleTime: 600, // 10分钟
            autoCleanupInterval: 60, // 1分钟
            enablePersistence: true, // 偏好设置可以持久化
            enableCompression: false,
            enableEncryption: false
        )
        self.preferencesCache = IntelligentCacheManager<String, Any>(name: "PreferencesCache", config: preferencesConfig)
        
        // 启动缓存监控
        startCacheMonitoring()
        
        print("✅ Global cache manager initialized")
    }
    
    // MARK: - Public Methods
    
    /// 获取缓存统计信息
    func getCacheStatistics() async -> [String: CacheStatistics] {
        return [
            "notes": notesCache.getStatistics(),
            "clipboard": clipboardCache.getStatistics(),
            "search": searchCache.getStatistics(),
            "preferences": preferencesCache.getStatistics()
        ]
    }
    
    /// 执行缓存维护
    func performCacheMaintenance() async {
        print("🧹 Performing cache maintenance...")
        
        // 清理过期缓存
        notesCache.cleanupExpired()
        clipboardCache.cleanupExpired()
        searchCache.cleanupExpired()
        preferencesCache.cleanupExpired()
        
        // 更新缓存指标
        await updateCacheMetrics()
        
        print("✅ Cache maintenance completed")
    }
    
    /// 清空所有缓存
    func clearAllCaches() {
        print("⚠️ Clearing all caches...")
        
        notesCache.clear()
        clipboardCache.clear()
        searchCache.clear()
        preferencesCache.clear()
        
        Task {
            await updateCacheMetrics()
        }
        
        print("✅ All caches cleared")
    }
    
    /// 预热缓存
    func warmupCaches() async {
        print("🔥 Warming up caches...")
        
        // 预热常用数据
        await warmupCommonData()
        
        // 预热用户偏好
        await warmupUserPreferences()
        
        await updateCacheMetrics()
        
        print("✅ Cache warmup completed")
    }
    
    /// 获取内存使用情况
    func getMemoryUsage() async -> MemoryUsageReport {
        let stats = await getCacheStatistics()
        var totalSize: Int64 = 0
        var totalItems: Int = 0
        
        for (_, cacheStats) in stats {
            totalSize += cacheStats.totalSize
            totalItems += cacheStats.totalItems
        }
        
        return MemoryUsageReport(
            totalSize: totalSize,
            totalItems: totalItems,
            cacheBreakdown: stats
        )
    }
    
    // MARK: - Cache Operations
    
    /// 缓存笔记
    func cacheNote(_ note: Note) {
        notesCache.set(note.id.uuidString, note)
    }
    
    /// 获取缓存的笔记
    func getCachedNote(id: UUID) -> Note? {
        return notesCache.get(id.uuidString) as? Note
    }
    
    /// 缓存剪贴板项目
    func cacheClipboardItem(_ item: ClipboardItem) {
        clipboardCache.set(item.id.uuidString, item)
    }
    
    /// 获取缓存的剪贴板项目
    func getCachedClipboardItem(id: UUID) -> ClipboardItem? {
        return clipboardCache.get(id.uuidString) as? ClipboardItem
    }
    
    /// 缓存搜索结果
    func cacheSearchResults(query: String, results: [NoteIndex]) {
        searchCache.set(query.lowercased(), results)
    }
    
    /// 获取缓存的搜索结果
    func getCachedSearchResults(query: String) -> [NoteIndex]? {
        return searchCache.get(query.lowercased()) as? [NoteIndex]
    }
    
    /// 缓存用户偏好
    func cachePreference(key: String, value: Any) {
        preferencesCache.set(key, value)
    }
    
    /// 获取缓存的用户偏好
    func getCachedPreference(key: String) -> Any? {
        return preferencesCache.get(key)
    }
    
    // MARK: - Private Methods
    
    private func startCacheMonitoring() {
        // 每30秒更新一次缓存指标
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await self.updateCacheMetrics()
            }
        }
    }
    
    private func updateCacheMetrics() async {
        let stats = await getCacheStatistics()
        
        let totalSize = stats.values.reduce(0) { $0 + $1.totalSize }
        let totalItems = stats.values.reduce(0) { $0 + $1.totalItems }
        let totalCacheSize = stats.values.reduce(0) { $0 + $1.cacheSize }
        let hitRate = stats.values.isEmpty ? 0 : 
            stats.values.map { $0.hitRate }.reduce(0, +) / Double(stats.values.count)
        
        await MainActor.run {
            cacheMetrics = CacheMetrics(
                totalSize: totalSize,
                totalItems: totalItems,
                cacheSize: totalCacheSize,
                hitRate: hitRate,
                lastUpdate: Date()
            )
        }
    }
    
    private func warmupCommonData() async {
        // 预热常用笔记数据
        // 这里可以加载用户常用访问的笔记
        
        print("📝 Notes cache warmed up")
    }
    
    private func warmupUserPreferences() async {
        // 预热用户偏好设置
        // 这里可以加载用户常用的偏好设置
        
        print("⚙️ Preferences cache warmed up")
    }
}

// MARK: - Supporting Types

/// 缓存指标
struct CacheMetrics {
    let totalSize: Int64
    let totalItems: Int
    let cacheSize: Int
    let hitRate: Double
    let lastUpdate: Date
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var description: String {
        """
        Cache Metrics:
        - Total Size: \(formattedSize)
        - Total Items: \(totalItems)
        - Cache Items: \(cacheSize)
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Last Update: \(lastUpdate)
        """
    }
}

/// 内存使用报告
struct MemoryUsageReport {
    let totalSize: Int64
    let totalItems: Int
    let cacheBreakdown: [String: CacheStatistics]
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var description: String {
        """
        Memory Usage Report:
        - Total Size: \(formattedSize)
        - Total Items: \(totalItems)
        
        Cache Breakdown:
        \(cacheBreakdown.map { "- \($0.key): \($1.totalItems) items, \(ByteCountFormatter.string(fromByteCount: $1.totalSize, countStyle: .file))" }.joined(separator: "\n"))
        """
    }
}

// MARK: - Cache Utilities

/// 缓存工具扩展
extension GlobalCacheManager {
    /// 获取缓存效率评分
    func getCacheEfficiencyScore() -> Double {
        let metrics = cacheMetrics
        
        // 计算效率评分 (0-100)
        var score = 0.0
        
        // 命中率权重40%
        score += metrics.hitRate * 40
        
        // 缓存利用率权重30%
        let utilizationRate = metrics.cacheSize > 0 ? Double(metrics.totalItems) / Double(metrics.cacheSize) : 0
        score += min(utilizationRate, 1.0) * 30
        
        // 大小合理性权重30%
        let sizeScore = metrics.totalSize < 50 * 1024 * 1024 ? 30 : // 50MB以下
                   metrics.totalSize < 100 * 1024 * 1024 ? 20 : // 100MB以下
                   metrics.totalSize < 200 * 1024 * 1024 ? 10 : 0 // 200MB以下
        score += sizeScore
        
        return min(score, 100)
    }
    
    /// 获取缓存优化建议
    func getOptimizationSuggestions() -> [String] {
        var suggestions: [String] = []
        let score = getCacheEfficiencyScore()
        
        if score < 60 {
            suggestions.append("缓存效率较低，建议清理过期数据")
        }
        
        if cacheMetrics.hitRate < 0.7 {
            suggestions.append("命中率较低，考虑增加缓存大小或延长缓存时间")
        }
        
        if cacheMetrics.totalSize > 100 * 1024 * 1024 {
            suggestions.append("缓存大小较大，建议启用压缩或增加清理频率")
        }
        
        return suggestions
    }
}

// MARK: - Memory Warning Handler

extension GlobalCacheManager {
    /// 处理内存警告
    func handleMemoryWarning() {
        print("⚠️ Memory warning received, optimizing caches...")
        
        // 紧急清理缓存
        searchCache.clear()
        preferencesCache.cleanupExpired()
        
        Task {
            await performCacheMaintenance()
        }
    }
}
