import XCTest
import Foundation
import Combine

@testable import UnclutterPlus

/// 性能基准测试
final class PerformanceBenchmarkTests: XCTestCase {
    var notesService: NotesService!
    var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        notesService = NotesService()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDownWithError() throws {
        notesService = nil
        cancellables = nil
        try super.tearDownWithError()
    }

    // MARK: - Startup Performance Tests

    func testNotesServiceInitialization() async throws {
        await MainActor.run {
            let startTime = Date()

            let service = NotesService()

            let endTime = Date()
            let startupTime = endTime.timeIntervalSince(startTime)

            // 初始化时间应该少于1秒
            XCTAssertLessThan(startupTime, 1.0, "初始化时间过长: \(startupTime)秒")

            print("📊 NotesService初始化时间: \(String(format: "%.3f", startupTime))秒")
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryUsageDuringOperations() async throws {
        let initialMemory = getMemoryUsage()

        // 执行大量操作
        for i in 0..<100 {
            _ = await notesService.createNote(
                title: "Memory Test Note \(i)",
                content: String(repeating: "Content ", count: 100)
            )
        }

        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory

        // 内存增长应该少于50MB
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "内存使用过高")

        print("📊 内存增长: \(memoryIncrease / 1024 / 1024)MB")
    }

    func testMemoryStabilityUnderLoad() async throws {
        // 模拟负载：多次执行操作
        var memories: [Int64] = []

        for _ in 0..<10 {
            _ = await notesService.createNote(title: "Load Test", content: "Content")
            memories.append(getMemoryUsage())

            // 稍微等待一下
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }

        // 检查内存是否稳定
        let maxMemory = memories.max() ?? 0
        let minMemory = memories.min() ?? 0
        let memoryVariation = maxMemory - minMemory

        // 内存变化应该小于10MB
        XCTAssertLessThan(memoryVariation, 10 * 1024 * 1024, "内存使用不稳定")

        print("📊 内存变化: \(memoryVariation / 1024 / 1024)MB")
    }

    // MARK: - Operation Performance Tests

    func testCreateNotePerformance() async throws {
        let noteCount = 50
        let startTime = Date()

        for i in 0..<noteCount {
            _ = await notesService.createNote(
                title: "Performance Test Note \(i)",
                content: "Content for note \(i)"
            )
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let notesPerSecond = Double(noteCount) / duration

        // 创建速度应该大于10笔记/秒
        XCTAssertGreaterThan(notesPerSecond, 10.0, "笔记创建性能不佳")

        print("📊 笔记创建性能: \(String(format: "%.2f", notesPerSecond)) 笔记/秒")
    }

    func testSearchPerformance() async throws {
        // 准备测试数据
        for i in 0..<50 {
            await notesService.createNote(
                title: "Search Test Note \(i)",
                content: "This is a searchable content with keyword \(i % 10)"
            )
        }

        let searchCount = 20
        let startTime = Date()

        for i in 0..<searchCount {
            _ = await notesService.searchNotes(query: "keyword \(i % 10)")
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let searchesPerSecond = Double(searchCount) / duration

        // 搜索速度应该大于10搜索/秒
        XCTAssertGreaterThan(searchesPerSecond, 10.0, "搜索性能不佳")

        print("📊 搜索性能: \(String(format: "%.2f", searchesPerSecond)) 搜索/秒")
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentOperations() async throws {
        let startTime = Date()

        await withTaskGroup(of: Void.self) { group in
            // 创建笔记任务
            for i in 0..<20 {
                group.addTask {
                    await self.notesService.createNote(
                        title: "Concurrent Test \(i)",
                        content: "Content \(i)"
                    )
                }
            }

            // 搜索任务
            for i in 0..<10 {
                group.addTask {
                    _ = await self.notesService.searchNotes(query: "Concurrent")
                }
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // 并发操作应该在5秒内完成
        XCTAssertLessThan(duration, 5.0, "并发操作时间过长: \(duration)秒")

        print("📊 并发操作性能: \(String(format: "%.2f", duration))秒")
    }

    // MARK: - Helper Methods

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Test Suite

extension PerformanceBenchmarkTests {
    static var allTests = [
        ("testNotesServiceInitialization", testNotesServiceInitialization),
        ("testMemoryUsageDuringOperations", testMemoryUsageDuringOperations),
        ("testMemoryStabilityUnderLoad", testMemoryStabilityUnderLoad),
        ("testCreateNotePerformance", testCreateNotePerformance),
        ("testSearchPerformance", testSearchPerformance),
        ("testConcurrentOperations", testConcurrentOperations)
    ]
}
