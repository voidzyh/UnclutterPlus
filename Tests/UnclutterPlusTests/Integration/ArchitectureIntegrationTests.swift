import XCTest
import Foundation
@testable import UnclutterPlus
import Combine

/// 架构集成测试 - 验证新组件协作
@MainActor
final class ArchitectureIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var unifiedStorageManager: UnifiedStorageManager!
    var notesService: NotesService!
    var globalCacheManager: GlobalCacheManager!
    var securityManager: SecurityManager!
    var asyncTaskManager: AsyncTaskManager!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 初始化集成的组件
        unifiedStorageManager = UnifiedStorageManager.shared
        notesService = unifiedStorageManager.notesService
        globalCacheManager = GlobalCacheManager.shared
        securityManager = SecurityManager.shared
        asyncTaskManager = AsyncTaskManager.shared
        cancellables = Set<AnyCancellable>()
        
        print("🔧 Architecture Integration Test Setup Completed")
    }
    
    override func tearDown() {
        // 清理测试数据
        Task {
            await clearTestData()
        }
        
        unifiedStorageManager = nil
        notesService = nil
        globalCacheManager = nil
        securityManager = nil
        asyncTaskManager = nil
        cancellables = nil
        
        print("🧹 Architecture Integration Test Teardown Completed")
    }
    
    // MARK: - Integration Test Cases
    
    /// 测试NotesService与UnifiedStorage的集成
    func testNotesServiceWithUnifiedStorage() async throws {
        print("🔗 Testing NotesService + UnifiedStorage integration...")
        
        // Given
        let testNote = Note(title: "Integration Test Note", content: "Testing storage integration")
        
        // When - 通过NotesService创建笔记（应该使用UnifiedStorage）
        let createResult = await notesService.createNote(
            title: testNote.title,
            content: testNote.content,
            tags: testNote.tags
        )
        
        // Then
        XCTAssertTrue(createResult, "NotesService应该成功创建笔记")
        
        let noteIndexes = notesService.noteIndexes
        XCTAssertFalse(noteIndexes.isEmpty, "笔记索引应该包含新笔记")
        
        // 验证数据持久化
        let createdNoteIndex = noteIndexes.first!
        let fullNote = await notesService.getNote(id: createdNoteIndex.id)
        XCTAssertNotNil(fullNote, "应该能够获取完整的笔记")
        XCTAssertEqual(fullNote?.title, testNote.title, "笔记标题应该匹配")
        
        // 验证缓存同步
        let cachedNote = globalCacheManager.getCachedNote(id: createdNoteIndex.id)
        XCTAssertNotNil(cachedNote, "全局缓存应该包含笔记")
        
        print("✅ NotesService + UnifiedStorage integration passed")
    }
    
    /// 测试缓存与存储的集成
    func testCacheWithStorageSync() async throws {
        print("🔗 Testing Cache + Storage synchronization...")
        
        // Given
        _ = await notesService.createNote(title: "Cache Test Note", content: "Cache integration test")
        let noteIndex = notesService.noteIndexes.first!
        
        // When - 获取笔记（应该触发缓存）
        let fullNote = await notesService.getNote(id: noteIndex.id)
        XCTAssertNotNil(fullNote, "笔记应该被获取")
        
        // 验证缓存状态
        let cachedNote = globalCacheManager.getCachedNote(id: noteIndex.id)
        XCTAssertNotNil(cachedNote, "笔记应该被缓存")
        
        // 测试缓存失效和重新加载
        globalCacheManager.notesCache.remove(noteIndex.id.uuidString)
        let uncachedNote = await notesService.getNote(id: noteIndex.id)
        XCTAssertNotNil(uncachedNote, "缓存失效后应该能从存储重新加载")
        
        let recachedNote = globalCacheManager.getCachedNote(id: noteIndex.id)
        XCTAssertNotNil(recachedNote, "重新缓存应该生效")
        
        print("✅ Cache + Storage synchronization passed")
    }
    
    /// 测试错误处理系统集成
    func testErrorHandlingIntegration() async throws {
        print("🔗 Testing Error Handling integration...")
        
        // Given - 创建一些测试数据
        _ = await notesService.createNote(title: "Error Test Note", content: "Error handling test")
        let noteIndex = notesService.noteIndexes.first!
        
        // When - 模拟各种错误情况
        let invalidOperation = SecurityOperation.sqlQuery("INVALID SQL QUERY")
        let validationResult = securityManager.validateOperation(invalidOperation)
        
        // Then
        XCTAssertFalse(validationResult.isSafe, "无效SQL应该被拒绝")
        
        // 测试错误恢复
        let recoveryResult = await ErrorHandler.shared.safeAsyncOperation {
            // 模拟恢复操作
            await notesService.loadNoteIndexes()
            return true
        }
        
        XCTAssertNoThrow(try recoveryResult.get(), "错误恢复应该成功")
        XCTAssertTrue(try recoveryResult.get(), "错误恢复应该返回成功结果")
        
        print("✅ Error Handling integration passed")
    }
    
    /// 测试异步任务与存储集成
    func testAsyncTaskWithStorage() async throws {
        print("🔗 Testing Async Task + Storage integration...")
        
        // Given
        let taskName = "StorageOperationTask"
        var taskCompleted = false
        var taskResult: Bool?
        
        // When - 创建异步任务
        let taskOperation = {
            // 执行存储操作
            await notesService.createNote(title: "Async Test Note", content: "Async task test")
            taskCompleted = true
            return true
        }
        
        let result = await asyncTaskManager.execute(
            name: taskName,
            configuration: .fast,
            operation: taskOperation
        )
        
        // Then
        switch result {
        case .success(let taskSuccess):
            XCTAssertTrue(taskSuccess, "异步任务应该成功")
            XCTAssertTrue(taskCompleted, "任务应该被执行")
            
            // 验证数据确实被创建
            let noteIndexes = notesService.noteIndexes
            let asyncCreatedNote = noteIndexes.first { $0.title == "Async Test Note" }
            XCTAssertNotNil(asyncCreatedNote, "异步创建的笔记应该存在")
            
        case .failure(let error):
            XCTFail("异步任务不应该失败: \(error)")
        case .cancelled:
            XCTFail("异步任务不应该被取消")
        case .timeout:
            XCTFail("异步任务不应该超时")
        }
        
        print("✅ Async Task + Storage integration passed")
    }
    
    /// 测试安全管理与存储集成
    func testSecurityWithStorage() async throws {
        print("🔗 Testing Security + Storage integration...")
        
        // Given
        let safeQuery = SecurityOperation.sqlQuery("SELECT * FROM notes WHERE title = ?")
        let unsafeQuery = SecurityOperation.sqlQuery("'; DROP TABLE notes; --")
        
        // When - 验证安全操作
        let safeValidation = securityManager.validateOperation(safeQuery)
        let unsafeValidation = securityManager.validateOperation(unsafeQuery)
        
        // Then
        XCTAssertTrue(safeValidation.isSafe, "安全查询应该通过验证")
        XCTAssertFalse(unsafeValidation.isSafe, "危险查询应该被拒绝")
        
        // 测试权限检查集成
        let permissionCheck = await PermissionManager.checkPermission(.fileSystem)
        XCTAssertTrue(permissionCheck == .authorized || permissionCheck == .denied, "权限检查应该返回有效状态")
        
        print("✅ Security + Storage integration passed")
    }
    /// 测试多组件协调工作流
    func testMultiComponentWorkflow() async throws {
        print("🔗 Testing Multi-component workflow...")
        
        // 模拟完整的工作流程：创建笔记 -> 缓存 -> 搜索 -> 安全验证 -> 异步更新
        
        // 1. 创建笔记
        let noteCreation = await notesService.createNote(
            title: "Workflow Test Note",
            content: "Testing complete workflow",
            tags: ["workflow", "integration"]
        )
        XCTAssertTrue(noteCreation, "笔记创建应该成功")
        
        let createdNote = notesService.noteIndexes.first { $0.title == "Workflow Test Note" }
        XCTAssertNotNil(createdNote, "新笔记应该存在")
        
        // 2. 验证缓存
        let cachedNote = globalCacheManager.getCachedNote(id: createdNote!.id)
        XCTAssertNotNil(cachedNote, "笔记应该被缓存")
        
        // 3. 执行搜索操作
        let searchResults = await notesService.searchNotes(query: "workflow")
        XCTAssertFalse(searchResults.isEmpty, "搜索应该返回结果")
        
        // 4. 执行异步更新
        let updateTask = asyncTaskManager.execute(name: "UpdateWorkflowNote") {
            if let noteId = createdNote?.id {
                let fullNote = await notesService.getNote(id: noteId)
                return fullNote != nil
            }
            return false
        }
        
        // 5. 验证权限
        let queryValidation = securityManager.validateOperation(.sqlQuery("SELECT * FROM notes"))
        XCTAssertTrue(queryValidation.isSafe, "查询应该安全")
        
        // 验证完整流程
        XCTAssertFalse(notesService.noteIndexes.isEmpty, "笔记应该仍然存在")
        
        print("✅ Multi-component workflow passed")
    }
    
    /// 测试性能集成
    func testPerformanceIntegration() async throws {
        print("🔗 Testing Performance integration...")
        
        // Given - 准备性能测试数据
        let testNotesCount = 50
        let startTime = Date()
        
        // When - 并发操作
        await withTaskGroup(of: Void.self) { group in
            // 创建笔记任务
            for i in 0..<testNotesCount {
                group.addTask {
                    await notesService.createNote(
                        title: "Performance Test \(i)",
                        content: "Performance test content \(i)"
                    )
                }
            }
            
            // 并发搜索任务
            for i in 0..<10 {
                group.addTask {
                    _ = await notesService.searchNotes(query: "Performance")
                }
            }
            
            // 并发缓存操作
            for i in 0..<20 {
                group.addTask {
                    globalCacheManager.cacheNote(Note(title: "Cache Note \(i)", content: "Cache content \(i)")
                }
            }
        }
        
        let endTime = Date()
        let totalDuration = endTime.timeIntervalSince(startTime)
        
        // Then - 验证性能
        XCTAssertLessThan(totalDuration, 10.0, "并发操作应该在10秒内完成")
        
        let finalNoteCount = notesService.noteIndexes.count
        XCTAssertGreaterThanOrEqual(finalNoteCount, testNotesCount, "笔记数量应该正确")
        
        print("Performance: Completed \(testNotesCount) note creations + 10 searches + 20 cache operations in \(String(format: "%.2f", totalDuration) seconds")
        print("✅ Performance integration passed")
    }
    
    /// 测试内存集成管理
    func testMemoryIntegration() async throws {
        print("🔗 Testing Memory integration...")
        
        // Given - 记录初始内存使用
        let initialMemory = getMemoryUsage()
        
        // 执行内存密集型操作
        for i in 0..<100 {
            _ = await notesService.createNote(
                title: "Memory Test \(i)",
                content: String(repeating: "Memory test content ", count: 100)
        }
        
        // 触发内存警告处理
        globalCacheManager.handleMemoryWarning()
        
        // 验证内存控制
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "内存增长应该控制在100MB以内")
        
        // 验证缓存管理
        let cacheStats = await globalCacheManager.getCacheStatistics()
        XCTAssertGreaterThan(cacheStats["notes"]?.totalItems ?? 0, 0, "笔记缓存应该有数据")
        
        print("Memory: Initial: \(initialMemory / 1024 / 1024)MB, Peak: \(peakMemory / 1024 / 1024)MB, Increase: \(memoryIncrease / 1024 / 1024)MB")
        print("✅ Memory integration passed")
    }
    
    // MARK: - Helper Methods
    
    private func clearTestData() async {
        // 清理测试数据
        let allIndexes = notesService.noteIndexes
        for index in allIndexes {
            if let fullNote = await notesService.getNote(id: index.id) {
                _ = await notesService.deleteNote(fullNote)
            }
        }
        
        // 清理缓存
        globalCacheManager.clearAllCaches()
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

// MARK: - Integration Test Suite

extension ArchitectureIntegrationTests {
    static var allIntegrationTests = [
        ("testNotesServiceWithUnifiedStorage", testNotesServiceWithUnifiedStorage),
        ("testCacheWithStorageSync", testCacheWithStorageSync),
        ("testErrorHandlingIntegration", testErrorHandlingIntegration),
        ("testAsyncTaskWithStorage", testAsyncTaskWithStorage),
        ("testSecurityWithStorage", testSecurityWithStorage),
        ("testMultiComponentWorkflow", testMultiComponentWorkflow),
        ("testPerformanceIntegration", testPerformanceIntegration),
        ("testMemoryIntegration", testMemoryIntegration)
    ]
}
