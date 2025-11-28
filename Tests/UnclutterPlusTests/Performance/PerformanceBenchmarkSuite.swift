import XCTest
import Foundation
import SwiftUI
@testable import UnclutterPlus

/// 性能基准测试套件
@MainActor
final class PerformanceBenchmarkSuite: ObservableObject {
    
    // MARK: - Benchmark Results
    
    @Published private(set) var results: [BenchmarkResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var currentBenchmark: String = ""
    @Published private(set) var progress: Double = 0.0
    
    // MARK: - Public Methods
    
    /// 运行完整性能基准测试套件
    func runFullBenchmark() async -> PerformanceBenchmarkReport {
        print("🚀 Starting full performance benchmark suite...")
        
        isRunning = true
        results.removeAll()
        progress = 0
        currentBenchmark = "初始化..."
        
        var report = PerformanceReport()
        
        // 1. 应用启动性能测试
        currentBenchmark = "应用启动性能测试"
        progress = 0.1
        let startupBenchmark = await benchmarkAppStartup()
        report.startupBenchmark = startupBenchmark
        results.append(startupBenchmark)
        
        // 2. 存储性能测试
        currentBenchmark = "存储性能测试"
        progress = 0.2
        let storageBenchmark = await benchmarkStoragePerformance()
        report.storageBenchmark = storageBenchmark
        results.append(storageBenchmark)
        
        // 3. 搜索性能测试
        currentBenchmark = "搜索性能测试"
        progress = 0.4
        let searchBenchmark = await benchmarkSearchPerformance()
        report.searchBenchmark = searchBenchmark
        results.append(searchBenchmark)
        
        // 4. 缓存性能测试
        currentBenchmark = "缓存性能测试"
        progress = 0.6
        let cacheBenchmark = await benchmarkCachePerformance()
        report.cacheBenchmark = cacheBenchmark
        results.append(cacheBenchmark)
        
        // 5. UI渲染性能测试
        currentBenchmark = "UI渲染性能测试"
        progress = 0.8
        let uiBenchmark = await benchmarkUIPerformance()
        report.uiBenchmark = uiBenchmark
        results.append(uiBenchmark)
        
        // 6. 内存使用测试
        currentBenchmark = "内存使用测试"
        progress = 0.9
        let memoryBenchmark = await benchmarkMemoryUsage()
        report.memoryBenchmark = memoryBenchmark
        results.append(memoryBenchmark)
        
        // 7. 整体性能测试
        currentBenchmark = "整体性能测试"
        progress = 1.0
        let overallBenchmark = await benchmarkOverallPerformance()
        report.overallBenchmark = overallBenchmark
        results.append(overallBenchmark)
        
        isRunning = false
        currentBenchmark = "完成"
        
        print("🎉 Performance benchmark suite completed")
        print(report.description)
        
        return report
    }
    
    // MARK: - Individual Benchmarks
    
    /// 应用启动性能基准测试
    private func benchmarkAppStartup() async -> AppStartupBenchmark {
        let iterations = 10
        var durations: [TimeInterval] = []
        
        print("🔄 Benchmarking app startup performance...")
        
        for i in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 模拟启动过程
            _ = NotesService()
            _ = UnifiedStorageManager.shared
            _ = GlobalCacheManager.shared
            _ = SecurityManager.shared
            
            let endTime = CFAbsoluteTimeGetCurrent()
            durations.append(endTime - startTime)
        }
        
        let averageDuration = durations.reduce(0, +) / Double(iterations)
        let minDuration = durations.min() ?? 0
        let maxDuration = durations.max() ?? 0
        
        let score = calculateStartupScore(averageDuration)
        
        print("Startup: Avg: \(String(format: "%.3f", averageDuration))s, Min: \(String(format: "%.3f", minDuration))s, Max: \(String(format: "%.3f", maxDuration))s")
        
        return AppStartupBenchmark(
            iterations: iterations,
            averageDuration: averageDuration,
            minDuration: minDuration,
            maxDuration: maxDuration,
            score: score
        )
    }
    
    /// 存储性能基准测试
    private func benchmarkStoragePerformance() async -> StoragePerformanceBenchmark {
        let noteCount = 1000
        let searchQueries = 100
        
        print("🔄 Benchmarking storage performance...")
        
        let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)
        var durations: [TimeInterval] = []
        
        // 创建笔记基准测试
        let createStartTime = CFAbsoluteTimeGetCurrent()
        for i in 0..<noteCount {
            let note = Note(title: "Benchmark Note \(i)", content: "Performance test content \(i)")
            let result = await storage.create([note])
            
            if case .failure(let error) = result {
                print("❌ Failed to create note \(i): \(error)")
            }
        }
        let createDuration = CFAbsoluteTimeGetCurrent() - createStartTime
        
        // 搜索基准测试
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        for i in 0..<searchQueries {
            _ = await storage.search(query: "Benchmark", limit: 10)
        }
        let searchDuration = CFAbsoluteTimeGetCurrent() - searchStartTime
        
        // 读取基准测试
        let readStartTime = CFAbsoluteTimeGetCurrent()
        let allIndexes = await storage.getAllIndexes()
        for index in allIndexes.prefix(100) {
            _ = await storage.read(id: index.id)
        }
        let readDuration = CFAbsoluteTimeGetCurrent() - readStartTime
        
        let createOpsPerSecond = Double(noteCount) / createDuration
        let searchOpsPerSecond = Double(searchQueries) / searchDuration
        let readOpsPerSecond = Double(min(100, allIndexes.count) / readDuration
        
        print("Storage: Create: \(String(format: "%.1f", createOpsPerSecond) ops/sec, Search: \(String(format: "1f", searchOpsPerSecond) ops/sec, Read: \(String(format: "1f", readOpsPerSecond) ops/sec")
        
        return StoragePerformanceBenchmark(
            noteCount: noteCount,
            createDuration: createDuration,
            searchDuration: searchDuration,
            readDuration: readDuration,
            createOpsPerSecond: createOpsPerSecond,
            searchOpsPerSecond: searchOpsPerSecond,
            readOpsPerSecond: readOpsPerSecond
        )
    }
    
    /// 搜索性能基准测试
    private func benchmarkSearchPerformance() async -> SearchPerformanceBenchmark {
        let service = NotesService()
        let queryCount = 50
        let resultCounts: [Int] = []
        var durations: [TimeInterval] = []
        
        print("🔄 Benchmarking search performance...")
        
        // 创建搜索测试数据
        for i in 0..<100 {
            _ = await service.createNote(title: "Search Test \(i)", content: "Searchable content \(i % 10)")
        }
        
        // 执行搜索基准测试
        for i in 0..<queryCount {
            let query = "searchable \(i % 10)"
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let results = await service.searchNotes(query: query)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            durations.append(duration)
            resultCounts.append(results.count)
        }
        
        let averageDuration = durations.reduce(0, +) / Double(queryCount)
        let averageResultCount = Double(resultCounts.reduce(0, +) / Double(queryCount)
        let queriesPerSecond = Double(queryCount) / durations.reduce(0, +)
        
        print("Search: \(queriesPerSecond) queries/sec, Avg results: \(String(format: "1f", averageResultCount), Avg duration: \(String(format: "3f", averageDuration * 1000)ms")
        
        return SearchPerformanceBenchmark(
            queryCount: queryCount,
            averageDuration: averageDuration,
            averageResultCount: averageResultCount,
            queriesPerSecond: queriesPerSecond
        )
    }
    
    /// 缓存性能基准测试
    private func benchmarkCachePerformance() async -> CachePerformanceBenchmark {
        let cache = GlobalCacheManager.shared.notesCache
        let operations = 1000
        var writeDurations: [TimeInterval] = []
        var readDurations: [TimeInterval] = []
        
        print("🔄 Benchmarking cache performance...")
        
        // 写入基准测试
        let writeStartTime = CFAbsoluteTimeGetCurrent()
        for i in 0..<operations {
            cache.set(UUID().uuidString, Note(title: "Cache Test \(i)", content: "Cache performance test")
        }
        let writeDuration = CFAbsoluteTimeGetCurrent() - writeStartTime
        
        // 读取基准测试
        let readStartTime = CFAbsoluteTimeGetCurrent()
        for i in 0..<operations {
            let key = UUID().uuidString
            _ = cache.get(key)
        }
        let readDuration = CFAbsoluteTimeGetCurrent() - readStartTime
        
        let writeOpsPerSecond = Double(operations) / writeDuration
        let readOpsPerSecond = Double(operations) / readDuration
        
        print("Cache: Write: \(String(format: "1f", writeOpsPerSecond) ops/sec, Read: \(String(format: "1f", readOpsPerSecond) ops/sec")
        
        return CachePerformanceBenchmark(
            operations: operations,
            writeDuration: writeDuration,
            readDuration: readDuration,
            writeOpsPerSecond: writeOpsPerSecond,
            readOpsPerSecond: readOpsPerSecond
        )
    }
    
    /// UI渲染性能基准测试
    private func benchmarkUIPerformance() async -> UIPerformanceBenchmark {
        // 模拟UI渲染性能测试
        let renderCount = 100
        let durations: [TimeInterval] = []
        
        print("🔄 Benchmarking UI performance...")
        
        // 模拟视图创建和更新
        for i in 0..<renderCount {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 模拟视图创建
            _ = MainContentView()
            
            let endTime = CFAbsoluteTimeGetCurrent()
            durations.append(endTime - startTime)
        }
        
        let averageDuration = durations.reduce(0, +) / Double(renderCount)
        let rendersPerSecond = Double(renderCount) / durations.reduce(0, +)
        
        print("UI: \(String(format: "1f", rendersPerSecond) renders/sec, Avg duration: \(averageDuration * 1000)ms")
        
        return UIPerformanceBenchmark(
            renderCount: renderCount,
            averageDuration: averageDuration,
            rendersPerSecond: rendersPerSecond
        )
    }
    
    /// 内存使用基准测试
    private func benchmarkMemoryUsage() async -> MemoryUsageBenchmark {
        let initialMemory = getMemoryUsage()
        let service = NotesService()
        
        print("🔄 Benchmarking memory usage...")
        
        // 创建大量数据
        for i in 0..<500 {
            _ = await service.createNote(
                title: "Memory Test \(i)",
                content: String(repeating: "Memory test content ", count: 200)
        }
        
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // 测试缓存使用
        let cacheManager = GlobalCacheManager.shared
        let cacheStats = await cacheManager.getCacheStatistics()
        
        print("Memory: Initial: \(initialMemory / 1024 / 1024)MB, Peak: \(peakMemory / 1024 / 1024)MB, Increase: \(memoryIncrease / 1024 / 1024)MB")
        
        return MemoryUsageBenchmark(
            initialMemory: initialMemory,
            peakMemory: peakMemory,
            memoryIncrease: memoryIncrease,
            cacheSize: Int64(cacheStats["notes"]?.totalSize ?? 0),
            notesCount: service.noteIndexes.count
        )
    }
    
    /// 整体性能基准测试
    private func benchmarkOverallPerformance() async -> OverallPerformanceBenchmark {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 模拟完整工作流
        let service = NotesService()
        let cacheManager = GlobalCacheManager.shared
        
        // 并发操作
        await withTaskGroup(of: Void.self) { group in
            // 创建笔记
            for i in 0..<50 {
                group.addTask {
                    _ = await service.createNote(title: "Overall Test \(i)", content: "Overall performance test")
                }
            }
            
            // 执行搜索
            for i in 0..<20 {
                group.addTask {
                    _ = await service.searchNotes(query: "Overall")
                }
            }
            
            // 执行缓存操作
            for i in 0..<30 {
                group.addTask {
                    cacheManager.cacheNote(Note(title: "Cache Test \(i)", content: "Cache performance")
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalDuration = endTime - startTime
        
        let finalMemory = getMemoryUsage()
        let memoryEfficiency = Double(service.noteIndexes.count) / Double(finalMemory / 1024 / 1024) // 笔记数/MB
        
        print("Overall: \(totalDuration)s, Memory: \(finalMemory / 1024 / 1024)MB, Efficiency: \(memoryEfficiency) notes/MB")
        
        return OverallPerformanceBenchmark(
            duration: totalDuration,
            memoryEfficiency: memoryEfficiency,
            operationsPerSecond: Double(service.noteIndexes.count) / totalDuration
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateStartupScore(_ duration: TimeInterval) -> Double {
        // 基于启动时间计算评分 (0-100分)
        // < 1秒 = 100分，> 5秒 = 0分
        let normalizedDuration = max(0, min(5, duration)
        return max(0, 100 - (normalizedDuration - 1) * 20)
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: task_info_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Benchmark Results

struct PerformanceReport {
    let startupBenchmark: AppStartupBenchmark
    let storageBenchmark: StoragePerformanceBenchmark
    let searchBenchmark: SearchPerformanceBenchmark
    let cacheBenchmark: CachePerformanceBenchmark
    let uiBenchmark: UIPerformanceBenchmark
    let memoryBenchmark: MemoryUsageBenchmark
    let overallBenchmark: OverallPerformanceBenchmark
    
    var description: String {
        """
        性能基准测试报告:
        
        📱 应用启动: \(String(format: "%.1f", startupBenchmark.score)分
        💾 存储性能: \(storageBenchmark.createOpsPerSecond) 创建/秒, \(storageBenchmark.searchOpsPerSecond) 搜索/秒
        🔍 搜索性能: \(searchBenchmark.queriesPerSecond) 查询/秒
        🗄️ 缓存性能: \(cacheBenchmark.writeOpsPerSecond) 写入/秒, \(cacheBenchmark.readOpsPerSecond) 读取/秒
        🎨 UI渲染: \(uiBenchmark.rendersPerSecond) 渲染/秒
        🧠 内存使用: \(memoryBenchmark.memoryIncrease / 1024 / 1024)MB 增长
        ⚡ 整体性能: \(overallBenchmark.operationsPerSecond) 操作/秒
        """
    }
}

struct AppStartupBenchmark {
    let iterations: Int
    let averageDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let score: Double
}

struct StoragePerformanceBenchmark {
    let noteCount: Int
    let createDuration: TimeInterval
    let searchDuration: TimeInterval
    let readDuration: TimeInterval
    let createOpsPerSecond: Double
    let searchOpsPerSecond: Double
    let readOpsPerSecond: Double
}

struct SearchPerformanceBenchmark {
    let queryCount: Int
    let averageDuration: TimeInterval
    let averageResultCount: Double
    let queriesPerSecond: Double
}

struct CachePerformanceBenchmark {
    let operations: Int
    let writeDuration: TimeInterval
    let readDuration: TimeInterval
    let writeOpsPerSecond: Double
    let readOpsPerSecond: Double
}

struct UIPerformanceBenchmark {
    let renderCount: Int
    let averageDuration: TimeInterval
    let rendersPerSecond: Double
}

struct MemoryUsageBenchmark {
    let initialMemory: Int64
    let peakMemory: Int64
    let memoryIncrease: Int64
    let cacheSize: Int64
    let notesCount: Int
}

struct OverallPerformanceBenchmark {
    let duration: TimeInterval
    let memoryEfficiency: Double
    let operationsPerSecond: Double
}

// MARK: - Performance Targets

enum PerformanceTargets {
    static let startupTime: TimeInterval = 3.0 // 3秒启动目标
    static let memoryUsage: Int64 = 100 * 1024 * 1024 // 100MB内存使用目标
    static let searchTime: TimeInterval = 0.1 // 100ms搜索目标
    static let cacheHitRate: Double = 0.8 // 80%缓存命中率目标
}

// MARK: - Performance Monitor

@MainActor
final class PerformanceMonitor: ObservableObject {
    @Published private(set) var currentMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published private(set) var alerts: [PerformanceAlert] = []
    @Published private(set) var isMonitoring = false
    
    private var monitoringTimer: Timer?
    
    func startMonitoring(interval: TimeInterval = 5.0) {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.collectMetrics()
            }
        }
        
        print("📊 Performance monitoring started")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        print("📊 Performance monitoring stopped")
    }
    
    private func collectMetrics() async {
        let memoryUsage = getMemoryUsage()
        let cacheStats = await GlobalCacheManager.shared.getCacheStatistics()
        let notesCount = AppStorageManager.shared.notesService.noteIndexes.count
        
        let metrics = PerformanceMetrics(
            timestamp: Date(),
            memoryUsage: memoryUsage,
            cacheHitRate: cacheStats["notes"]?.hitRate ?? 0,
            notesCount: notesCount,
            searchLatency: measureSearchLatency()
        )
        
        await MainActor.run {
            currentMetrics = metrics
        }
        
        // 检查性能告警
        checkAlerts(metrics)
    }
    
    private func measureSearchLatency() -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        Task {
            _ = await AppStorageManager.shared.notesService.searchNotes(query: "performance")
        }
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    private func checkAlerts(_ metrics: PerformanceMetrics) {
        var newAlerts: [PerformanceAlert] = []
        
        if metrics.memoryUsage > PerformanceTargets.memoryUsage {
            newAlerts.append(PerformanceAlert(
                type: .memory,
                message: "内存使用超过目标: \(metrics.memoryUsage / 1024 / 1024)MB > 100MB",
                timestamp: Date()
            ))
        }
        
        if metrics.searchLatency > PerformanceTargets.searchTime {
            newAlerts.append(PerformanceAlert(
                type: .performance,
                message: "搜索延迟过高: \(String(format: "3f", metrics.searchLatency * 1000)ms > 100ms",
                timestamp: Date()
            ))
        }
        
        if metrics.cacheHitRate < PerformanceTargets.cacheHitRate {
            newAlerts.append(PerformanceAlert(
                type: .cache,
                message: "缓存命中率过低: \(String(format: "2f", metrics.cacheHitRate * 100)% < 80%",
                timestamp: Date()
            ))
        }
        
        await MainActor.run {
            self.alerts.append(contentsOf: newAlerts)
            
            // 保持告警历史不超过100条
            if self.alerts.count > 100 {
                self.alerts.removeFirst()
            }
        }
    }
}

struct PerformanceMetrics {
    let timestamp: Date
    let memoryUsage: Int64
    let cacheHitRate: Double
    let notesCount: Int
    let searchLatency: TimeInterval
}

struct PerformanceAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let message: String
    let timestamp: Date
    
    enum AlertType {
        case memory
        case performance
        case cache
        case storage
    }
}

// MARK: - Preview

#if DEBUG
struct PerformanceMonitor_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceMonitor()
            .frame(width: 400, height: 300)
    }
}
#endif
