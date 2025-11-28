import XCTest
import Foundation
import Combine

@testable import UnclutterPlus

/// 性能基准测试
final class PerformanceBenchmarkTests: XCTestCase {
    var serviceManager: ApplicationServiceManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        serviceManager = ApplicationServiceManager.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        Task {
            await serviceManager.shutdown()
        }
        cancellables = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Startup Performance Tests
    
    func testApplicationStartupTime() async throws {
        let startTime = Date()
        
        try await serviceManager.initialize()
        
        let endTime = Date()
        let startupTime = endTime.timeIntervalSince(startTime)
        
        // 应用启动时间应该少于3秒
        XCTAssertLessThan(startupTime, 3.0, "启动时间过长: \(startupTime)秒")
        
        print("📊 应用启动时间: \(String(format: "%.3f", startupTime))秒")
        
        // 记录到性能日志
        logger.performance(
            operation: "Benchmark Application Startup",
            duration: startupTime
        )
    }
    
    func testServiceInitializationPhases() async throws {
        var phaseTimes: [String: TimeInterval] = [:]
        
        let startTime = Date()
        
        // Phase 1: 基础服务
        let phase1Start = Date()
        try await serviceManager.initializeBasicServices()
        phaseTimes["基础服务"] = Date().timeIntervalSince(phase1Start)
        
        // Phase 2: 核心服务
        let phase2Start = Date()
        try await serviceManager.initializeCoreServices()
        phaseTimes["核心服务"] = Date().timeIntervalSince(phase2Start)
        
        // Phase 3: 高级服务
        let phase3Start = Date()
        try await serviceManager.initializeAdvancedServices()
        phaseTimes["高级服务"] = Date().timeIntervalSince(phase3Start)
        
        // Phase 4: 安全和监控
        let phase4Start = Date()
        try await serviceManager.initializeSecurityAndMonitoring()
        phaseTimes["安全监控"] = Date().timeIntervalSince(phase4Start)
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // 验证各阶段时间
        for (phase, time) in phaseTimes {
            XCTAssertLessThan(time, 2.0, "\(phase)初始化时间过长: \(time)秒")
            print("📈 \(phase): \(String(format: "%.3f", time))秒")
        }
        
        print("📊 总初始化时间: \(String(format: "%.3f", totalTime))秒")
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageDuringInitialization() async throws {
        let initialMemory = getMemoryUsage()
        
        try await serviceManager.initialize()
        
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // 内存增长应该少于100MB
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "内存使用过高")
        
        print("📊 内存增长: \(memoryIncrease / 1024 / 1024)MB")
        
        // 记录内存使用
        logger.memoryUsage(
            category: "Benchmark",
            metadata: [
                "initial_memory": "\(initialMemory / 1024 / 1024)MB",
                "peak_memory": "\(peakMemory / 1024 / 1024)MB",
                "memory_increase": "\(memoryIncrease / 1024 / 1024)MB"
            ]
        )
    }
    
    func testMemoryStabilityUnderLoad() async throws {
        try await serviceManager.initialize()
        
        // 模拟负载：多次执行健康检查
        var memories: [Int64] = []
        
        for _ in 0..<10 {
            let healthReport = await serviceManager.performHealthCheck()
            memories.append(getMemoryUsage())
            
            // 稍微等待一下
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        // 检查内存是否稳定
        let maxMemory = memories.max() ?? 0
        let minMemory = memories.min() ?? 0
        let memoryVariation = maxMemory - minMemory
        
        // 内存变化应该小于20MB
        XCTAssertLessThan(memoryVariation, 20 * 1024 * 1024, "内存使用不稳定")
        
        print("📊 内存变化: \(memoryVariation / 1024 / 1024)MB")
    }
    
    // MARK: - Service Performance Tests
    
    func testNotesServicePerformance() async throws {
        try await serviceManager.initialize()
        let notesService = try await serviceManager.getNotesService()
        
        // 测试笔记创建性能
        let createStartTime = Date()
        for i in 0..<10 {
            _ = await notesService.createNote(title: "Test Note \(i)", content: "Test content \(i)")
        }
        let createTime = Date().timeIntervalSince(createStartTime)
        
        XCTAssertLessThan(createTime, 5.0, "笔记创建性能不佳")
        print("📈 笔记创建(10个): \(String(format: "%.3f", createTime))秒")
        
        // 测试搜索性能
        let searchStartTime = Date()
        _ = await notesService.searchNotes(query: "test")
        let searchTime = Date().timeIntervalSince(searchStartTime)
        
        XCTAssertLessThan(searchTime, 1.0, "笔记搜索性能不佳")
        print("📈 笔记搜索: \(String(format: "%.3f", searchTime))秒")
    }
    
    func testHealthCheckPerformance() async throws {
        try await serviceManager.initialize()
        
        let iterations = 50
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = await serviceManager.performHealthCheck()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(iterations)
        
        // 平均健康检查时间应该少于100ms
        XCTAssertLessThan(averageTime, 0.1, "健康检查性能不佳")
        
        print("📈 健康检查平均时间: \(String(format: "%.3f", averageTime * 1000))ms")
        
        // 记录性能指标
        logger.performance(
            operation: "Health Check Benchmark",
            duration: averageTime,
            metadata: ["iterations": "\(iterations)", "total_time": "\(totalTime)"]
        )
    }
    
    // MARK: - Caching Performance Tests
    
    func testCachePerformance() async throws {
        try await serviceManager.initialize()
        let cacheManager = serviceManager.globalCacheManager
        
        // 测试缓存写入性能
        let writeStartTime = Date()
        for i in 0..<100 {
            let testData = "Test data \(i)".data(using: .utf8)!
            cacheManager?.notesCache.set(UUID(), testData as Any)
        }
        let writeTime = Date().timeIntervalSince(writeStartTime)
        
        XCTAssertLessThan(writeTime, 2.0, "缓存写入性能不佳")
        print("📈 缓存写入(100项): \(String(format: "%.3f", writeTime))秒")
        
        // 测试缓存读取性能
        let readStartTime = Date()
        for _ in 0..<100 {
            _ = cacheManager?.notesCache.get(UUID())
        }
        let readTime = Date().timeIntervalSince(readStartTime)
        
        XCTAssertLessThan(readTime, 1.0, "缓存读取性能不佳")
        print("📈 缓存读取(100项): \(String(format: "%.3f", readTime))秒")
    }
    
    func testCacheHitRate() async throws {
        try await serviceManager.initialize()
        let cacheManager = serviceManager.globalCacheManager
        
        // 预热缓存
        for i in 0..<50 {
            let testData = "Test data \(i)".data(using: .utf8)!
            cacheManager?.notesCache.set(UUID(), testData as Any)
        }
        
        // 测试命中率
        var hits = 0
        var misses = 0
        
        for i in 0..<100 {
            if i < 50 {
                // 前50次应该是缓存命中
                _ = cacheManager?.notesCache.get(UUID())
                hits += 1
            } else {
                // 后50次应该是缓存未命中
                _ = cacheManager?.notesCache.get(UUID(uuidString: "\(i)"))
                misses += 1
            }
        }
        
        let hitRate = Double(hits) / Double(hits + misses)
        
        // 命中率应该很高（至少80%）
        XCTAssertGreaterThanOrEqual(hitRate, 0.8, "缓存命中率过低")
        
        print("📊 缓存命中率: \(String(format: "%.1f", hitRate * 100))%")
    }
    
    // MARK: - Concurrent Performance Tests
    
    func testConcurrentServiceAccess() async throws {
        try await serviceManager.initialize()
        
        let concurrentOperations = 20
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOperations {
                group.addTask {
                    let healthReport = await self.serviceManager.performHealthCheck()
                    _ = healthReport.isHealthy
                }
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(concurrentOperations)
        
        // 并发访问的平均时间应该合理
        XCTAssertLessThan(averageTime, 0.2, "并发访问性能不佳")
        
        print("📈 并发访问(20次): \(String(format: "%.3f", totalTime))秒")
        print("📈 平均时间: \(String(format: "%.3f", averageTime * 1000))ms")
    }
    
    // MARK: - Stress Tests
    
    func testMemoryStressTest() async throws {
        try await serviceManager.initialize()
        
        // 创建大量笔记来测试内存使用
        let notesService = try await serviceManager.getNotesService()
        
        let stressTestStartTime = Date()
        
        // 创建1000个笔记
        for i in 0..<1000 {
            if i % 100 == 0 {
                print("📊 创建笔记进度: \(i)/1000")
            }
            
            _ = await notesService.createNote(
                title: "Stress Test Note \(i)",
                content: String(repeating: "Content ", count: 100) + "\(i)"
            )
        }
        
        let creationTime = Date().timeIntervalSince(stressTestStartTime)
        
        // 验证内存使用没有爆炸性增长
        let memoryAfterStress = getMemoryUsage()
        XCTAssertLessThan(memoryAfterStress, 500 * 1024 * 1024, "内存使用爆炸")
        
        print("📊 压力测试创建(1000笔记): \(String(format: "%.3f", creationTime))秒")
        print("📊 内存使用: \(memoryAfterStress / 1024 / 1024)MB")
    }
    
    // MARK: - Helper Methods
    
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

// MARK: - Extension for accessing private methods

private extension ApplicationServiceManager {
    func initializeBasicServices() async throws {
        // 公开测试需要的私有方法
        configurationManager = ConfigurationManagerEnhanced()
        structuredLogger = StructuredLogger()
        errorHandler = ErrorHandler.shared
    }
    
    func initializeCoreServices() async throws {
        taskManager = AsyncTaskManager.shared
        globalCacheManager = GlobalCacheManager.shared
        performanceMonitor = PerformanceMonitor()
    }
    
    func initializeAdvancedServices() async throws {
        notesService = NotesService()
    }
    
    func initializeSecurityAndMonitoring() async throws {
        securityManager = SecurityManager.shared
        securityManager?.startSecurityMonitoring()
    }
}
