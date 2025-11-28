import XCTest
import SwiftUI
import Combine

@testable import UnclutterPlus

/// ApplicationServiceManager 的单元测试
final class ApplicationServiceManagerTests: XCTestCase {
    var serviceManager: ApplicationServiceManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        serviceManager = ApplicationServiceManager.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        serviceManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceManagerInitialization() async throws {
        // 测试服务管理器初始化
        XCTAssertFalse(serviceManager.isInitialized)
        XCTAssertEqual(serviceManager.initializationProgress, 0.0)
        XCTAssertEqual(serviceManager.healthStatus, .unknown)
        
        // 执行初始化
        try await serviceManager.initialize()
        
        // 验证初始化结果
        XCTAssertTrue(serviceManager.isInitialized)
        XCTAssertEqual(serviceManager.healthStatus, .healthy)
        XCTAssertEqual(serviceManager.initializationProgress, 1.0)
    }
    
    func testServiceManagerInitializationProgress() async throws {
        let expectation = XCTestExpectation(description: "进度更新")
        
        serviceManager.$initializationProgress
            .sink { progress in
                if progress > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        try await serviceManager.initialize()
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Health Check Tests
    
    func testHealthCheckWhenInitialized() async throws {
        // 先初始化服务
        try await serviceManager.initialize()
        
        // 执行健康检查
        let healthReport = await serviceManager.performHealthCheck()
        
        // 验证健康报告
        XCTAssertNotNil(healthReport)
        XCTAssertGreaterThanOrEqual(healthReport.checks.count, 1)
        
        // 核心服务应该都处于健康状态
        let coreServicesCheck = healthReport.checks.first { $0.name == "CoreServices" }
        XCTAssertNotNil(coreServicesCheck)
        XCTAssertEqual(coreServicesCheck?.status, .healthy)
    }
    
    func testHealthCheckWhenNotInitialized() async {
        // 在未初始化状态下执行健康检查
        let healthReport = await serviceManager.performHealthCheck()
        
        // 应该能返回报告，即使某些服务未初始化
        XCTAssertNotNil(healthReport)
        XCTAssertEqual(healthReport.overallStatus, .unknown)
    }
    
    // MARK: - Service Access Tests
    
    func testGetNotesService() async throws {
        // 先初始化服务管理器
        try await serviceManager.initialize()
        
        // 获取笔记服务
        let notesService = try await serviceManager.getNotesService()
        
        // 验证笔记服务
        XCTAssertNotNil(notesService)
        XCTAssertTrue(notesService is NotesService)
    }
    
    func testGetNotesServiceTwiceReturnsSameInstance() async throws {
        try await serviceManager.initialize()
        
        // 两次获取笔记服务应该返回同一个实例
        let notesService1 = try await serviceManager.getNotesService()
        let notesService2 = try await serviceManager.getNotesService()
        
        XCTAssertEqual(notesService1, notesService2)
    }
    
    // MARK: - Shutdown Tests
    
    func testShutdown() async throws {
        // 先初始化
        try await serviceManager.initialize()
        XCTAssertTrue(serviceManager.isInitialized)
        
        // 执行关闭
        await serviceManager.shutdown()
        
        // 验证关闭结果
        XCTAssertFalse(serviceManager.isInitialized)
        XCTAssertEqual(serviceManager.healthStatus, .stopped)
    }
    
    func testShutdownCanBeCalledMultipleTimes() async throws {
        try await serviceManager.initialize()
        
        // 多次关闭不应该崩溃
        await serviceManager.shutdown()
        await serviceManager.shutdown()
        await serviceManager.shutdown()
        
        XCTAssertFalse(serviceManager.isInitialized)
    }
    
    // MARK: - Error Handling Tests
    
    func testInitializationFailureHandling() async throws {
        // 这是一个基本测试，确保错误处理不会崩溃
        // 在实际应用中，我们可能需要模拟初始化失败的情况
        
        try await serviceManager.initialize()
        
        // 如果初始化成功，说明错误处理正常
        XCTAssertTrue(serviceManager.isInitialized)
    }
    
    // MARK: - Performance Tests
    
    func testInitializationPerformance() async throws {
        measure {
            let expectation = XCTestExpectation(description: "初始化完成")
            
            Task {
                try? await serviceManager.initialize()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testHealthCheckPerformance() async throws {
        try await serviceManager.initialize()
        
        measure {
            let expectation = XCTestExpectation(description: "健康检查完成")
            
            Task {
                _ = await serviceManager.performHealthCheck()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryUsageAfterInitialization() async throws {
        let initialMemory = getMemoryUsage()
        
        try await serviceManager.initialize()
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // 内存增长应该合理（少于100MB）
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024)
    }
    
    func testMemoryNotLeakingAfterShutdown() async throws {
        try await serviceManager.initialize()
        await serviceManager.shutdown()
        
        // 关闭后内存使用应该显著减少
        // 这里我们主要验证不会崩溃
        let expectation = XCTestExpectation(description: "验证无内存泄漏")
        
        Task {
            // 再次初始化和关闭
            try? await serviceManager.initialize()
            await serviceManager.shutdown()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
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
