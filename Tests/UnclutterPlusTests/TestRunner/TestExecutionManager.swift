import XCTest
import Foundation
import Combine

/// 测试执行管理器 - 运行所有测试并生成报告
@MainActor
final class TestExecutionManager: ObservableObject {
    static let shared = TestExecutionManager()
    
    // MARK: - Test Results
    
    @Published private(set) var testResults: [TestResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var currentTest: String?
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var testStatistics: TestStatistics?
    
    // MARK: - Test Execution
    
    /// 运行所有笔记服务测试
    func runNotesServiceTests() async -> TestStatistics {
        print("🧪 Starting NotesService tests...")
        
        let testCase = NotesServiceTests()
        testCase.setUp()
        
        isRunning = true
        testResults.removeAll()
        
        let testMethods = NotesServiceTests.allTests
        let totalTests = testMethods.count
        
        var passedTests: Int = 0
        var failedTests: Int = 0
        var skippedTests: Int = 0
        var totalDuration: TimeInterval = 0
        
        for (index, (testName, testMethod) in testMethods.enumerated() {
            currentTest = testName
            progress = Double(index) / Double(totalTests)
            
            let startTime = Date()
            
            do {
                try await testMethod(testCase)()
                passedTests += 1
                print("✅ \(testName) passed")
                
                // 记录成功的测试
                let result = TestResult(
                    testName: testName,
                    suiteName: "NotesService",
                    status: .passed,
                    duration: Date().timeIntervalSince(startTime),
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                )
                testResults.append(result)
                
            } catch {
                failedTests += 1
                print("❌ \(testName) failed: \(error)")
                
                // 记录失败的测试
                let result = TestResult(
                    testName: testName,
                    suiteName: "NotesService",
                    status: .failed,
                    duration: Date().timeIntervalSince(startTime),
                    memoryUsage: nil,
                    error: error,
                    timestamp: Date()
                )
                testResults.append(result)
            }
            
            totalDuration += Date().timeIntervalSince(startTime)
        }
        
        testCase.tearDown()
        
        isRunning = false
        currentTest = nil
        progress = 1.0
        
        // 计算统计信息
        testStatistics = TestStatistics(
            totalTests: totalTests,
            passed: passedTests,
            failed: failedTests,
            skipped: skippedTests,
            totalDuration: totalDuration,
            averageDuration: totalDuration / Double(totalTests),
            successRate: totalTests > 0 ? Double(passedTests) / Double(totalTests) : 0,
            memoryUsage: nil
        )
        
        print("📊 NotesService tests completed: \(passedTests)/\(totalTests) passed")
        return testStatistics!
    }
    
    /// 运行所有核心组件测试
    func runCoreComponentTests() async -> TestStatistics {
        print("🔧 Starting core component tests...")
        
        var allResults: [TestResult] = []
        
        // 测试统一存储协议
        let storageResults = await testUnifiedStorageProtocol()
        allResults.append(contentsOf: storageResults)
        
        // 测试缓存管理器
        let cacheResults = await testCacheManager()
        allResults.append(contentsOf: cacheResults)
        
        // 测试错误处理系统
        let errorResults = await testErrorHandling()
        allResults.append(contentsOf: errorResults)
        
        // 测试异步任务管理器
        let asyncResults = await testAsyncTaskManager()
        allResults.append(contentsOf: asyncResults)
        
        // 测试安全管理器
        let securityResults = await testSecurityManager()
        allResults.append(contentsOf: securityResults)
        
        return TestStatistics(results: allResults)
    }
    
    /// 运行性能基准测试
    func runPerformanceBenchmarks() async -> PerformanceBenchmarkResults {
        print("⚡ Starting performance benchmarks...")
        
        var results = PerformanceBenchmarkResults()
        
        // 笔记创建性能测试
        let noteCreationBenchmark = await benchmarkNoteCreation()
        results.noteCreationBenchmark = noteCreationBenchmark
        
        // 搜索性能测试
        let searchBenchmark = await benchmarkSearch()
        results.searchBenchmark = searchBenchmark
        
        // 内存使用测试
        let memoryBenchmark = await benchmarkMemoryUsage()
        results.memoryBenchmark = memoryBenchmark
        
        // 缓存性能测试
        let cacheBenchmark = await benchmarkCachePerformance()
        results.cacheBenchmark = cacheBenchmark
        
        print("🏁 Performance benchmarks completed")
        return results
    }
    
    // MARK: - Individual Component Tests
    
    private func testUnifiedStorageProtocol() async -> [TestResult] {
        var results: [TestResult] = []
        
        do {
            let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)
            
            // 测试创建笔记
            let testNote = Note(title: "Test Storage Note", content: "Storage test content")
            let createResult = await storage.create([testNote])
            
            if case .success = createResult {
                results.append(TestResult(
                    testName: "testUnifiedStorageCreate",
                    suiteName: "Storage",
                    status: .passed,
                    duration: 0.1,
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                ))
            } else {
                throw NSError(domain: "Test", code: -1)
            }
            
            // 测试读取笔记
            let readResult = await storage.read(id: testNote.id)
            if case .success(let note) = readResult, note != nil {
                results.append(TestResult(
                    testName: "testUnifiedStorageRead",
                    suiteName: "Storage",
                    status: .passed,
                    duration: 0.1,
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                ))
            } else {
                throw NSError(domain: "Test", code: -2)
            }
            
        } catch {
            results.append(TestResult(
                testName: "testUnifiedStorage",
                suiteName: "Storage",
                status: .failed,
                duration: 0.1,
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            ))
        }
        
        return results
    }
    
    private func testCacheManager() async -> [TestResult] {
        var results: [TestResult] = []
        
        do {
            let cache = IntelligentCacheManager<String, String>(name: "TestCache")
            
            // 测试缓存设置和获取
            cache.set("test_key", "test_value")
            let cachedValue = cache.get("test_key") as? String
            
            if cachedValue == "test_value" {
                results.append(TestResult(
                    testName: "testCacheSetGet",
                    suiteName: "Cache",
                    status: .passed,
                    duration: 0.05,
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                ))
            } else {
                throw NSError(domain: "Test", code: -1)
            }
            
            // 测试缓存清理
            cache.clear()
            let clearedValue = cache.get("test_key") as? String
            
            if clearedValue == nil {
                results.append(TestResult(
                    testName: "testCacheClear",
                    suiteName: "Cache",
                    status: .passed,
                    duration: 0.05,
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                ))
            } else {
                throw NSError(domain: "Test", code: -2)
            }
            
        } catch {
            results.append(TestResult(
                testName: "testCacheManager",
                suiteName: "Cache",
                status: .failed,
                duration: 0.1,
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            ))
        }
        
        return results
    }
    
    private func testErrorHandling() async -> [TestResult] {
        var results: [TestResult] = []
        
        do {
            // 测试错误构造
            let storageError = ErrorBuilder.storage("Test storage error")
            let appError = ErrorConverter.fromStorageError(.itemNotFound(id: UUID()))
            
            if appError.category == .storage {
                results.append(TestResult(
                    testName: "testErrorConstruction",
                    suiteName: "ErrorHandling",
                    status: .passed,
                    duration: 0.01,
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                ))
            } else {
                throw NSError(domain: "Test", code: -1)
            }
            
        } catch {
            results.append(TestResult(
                testName: "testErrorHandling",
                suiteName: "ErrorHandling",
                status: .failed,
                duration: 0.01,
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            ))
        }
        
        return results
    }
    
    private func testAsyncTaskManager() async -> [TestResult] {
        var results: [TestResult] = []
        
        do {
            let taskManager = AsyncTaskManager.shared
            
            // 测试异步任务执行
            let startTime = Date()
            let result = await taskManager.execute(name: "TestTask") {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                return "Test Result"
            }
            
            if case .success(let taskResult) = result, taskResult == "Test Result" {
                let duration = Date().timeIntervalSince(startTime)
                results.append(TestResult(
                    testName: "testAsyncTaskExecution",
                    suiteName: "AsyncTaskManager",
                    status: .passed,
                    duration: duration,
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                ))
            } else {
                throw NSError(domain: "Test", code: -1)
            }
            
        } catch {
            results.append(TestResult(
                testName: "testAsyncTaskManager",
                suiteName: "AsyncTaskManager",
                status: .failed,
                duration: 0.1,
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            ))
        }
        
        return results
    }
    
    private func testSecurityManager() async -> [TestResult] {
        var results: [TestResult] = []
        
        do {
            let securityManager = SecurityManager.shared
            
            // 测试SQL验证
            let validationResult = securityManager.validateOperation(.sqlQuery("SELECT * FROM notes"))
            
            if validationResult.isSafe {
                results.append(TestResult(
                    testName: "testSQLValidation",
                    suiteName: "SecurityManager",
                    status: .passed,
                    duration: 0.01,
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                ))
            } else {
                throw NSError(domain: "Test", code: -1)
            }
            
        } catch {
            results.append(TestResult(
                testName: "testSecurityManager",
                suiteName: "SecurityManager",
                status: .failed,
                duration: 0.01,
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            ))
        }
        
        return results
    }
    
    // MARK: - Performance Benchmarks
    
    private func benchmarkNoteCreation() async -> NoteCreationBenchmark {
        let noteCount = 100
        let startTime = Date()
        
        for i in 0..<noteCount {
            _ = await NotesService().createNote(
                title: "Benchmark Note \(i)",
                content: "Performance test content \(i)"
            )
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        return NoteCreationBenchmark(
            noteCount: noteCount,
            duration: duration,
            notesPerSecond: Double(noteCount) / duration,
            memoryUsed: getMemoryUsage()
        )
    }
    
    private func benchmarkSearch() async -> SearchBenchmark {
        let service = NotesService()
        
        // 创建测试数据
        for i in 0..<50 {
            _ = await service.createNote(
                title: "Search Test Note \(i)",
                content: "This is searchable content with keyword \(i % 10)"
            )
        }
        
        let searchCount = 20
        let startTime = Date()
        
        for i in 0..<searchCount {
            _ = await service.searchNotes(query: "keyword \(i % 10)")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        return SearchBenchmark(
            searchCount: searchCount,
            duration: duration,
            searchesPerSecond: Double(searchCount) / duration,
            memoryUsed: getMemoryUsage()
        )
    }
    
    private func benchmarkMemoryUsage() async -> MemoryBenchmark {
        let initialMemory = getMemoryUsage()
        
        // 创建大量数据
        let service = NotesService()
        for i in 0..<100 {
            _ = await service.createNote(
                title: "Memory Test Note \(i)",
                content: String(repeating: "Test content ", count: 500)
            )
        }
        
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        return MemoryBenchmark(
            initialMemory: initialMemory,
            peakMemory: peakMemory,
            memoryIncrease: memoryIncrease,
            notesCreated: 100
        )
    }
    
    private func benchmarkCachePerformance() async -> CacheBenchmark {
        let cache = IntelligentCacheManager<String, String>(name: "PerformanceTestCache")
        
        // 测试写入性能
        let writeStartTime = Date()
        for i in 0..<1000 {
            cache.set("key_\(i)", "value_\(i)")
        }
        let writeDuration = Date().timeIntervalSince(writeStartTime)
        
        // 测试读取性能
        let readStartTime = Date()
        for i in 0..<1000 {
            _ = cache.get("key_\(i % 1000)")
        }
        let readDuration = Date().timeIntervalSince(readStartTime)
        
        return CacheBenchmark(
            writeOperations: 1000,
            readOperations: 1000,
            writeDuration: writeDuration,
            readDuration: readDuration,
            writeOpsPerSecond: 1000.0 / writeDuration,
            readOpsPerSecond: 1000.0 / readDuration,
            memoryUsed: getMemoryUsage()
        )
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

// MARK: - Benchmark Results

struct PerformanceBenchmarkResults {
    var noteCreationBenchmark: NoteCreationBenchmark?
    var searchBenchmark: SearchBenchmark?
    var memoryBenchmark: MemoryBenchmark?
    var cacheBenchmark: CacheBenchmark?
    
    var description: String {
        """
        Performance Benchmarks:
        \(noteCreationBenchmark?.description ?? "Note creation: Not tested")
        \(searchBenchmark?.description ?? "Search: Not tested")
        \(memoryBenchmark?.description ?? "Memory: Not tested")
        \(cacheBenchmark?.description ?? "Cache: Not tested")
        """
    }
}

struct NoteCreationBenchmark {
    let noteCount: Int
    let duration: TimeInterval
    let notesPerSecond: Double
    let memoryUsed: Int64
    
    var description: String {
        "Note Creation: \(notesPerSecond) notes/second, Memory: \(memoryUsed / 1024 / 1024)MB"
    }
}

struct SearchBenchmark {
    let searchCount: Int
    let duration: TimeInterval
    let searchesPerSecond: Double
    let memoryUsed: Int64
    
    var description: String {
        "Search: \(searchesPerSecond) searches/second, Memory: \(memoryUsed / 1024 / 1024)MB"
    }
}

struct MemoryBenchmark {
    let initialMemory: Int64
    let peakMemory: Int64
    let memoryIncrease: Int64
    let notesCreated: Int
    
    var description: String {
        "Memory: \(memoryIncrease / 1024 / 1024)MB increase for \(notesCreated) notes"
    }
}

struct CacheBenchmark {
    let writeOperations: Int
    let readOperations: Int
    let writeDuration: TimeInterval
    let readDuration: TimeInterval
    let writeOpsPerSecond: Double
    let readOpsPerSecond: Double
    let memoryUsed: Int64
    
    var description: String {
        "Cache: \(writeOpsPerSecond)/sec writes, \(readOpsPerSecond)/sec reads, Memory: \(memoryUsed / 1024 / 1024)MB"
    }
}
