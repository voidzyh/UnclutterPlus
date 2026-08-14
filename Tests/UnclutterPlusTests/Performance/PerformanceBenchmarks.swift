import Foundation
import XCTest
@testable import UnclutterPlus

/// 性能基准测试 - 验证关键操作的性能指标
@MainActor
final class PerformanceBenchmarks: XCTestCase {

    // MARK: - Properties

    private var testStorage: UnifiedNoteStorage!
    private var testNotes: [Note] = []

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // 创建临时存储配置
        let config = StorageConfiguration(
            baseURL: FileManager.default.temporaryDirectory.appendingPathComponent("PerformanceTests"),
            cacheSizeLimit: 100 * 1024 * 1024  // 100MB
        )

        // 删除旧数据
        try? FileManager.default.removeItem(at: config.baseURL)

        // 创建存储
        testStorage = UnifiedNoteStorage(configuration: config)

        // 生成测试笔记
        testNotes = generateTestNotes(count: 1000)
    }

    override func tearDown() async throws {
        // 清理测试数据
        try? await testStorage?.clear()
        testStorage = nil
        testNotes.removeAll()

        try await super.tearDown()
    }

    // MARK: - Search Performance Tests

    /// 测试搜索性能 - 1000 条笔记搜索应在 10ms 内完成
    func testSearchPerformance() async throws {
        // 1. 准备测试数据 - 保存 1000 条笔记
        let saveStart = Date()
        for note in testNotes {
            try await testStorage.create([note])
        }
        let saveDuration = Date().timeIntervalSince(saveStart)
        print("💾 保存 1000 条笔记耗时: \(String(format: "%.2f", saveDuration * 1000))ms")

        // 2. 测试搜索性能
        let queries = ["测试", "重要", "Swift", "macOS", "笔记", "内容"]

        var totalSearchTime: TimeInterval = 0
        var iterations = 0

        for query in queries {
            let start = Date()
            _ = try await testStorage.search(query: query)
            let duration = Date().timeIntervalSince(start)
            totalSearchTime += duration
            iterations += 1

            print("🔍 搜索 '\(query)' 耗时: \(String(format: "%.3f", duration * 1000))ms")
        }

        let avgSearchTime = (totalSearchTime / Double(iterations)) * 1000 // 转换为毫秒

        print("📊 平均搜索时间: \(String(format: "%.3f", avgSearchTime))ms")

        // 性能断言：平均搜索时间应 < 10ms
        XCTAssertLessThan(avgSearchTime, 10.0,
                          "搜索性能未达标：平均 \(String(format: "%.3f", avgSearchTime))ms，要求 < 10ms")

        // 额外断言：最慢搜索也应 < 50ms（预计算优化后应该很快）
        let maxSearchTime = totalSearchTime * 1000
        XCTAssertLessThan(maxSearchTime, 50.0,
                          "最慢搜索时间过长: \(String(format: "%.3f", maxSearchTime))ms")
    }

    /// 测试大量笔记下的搜索性能
    func testLargeDatasetSearchPerformance() async throws {
        // 保存 1000 条笔记
        for note in testNotes {
            try await testStorage.create([note])
        }

        // 测试不同复杂度的查询
        let testCases = [
            ("单字查询", "测"),
            ("双字查询", "测试"),
            ("长查询", "这是一个重要的测试笔记"),
            ("英文查询", "Swift"),
            ("混合查询", "Swift macOS")
        ]

        for (name, query) in testCases {
            let start = Date()
            let results = try await testStorage.search(query: query)
            let duration = Date().timeIntervalSince(start) * 1000

            print("\(name): '\(query)' - 找到 \(results.count) 条结果，耗时 \(String(format: "%.3f", duration))ms")

            // 所有查询都应在 20ms 内完成
            XCTAssertLessThan(duration, 20.0,
                              "\(name) 性能未达标: \(String(format: "%.3f", duration))ms")
        }
    }

    // MARK: - Batch Operations Performance Tests

    /// 测试批量保存性能 - 100 个笔记应在 1 秒内完成
    func testBatchSavePerformance() async throws {
        let batchSize = 100
        let notesToSave = Array(testNotes.prefix(batchSize))

        let start = Date()
        for note in notesToSave {
            try await testStorage.create([note])
        }
        let duration = Date().timeIntervalSince(start)

        print("💾 批量保存 \(batchSize) 条笔记耗时: \(String(format: "%.3f", duration * 1000))ms")

        // 性能断言：批量保存应在 1 秒内完成
        XCTAssertLessThan(duration, 1.0,
                          "批量保存性能未达标: \(String(format: "%.3f", duration))s，要求 < 1s")

        // 验证保存成功
        let indexes = try await testStorage.getAllIndexes()
        XCTAssertEqual(indexes.count, batchSize,
                      "批量保存数量不匹配: 预期 \(batchSize)，实际 \(indexes.count)")
    }

    /// 测试并发批量操作性能
    func testConcurrentBatchOperationsPerformance() async throws {
        let operationCount = 50
        let notesToSave = Array(testNotes.prefix(operationCount))

        let start = Date()

        // 并发执行多个操作
        await withTaskGroup(of: Void.self) { group in
            for note in notesToSave {
                group.addTask {
                    try? await self.testStorage.create([note])
                }
            }
        }

        let duration = Date().timeIntervalSince(start)

        print("⚡️ 并发保存 \(operationCount) 条笔记耗时: \(String(format: "%.3f", duration * 1000))ms")

        // 并发操作应更快，但仍应在合理范围内（< 2s）
        XCTAssertLessThan(duration, 2.0,
                          "并发批量操作性能未达标: \(String(format: "%.3f", duration))s")
    }

    /// 测试批量删除性能
    func testBatchDeletePerformance() async throws {
        // 创建独立的临时存储
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("deleteTest_\(UUID().uuidString)")
        let config = StorageConfiguration(baseURL: tempDir, cacheSizeLimit: 100 * 1024 * 1024)
        let deleteTestStorage = UnifiedNoteStorage(configuration: config)

        // 1. 先保存 100 条笔记
        let notesToDelete = Array(testNotes.prefix(100))
        for note in notesToDelete {
            try await deleteTestStorage.create([note])
        }

        // 2. 测试批量删除性能
        let idsToDelete = notesToDelete.map { $0.id }

        let start = Date()
        try await deleteTestStorage.delete(ids: idsToDelete)
        let duration = Date().timeIntervalSince(start)

        print("🗑️ 批量删除 \(idsToDelete.count) 条笔记耗时: \(String(format: "%.3f", duration * 1000))ms")

        // 性能断言：批量删除应在 1 秒内完成
        XCTAssertLessThan(duration, 1.0,
                          "批量删除性能未达标: \(String(format: "%.3f", duration))s")

        // 验证删除成功
        let remainingIndexes = try await deleteTestStorage.getAllIndexes()
        XCTAssertEqual(remainingIndexes.count, 0,
                      "批量删除后应无剩余笔记，实际剩余: \(remainingIndexes.count)")

        // 清理
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Cache Performance Tests

    /// 测试缓存命中率 - LRU 缓存应达到 80% 以上命中率
    func testCacheHitRate() async throws {
        let notes = Array(testNotes.prefix(100))
        for note in notes {
            try await testStorage.create([note])
        }

        let cache = LRUCache<UUID, Note>(maxSize: 10)
        let hotNoteIds = Array(notes.prefix(10).map { $0.id })

        for id in hotNoteIds {
            if let note = notes.first(where: { $0.id == id }) {
                await cache.set(id, note)
            }
        }

        let hitCount = 100
        for _ in 0..<hitCount {
            for id in hotNoteIds {
                _ = await cache.get(id)
            }
        }

        let stats = await cache.getStatistics()

        print("📈 缓存统计:")
        print("   - 命中率: \(String(format: "%.2f%%", stats.hitRate * 100))")
        print("   - 命中次数: \(stats.hitCount)")
        print("   - 未命中次数: \(stats.missCount)")
        print("   - 淘汰次数: \(stats.evictionCount)")

        XCTAssertGreaterThan(stats.hitRate, 0.8,
                            "缓存命中率未达标: \(String(format: "%.2f%%", stats.hitRate * 100))，要求 > 80%")
    }

    // MARK: - Logger Performance Tests

    /// 测试日志系统性能 - 1000 次日志调用应在 100ms 内完成
    func testLoggerPerformance() async throws {
        let iterations = 1000

        let originalLogLevel = logger.currentLevel
        logger.setLogLevel(.warning)

        let start = Date()
        for i in 0..<iterations {
            logger.debug("这是第 \(i) 条调试日志", category: "Performance")
        }
        let debugDuration = Date().timeIntervalSince(start) * 1000

        print("📝 \(iterations) 条 debug 日志耗时: \(String(format: "%.2f", debugDuration))ms")
        XCTAssertLessThan(debugDuration, 100.0,
                          "Debug 日志性能未达标: \(String(format: "%.2f", debugDuration))ms")

        let infoStart = Date()
        for i in 0..<iterations {
            logger.info("这是第 \(i) 条信息日志", category: "Performance")
        }
        let infoDuration = Date().timeIntervalSince(infoStart) * 1000

        print("📝 \(iterations) 条 info 日志耗时: \(String(format: "%.2f", infoDuration))ms")
        XCTAssertLessThan(infoDuration, 100.0,
                          "Info 日志性能未达标: \(String(format: "%.2f", infoDuration))ms")

        logger.setLogLevel(originalLogLevel)
    }

    /// 测试错误处理性能 - 100 次错误处理应在 50ms 内完成
    func testErrorHandlingPerformance() async throws {
        let iterations = 100

        // 测试 GlobalErrorHandler 性能
        let start = Date()
        for i in 0..<iterations {
            let error = StorageError.notFound(UUID())
            await GlobalErrorHandler.shared.handle(
                error,
                context: "性能测试 #\(i)",
                showAlert: false  // 不显示对话框
            )
        }
        let duration = Date().timeIntervalSince(start) * 1000

        print("⚠️ \(iterations) 次错误处理耗时: \(String(format: "%.2f", duration))ms")

        // 错误处理应在 50ms 内完成
        XCTAssertLessThan(duration, 50.0,
                          "错误处理性能未达标: \(String(format: "%.2f", duration))ms")
    }

    // MARK: - Memory Performance Tests

    /// 测试内存使用 - 1000 条笔记的内存增长应 < 100MB
    func testMemoryUsage() async throws {
        // 记录初始内存
        let initialMemory = getMemoryUsage()

        // 保存 1000 条笔记到内存数组
        var allNotes: [Note] = []
        for note in testNotes {
            try await testStorage.create([note])
            allNotes.append(note)
        }

        // 记录最终内存
        let finalMemory = getMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory

        print("💾 内存使用统计:")
        print("   - 初始内存: \(formatBytes(initialMemory))")
        print("   - 最终内存: \(formatBytes(finalMemory))")
        print("   - 内存增长: \(formatBytes(memoryGrowth))")
        print("   - 笔记数量: \(allNotes.count)")

        // 性能断言：内存增长应 < 100MB
        let maxAllowedGrowth: Int64 = 100 * 1024 * 1024 // 100MB
        XCTAssertLessThan(memoryGrowth, maxAllowedGrowth,
                          "内存使用过多: \(formatBytes(memoryGrowth))，要求 < 100MB")
    }

    // MARK: - 剪贴板万级数据基准（P0 性能达标）

    /// 10,000 条剪贴板历史：索引加载 / VM 全量加载 / 搜索过滤
    func testClipboardTenThousandItemsPerformance() async throws {
        let storage = MockGenericStorage<ClipboardItem, ClipboardIndex>()
        storage.indexFactory = { ClipboardIndex(from: $0) }

        // 1. 准备 10,000 条数据（直接进存储，绕过逐条 addItem 的开销）
        let batchStart = Date()
        var items: [ClipboardItem] = []
        for index in 0..<10_000 {
            items.append(ClipboardItem(
                content: .text("clipboard item \(index) swift macOS 开发笔记"),
                timestamp: Date(timeIntervalSinceNow: -Double(index))
            ))
        }
        try await storage.create(items)
        let batchDuration = Date().timeIntervalSince(batchStart) * 1000
        print("📦 内存构建 10,000 项耗时: \(String(format: "%.1f", batchDuration))ms")

        let repository = ClipboardRepository(storage: storage)

        // 2. 索引加载基准
        let loadStart = Date()
        await repository.loadIndexes()
        let loadDuration = Date().timeIntervalSince(loadStart) * 1000
        print("📇 10,000 项索引加载耗时: \(String(format: "%.1f", loadDuration))ms")
        XCTAssertEqual(repository.clipboardIndexes.count, 10_000)
        XCTAssertLessThan(loadDuration, 500, "索引加载未达标：\(loadDuration)ms")

        // 3. VM 全量加载基准（逐条 getItem 初始加载）
        let vm = ModernClipboardViewModel(repository: repository)
        let vmStart = Date()
        while vm.clipboardItems.count < 10_000 {
            if Date().timeIntervalSince(vmStart) > 10 {
                XCTFail("VM 加载 10,000 项超时")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let vmDuration = Date().timeIntervalSince(vmStart) * 1000
        print("🖥️ VM 加载 10,000 项耗时: \(String(format: "%.1f", vmDuration))ms")
        XCTAssertLessThan(vmDuration, 5000, "VM 加载未达标：\(vmDuration)ms")

        // 4. 搜索过滤基准（含防抖等待）
        let filterStart = Date()
        vm.searchText = "swift"
        while vm.filteredItems.count < 10_000 {
            if Date().timeIntervalSince(filterStart) > 5 {
                XCTFail("过滤 10,000 项超时")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let filterDuration = Date().timeIntervalSince(filterStart) * 1000
        print("🔍 10,000 项搜索过滤耗时（含防抖）: \(String(format: "%.1f", filterDuration))ms")
        XCTAssertLessThan(filterDuration, 2000, "搜索过滤未达标：\(filterDuration)ms")
    }

    // MARK: - Helper Methods

    /// 生成测试笔记
    private func generateTestNotes(count: Int) -> [Note] {
        var notes: [Note] = []
        let titles = ["重要笔记", "测试文档", "Swift 开发", "macOS 技巧", "个人随笔"]
        let contents = [
            "这是一个测试笔记的内容，包含了一些重要的信息。",
            "Swift 是苹果公司开发的一种强大的编程语言。",
            "macOS 是苹果公司的桌面操作系统，具有强大的功能。",
            "这是另一篇测试笔记，用于验证系统的性能和稳定性。",
            "笔记应用应该支持 Markdown 语法，方便用户编写和编辑。"
        ]
        let tags = [["工作", "重要"], ["测试"], ["开发", "Swift"], ["macOS", "技巧"], ["个人"]]

        for i in 0..<count {
            let note = Note(
                title: "\(titles[i % titles.count]) #\(i)",
                content: contents[i % contents.count],
                tags: tags[i % tags.count]
            )
            notes.append(note)
        }

        return notes
    }

    /// 获取当前内存使用量（字节）
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }

    /// 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - POSIX Functions Import

import Darwin
import MachO

// task_info 函数已由 Darwin 模块提供，无需额外声明
