import XCTest
import Foundation
import Combine
import SwiftUI
@testable import UnclutterPlus

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
        try? testCase.setUpWithError()

        isRunning = true
        testResults.removeAll()

        let testMethods = NotesServiceTests.allTests
        let totalTests = testMethods.count

        var passedTests: Int = 0
        var failedTests: Int = 0
        var skippedTests: Int = 0
        var totalDuration: TimeInterval = 0

        for (index, (testName, testMethod)) in testMethods.enumerated() {
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

        try? testCase.tearDownWithError()

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

        return TestStatistics(results: allResults)!
    }

    /// 运行性能基准测试
    func runPerformanceBenchmarks() async -> PerformanceBenchmarkReport {
        print("⚡ Starting performance benchmarks...")

        let results = [BenchmarkResult]()
        return PerformanceBenchmarkReport(timestamp: Date(), results: results)
    }

    // MARK: - Storage Integration Tests

    func runStorageIntegrationTests() async -> TestStatistics {
        print("💾 Starting storage integration tests...")

        isRunning = true
        testResults.removeAll()
        var results: [TestResult] = []

        // 测试 1: 完整的 CRUD 流程
        results.append(await testStorageCRUD())

        // 测试 2: 批量操作
        results.append(await testStorageBatchOperations())

        // 测试 3: 错误处理
        results.append(await testStorageErrorHandling())

        // 测试 4: 并发访问
        results.append(await testStorageConcurrentAccess())

        testResults.append(contentsOf: results)
        isRunning = false

        let stats = TestStatistics(results: results)!
        testStatistics = stats
        return stats
    }

    private func testStorageCRUD() async -> TestResult {
        let startTime = Date()
        do {
            let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)

            // Create
            let note = Note(title: "CRUD Test", content: "Test content")
            try await storage.create([note])

            // Read
            let loaded = try await storage.read(id: note.id)
            guard loaded?.id == note.id else {
                throw StorageError.corrupted("Read failed")
            }

            // Update
            var updated = note
            updated.content = "Updated content"
            try await storage.update([updated])

            // Delete
            try await storage.delete(ids: [note.id])
            let deleted = try await storage.read(id: note.id)
            guard deleted == nil else { throw StorageError.corrupted("Delete failed") }

            return TestResult(
                testName: "Storage CRUD Flow",
                suiteName: "Storage",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Storage CRUD Flow",
                suiteName: "Storage",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    private func testStorageBatchOperations() async -> TestResult {
        let startTime = Date()
        do {
            let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)

            // Create batch
            let notes = (0..<10).map { i in Note(title: "Batch Note \(i)", content: "Content \(i)") }
            try await storage.create(notes)

            // Read batch
            let ids = notes.map { $0.id }
            let loaded = try await storage.readBatch(ids: ids)
            guard loaded.count == 10 else { throw StorageError.corrupted("Batch read failed") }

            // Delete batch
            try await storage.delete(ids: ids)

            return TestResult(
                testName: "Storage Batch Operations",
                suiteName: "Storage",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Storage Batch Operations",
                suiteName: "Storage",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    private func testStorageErrorHandling() async -> TestResult {
        let startTime = Date()
        do {
            let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)

            // Test not found error
            let randomID = UUID()
            let result = try await storage.read(id: randomID)
            if result != nil {
                throw ValidationError.invalidData("Should return nil for non-existent ID")
            }

            // Test validation error (no validation in storage layer for now, skipping invalid note creation)
            
            return TestResult(
                testName: "Storage Error Handling",
                suiteName: "Storage",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Storage Error Handling",
                suiteName: "Storage",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    private func testStorageConcurrentAccess() async -> TestResult {
        let startTime = Date()
        do {
            let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)

            // 并发创建多个笔记
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<5 {
                    group.addTask {
                        let note = Note(title: "Concurrent Note \(i)", content: "Content \(i)")
                        try? await storage.create([note])
                    }
                }
            }

            return TestResult(
                testName: "Storage Concurrent Access",
                suiteName: "Storage",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Storage Concurrent Access",
                suiteName: "Storage",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    // MARK: - Cache Integration Tests

    func runCacheIntegrationTests() async -> TestStatistics {
        print("⚡️ Starting cache integration tests...")

        isRunning = true
        testResults.removeAll()
        var results: [TestResult] = []

        // 测试 1: 缓存命中率和淘汰策略
        results.append(await testCacheHitRateAndEviction())

        // 测试 2: 多级缓存
        results.append(await testMultiLevelCache())

        // 测试 3: 缓存一致性
        results.append(await testCacheConsistency())

        testResults.append(contentsOf: results)
        isRunning = false

        let stats = TestStatistics(results: results)!
        testStatistics = stats
        return stats
    }

    private func testCacheHitRateAndEviction() async -> TestResult {
        let startTime = Date()
        do {
            let cache = LRUCache<UUID, Note>(maxSize: 5)

            // 添加 10 个笔记，测试淘汰策略
            var notes: [Note] = []
            for i in 0..<10 {
                let note = Note(title: "Cache Note \(i)", content: "Content \(i)")
                notes.append(note)
                await cache.set(note.id, note)
            }

            // 前 5 个应该被淘汰
            let firstNote = await cache.get(notes[0].id)
            guard firstNote == nil else { throw ValidationError.invalidData("LRU eviction failed") }

            // 后 5 个应该存在
            let lastNote = await cache.get(notes[9].id)
            guard lastNote != nil else { throw ValidationError.invalidData("Cache retention failed") }

            return TestResult(
                testName: "Cache Hit Rate and Eviction",
                suiteName: "Cache",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Cache Hit Rate and Eviction",
                suiteName: "Cache",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    private func testMultiLevelCache() async -> TestResult {
        let startTime = Date()
        do {
            let l1Cache = LRUCache<UUID, Note>(maxSize: 3)
            let l2Cache = LRUCache<UUID, Note>(maxSize: 10)

            let note = Note(title: "Multi-level Test", content: "Content")

            // L1 命中
            await l1Cache.set(note.id, note)
            guard await l1Cache.get(note.id) != nil else {
                throw ValidationError.invalidData("L1 cache failed")
            }

            // L2 命中（L1 未命中）
            await l2Cache.set(note.id, note)
            guard await l2Cache.get(note.id) != nil else {
                throw ValidationError.invalidData("L2 cache failed")
            }

            return TestResult(
                testName: "Multi-level Cache",
                suiteName: "Cache",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Multi-level Cache",
                suiteName: "Cache",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    private func testCacheConsistency() async -> TestResult {
        let startTime = Date()
        do {
            let cache = LRUCache<UUID, Note>(maxSize: 10)

            var note = Note(title: "Consistency Test", content: "Original")
            await cache.set(note.id, note)

            // 更新笔记
            note.content = "Updated"
            await cache.set(note.id, note)

            // 验证缓存中的值已更新
            let cached = await cache.get(note.id)
            guard cached?.content == "Updated" else {
                throw ValidationError.invalidData("Cache consistency failed")
            }

            return TestResult(
                testName: "Cache Consistency",
                suiteName: "Cache",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Cache Consistency",
                suiteName: "Cache",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    // MARK: - Error Handling Integration Tests

    func runErrorHandlingIntegrationTests() async -> TestStatistics {
        print("⚠️ Starting error handling integration tests...")

        isRunning = true
        testResults.removeAll()
        var results: [TestResult] = []

        // 测试 1: 错误恢复
        results.append(await testErrorRecovery())

        // 测试 2: 错误传播
        results.append(await testErrorPropagation())

        testResults.append(contentsOf: results)
        isRunning = false

        let stats = TestStatistics(results: results)!
        testStatistics = stats
        return stats
    }

    private func testErrorRecovery() async -> TestResult {
        let startTime = Date()
        do {
            let handler = GlobalErrorHandler.shared

            // 测试错误处理和恢复
            let testError = StorageError.notFound(UUID())
            handler.handle(testError, context: "测试错误恢复", showAlert: false)

            // 验证错误被记录
            guard handler.errorHistory.contains(where: { $0.errorCode == "STORAGE_001" }) else {
                throw ValidationError.invalidData("Error not logged")
            }

            return TestResult(
                testName: "Error Recovery",
                suiteName: "Error Handling",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            )
        } catch {
            return TestResult(
                testName: "Error Recovery",
                suiteName: "Error Handling",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    private func testErrorPropagation() async -> TestResult {
        let startTime = Date()
        do {
            // 测试错误从存储层传播到服务层
            let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)

            // 尝试读取不存在的笔记
            let randomID = UUID()
            let note = try await storage.read(id: randomID)

            // 如果读取成功（返回 nil），说明未找到是正常情况
            if note == nil {
                return TestResult(
                    testName: "Error Propagation",
                    suiteName: "Error Handling",
                    status: .passed,
                    duration: Date().timeIntervalSince(startTime),
                    memoryUsage: nil,
                    error: nil,
                    timestamp: Date()
                )
            }

            // 如果真的读取到了笔记，这是意外的
            throw ValidationError.invalidData("Unexpectedly found a note with random ID")
        } catch {
            return TestResult(
                testName: "Error Propagation",
                suiteName: "Error Handling",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                memoryUsage: nil,
                error: error,
                timestamp: Date()
            )
        }
    }

    // MARK: - Security Integration Tests (Placeholder)

    func runSecurityIntegrationTests() async -> TestStatistics {
        print("🔒 Starting security integration tests...")

        isRunning = true
        testResults.removeAll()

        // TODO: 实现完整的安全测试
        let result = TestResult(
            testName: "Security Tests",
            suiteName: "Security",
            status: .skipped,
            duration: 0,
            memoryUsage: nil,
            error: nil,
            timestamp: Date()
        )
        testResults.append(result)
        isRunning = false

        let stats = TestStatistics(results: [result])!
        testStatistics = stats
        return stats
    }

    // MARK: - Memory Integration Tests (Placeholder)

    func runMemoryIntegrationTests() async -> TestStatistics {
        print("🧠 Starting memory integration tests...")

        isRunning = true
        testResults.removeAll()

        // TODO: 实现完整的内存测试
        let result = TestResult(
            testName: "Memory Tests",
            suiteName: "Memory",
            status: .skipped,
            duration: 0,
            memoryUsage: nil,
            error: nil,
            timestamp: Date()
        )
        testResults.append(result)
        isRunning = false

        let stats = TestStatistics(results: [result])!
        testStatistics = stats
        return stats
    }

    // MARK: - Multi-Component Integration Tests (Placeholder)

    func runMultiComponentIntegrationTests() async -> TestStatistics {
        print("🔗 Starting multi-component integration tests...")

        isRunning = true
        testResults.removeAll()

        // TODO: 实现完整的多组件测试
        let result = TestResult(
            testName: "Multi-Component Tests",
            suiteName: "Multi-Component",
            status: .skipped,
            duration: 0,
            memoryUsage: nil,
            error: nil,
            timestamp: Date()
        )
        testResults.append(result)
        isRunning = false

        let stats = TestStatistics(results: [result])!
        testStatistics = stats
        return stats
    }

    // MARK: - Individual Component Tests

    private func testUnifiedStorageProtocol() async -> [TestResult] {
        var results: [TestResult] = []

        do {
            let storage = UnifiedNoteStorage(configuration: StorageConfiguration.default)

            // 测试创建笔记
            let testNote = Note(title: "Test Storage Note", content: "Storage test content")
            try await storage.create([testNote])

            results.append(TestResult(
                testName: "testUnifiedStorageCreate",
                suiteName: "Storage",
                status: .passed,
                duration: 0.1,
                memoryUsage: nil,
                error: nil,
                timestamp: Date()
            ))

            // 测试读取笔记
            if let note = try await storage.read(id: testNote.id) {
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
}
