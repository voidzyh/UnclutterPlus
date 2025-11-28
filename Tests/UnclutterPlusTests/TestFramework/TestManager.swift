import XCTest
import Foundation
import Combine

// MARK: - 测试配置

/// 测试配置
struct TestConfiguration {
    let testTimeout: TimeInterval
    let performanceThreshold: TimeInterval
    let memoryThreshold: Int64
    let enableCodeCoverage: Bool
    let parallelExecution: Bool
    let randomTestOrder: Bool
    
    static let `default` = TestConfiguration(
        testTimeout: 30.0,
        performanceThreshold: 1.0,
        memoryThreshold: 50 * 1024 * 1024, // 50MB
        enableCodeCoverage: true,
        parallelExecution: true,
        randomTestOrder: false
    )
    
    static let ci = TestConfiguration(
        testTimeout: 60.0,
        performanceThreshold: 2.0,
        memoryThreshold: 100 * 1024 * 1024, // 100MB
        enableCodeCoverage: true,
        parallelExecution: false,
        randomTestOrder: false
    )
}

// MARK: - 测试结果

/// 测试结果
struct TestResult: Identifiable {
    let id = UUID()
    let testName: String
    let suiteName: String
    let status: TestStatus
    let duration: TimeInterval
    let memoryUsage: Int64?
    let error: Error?
    let timestamp: Date
    
    enum TestStatus: String, CaseIterable {
        case passed = "passed"
        case failed = "failed"
        case skipped = "skipped"
        case timedOut = "timedOut"
        case crashed = "crashed"
        
        var isSuccess: Bool {
            return self == .passed
        }
        
        var icon: String {
            switch self {
            case .passed: return "✅"
            case .failed: return "❌"
            case .skipped: return "⏭️"
            case .timedOut: return "⏰"
            case .crashed: return "💥"
            }
        }
    }
}

// MARK: - 测试统计

/// 测试统计信息
struct TestStatistics {
    let totalTests: Int
    let passed: Int
    let failed: Int
    let skipped: Int
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let successRate: Double
    let memoryUsage: Int64?
    
    init(results: [TestResult]) {
        self.totalTests = results.count
        self.passed = results.filter { $0.status == .passed }.count
        self.failed = results.filter { $0.status == .failed }.count
        self.skipped = results.filter { $0.status == .skipped }.count
        
        let successfulResults = results.filter { $0.status.isSuccess }
        self.totalDuration = results.reduce(0) { $0 + $1.duration }
        self.averageDuration = totalTests > 0 ? totalDuration / Double(totalTests) : 0
        self.successRate = totalTests > 0 ? Double(passed) / Double(totalTests) : 0
        
        let maxMemoryUsage = results.compactMap { $0.memoryUsage }.max()
        self.memoryUsage = maxMemoryUsage
    }
    
    var description: String {
        """
        测试统计:
        - 总测试数: \(totalTests)
        - 通过: \(passed)
        - 失败: \(failed)
        - 跳过: \(skipped)
        - 成功率: \(String(format: "%.2f%%", successRate * 100))
        - 总耗时: \(String(format: "%.2f", totalDuration))秒
        - 平均耗时: \(String(format: "%.3f", averageDuration))秒
        - 内存峰值: \(memoryUsage.map { "\($0 / 1024 / 1024)MB" } ?? "未知")
        """
    }
}

// MARK: - 测试管理器

/// 统一测试管理器
@MainActor
final class TestManager: ObservableObject {
    static let shared = TestManager()
    
    @Published private(set) var testResults: [TestResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var currentTest: String?
    
    private let configuration: TestConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // 性能监控
    private var performanceMonitor: PerformanceMonitor?
    private let memoryThreshold: Int64
    
    // MARK: - Initialization
    
    init(configuration: TestConfiguration = .default) {
        self.configuration = configuration
        self.memoryThreshold = configuration.memoryThreshold
        self.performanceMonitor = PerformanceMonitor()
    }
    
    // MARK: - Public Methods
    
    /// 运行单元测试套件
    func runUnitTests() async -> TestStatistics {
        await runTestSuite(UnitTestSuite.self)
    }
    
    /// 运行集成测试套件
    func runIntegrationTests() async -> TestStatistics {
        await runTestSuite(IntegrationTestSuite.self)
    }
    
    /// 运行性能测试套件
    func runPerformanceTests() async -> TestStatistics {
        await runTestSuite(PerformanceTestSuite.self)
    }
    
    /// 运行完整测试套件
    func runAllTests() async -> TestStatistics {
        await runTestSuites([
            UnitTestSuite.self,
            IntegrationTestSuite.self,
            PerformanceTestSuite.self
        ])
    }
    
    /// 运行特定测试套件
    func runTestSuite<T: TestSuite>(_ suiteType: T.Type) async -> TestStatistics {
        print("🧪 开始运行测试套件: \(suiteType.suiteName)")
        
        let suite = suiteType.init()
        return await executeTests(in: suite)
    }
    
    /// 运行多个测试套件
    func runTestSuites(_ suiteTypes: [any TestSuite.Type]) async -> TestStatistics {
        print("🧪 开始运行 \(suiteTypes.count) 个测试套件")
        
        var allResults: [TestResult] = []
        
        for suiteType in suiteTypes {
            let statistics = await runTestSuite(suiteType)
            allResults.append(contentsOf: testResults)
        }
        
        return TestStatistics(results: allResults)
    }
    
    /// 生成测试报告
    func generateTestReport(format: ReportFormat = .text) -> String {
        let statistics = TestStatistics(results: testResults)
        
        switch format {
        case .text:
            return statistics.description
        case .json:
            return generateJSONReport()
        case .html:
            return generateHTMLReport()
        }
    }
    
    // MARK: - Private Methods
    
    private func executeTests<T: TestSuite>(in suite: T) async -> TestStatistics {
        isRunning = true
        testResults.removeAll()
        
        let startMemory = getCurrentMemoryUsage()
        let startTime = Date()
        
        defer {
            isRunning = false
        }
        
        // 获取测试方法
        let testMethods = suite.testMethods
        print("📋 发现 \(testMethods.count) 个测试方法")
        
        for testMethod in testMethods {
            await executeTest(testMethod, in: suite)
        }
        
        let endTime = Date()
        let endMemory = getCurrentMemoryUsage()
        let peakMemory = max(startMemory, endMemory)
        
        let statistics = TestStatistics(results: testResults)
        print("📊 \(suite.suiteName) 完成: \(statistics.description)")
        
        // 检查内存泄漏
        if peakMemory > memoryThreshold {
            print("⚠️ 警告: 检测到内存使用过高 (\(peakMemory / 1024 / 1024)MB)")
        }
        
        return statistics
    }
    
    private func executeTest<T: TestSuite>(_ testMethod: TestMethod, in suite: T) async {
        let testName = "\(suite.suiteName).\(testMethod.name)"
        currentTest = testName
        
        print("🔬 执行测试: \(testName)")
        
        let startTime = Date()
        let startMemory = getCurrentMemoryUsage()
        
        // 执行测试
        let result = await executeWithTimeout {
            await suite.execute(testMethod)
        }
        
        let endTime = Date()
        let endMemory = getCurrentMemoryUsage()
        let duration = endTime.timeIntervalSince(startTime)
        let memoryDelta = endMemory - startMemory
        
        // 检查超时
        if duration > configuration.testTimeout {
            addTestResult(
                name: testName,
                suite: suite.suiteName,
                status: .timedOut,
                duration: duration,
                memory: memoryDelta,
                error: TestError.timeout
            )
            return
        }
        
        // 处理测试结果
        switch result {
        case .success:
            addTestResult(
                name: testName,
                suite: suite.suiteName,
                status: .passed,
                duration: duration,
                memory: memoryDelta,
                error: nil
            )
            print("✅ \(testName) 通过 (\(String(format: "%.3f", duration))秒)")
            
        case .failure(let error):
            addTestResult(
                name: testName,
                suite: suite.suiteName,
                status: .failed,
                duration: duration,
                memory: memoryDelta,
                error: error
            )
            print("❌ \(testName) 失败: \(error.localizedDescription)")
            
        case .cancelled:
            addTestResult(
                name: testName,
                suite: suite.suiteName,
                status: .timedOut,
                duration: duration,
                memory: memoryDelta,
                error: TestError.cancelled
            )
            print("⏰ \(testName) 取消")
        }
        
        currentTest = nil
    }
    
    private func executeWithTimeout<T>(
        _ operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        return await withTaskGroup(of: Result<T, Error>.self) { group in
            group.addTask {
                do {
                    let result = try await operation()
                    return .success(result)
                } catch {
                    return .failure(error)
                }
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(configuration.testTimeout * 1_000_000_000))
                return .failure(TestError.timeout)
            }
            
            // 返回第一个完成的结果
            for await result in group {
                group.cancelAll()
                return result
            }
            
            return .failure(TestError.timeout)
        }
    }
    
    private func addTestResult(
        name: String,
        suite: String,
        status: TestResult.TestStatus,
        duration: TimeInterval,
        memory: Int64,
        error: Error?
    ) {
        let result = TestResult(
            testName: name,
            suiteName: suite,
            status: status,
            duration: duration,
            memoryUsage: abs(memory),
            error: error,
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: task_info_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func generateJSONReport() -> String {
        let reportData: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "statistics": TestStatistics(results: testResults).description,
            "results": testResults.map { result in
                [
                    "id": result.id.uuidString,
                    "name": result.testName,
                    "suite": result.suiteName,
                    "status": result.status.rawValue,
                    "duration": result.duration,
                    "memory": result.memoryUsage ?? 0,
                    "timestamp": ISO8601DateFormatter().string(from: result.timestamp)
                ]
            }
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: reportData, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    private func generateHTMLReport() -> String {
        let statistics = TestStatistics(results: testResults)
        let passedTests = testResults.filter { $0.status == .passed }
        let failedTests = testResults.filter { $0.status == .failed }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Test Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; }
                .success { color: green; }
                .failure { color: red; }
                .test-item { margin: 10px 0; padding: 10px; border: 1px solid #ddd; }
            </style>
        </head>
        <body>
            <h1>UnclutterPlus Test Report</h1>
            
            <div class="summary">
                <h2>Summary</h2>
                <p><strong>Total Tests:</strong> \(statistics.totalTests)</p>
                <p><strong>Passed:</strong> \(statistics.passed) <span class="success">✅</span></p>
                <p><strong>Failed:</strong> \(statistics.failed) <span class="failure">❌</span></p>
                <p><strong>Success Rate:</strong> \(String(format: "%.2f%%", statistics.successRate * 100))</p>
                <p><strong>Total Duration:</strong> \(String(format: "%.2f", statistics.totalDuration))s</p>
            </div>
            
            <h2>Test Details</h2>
            \(passedTests.map { test in
                "<div class='test-item'><strong>\(test.testName)</strong> - <span class='success'>PASSED</span> (\(String(format: "%.3f", test.duration))s)</div>"
            }.joined(separator: "\n"))
            \(failedTests.map { test in
                "<div class='test-item'><strong>\(test.testName)</strong> - <span class='failure'>FAILED</span> (\(String(format: "%.3f", test.duration))s) - \(test.error?.localizedDescription ?? "")</div>"
            }.joined(separator: "\n"))
        </body>
        </html>
        """
    }
}

// MARK: - 测试协议

/// 测试套件协议
protocol TestSuite {
    static var suiteName: String { get }
    var testMethods: [TestMethod] { get }
    
    func execute(_ testMethod: TestMethod) async throws
}

/// 测试方法
struct TestMethod: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let tags: [String]
    let isAsync: Bool
}

// MARK: - 性能监控器

/// 性能监控器
final class PerformanceMonitor {
    private var measurements: [String: [TimeInterval]] = [:]
    
    func startMeasurement(_ identifier: String) {
        measurements[identifier, default: []].append(Date().timeIntervalSince1970)
    }
    
    func endMeasurement(_ identifier: String) -> TimeInterval? {
        guard var times = measurements[identifier], times.count >= 2 else {
            return nil
        }
        let startTime = times.removeFirst()
        let endTime = times.removeLast()
        measurements[identifier] = times
        return endTime - startTime
    }
    
    func getAverageDuration(_ identifier: String) -> TimeInterval? {
        guard let times = measurements[identifier], !times.isEmpty else {
            return nil
        }
        return times.reduce(0, +) / Double(times.count)
    }
}

// MARK: - 错误类型

enum TestError: Error {
    case timeout
    case cancelled
    case invalidTest
    case assertionFailed(String)
}

extension TestError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .timeout:
            return "测试超时"
        case .cancelled:
            return "测试被取消"
        case .invalidTest:
            return "无效测试"
        case .assertionFailed(let message):
            return "断言失败: \(message)"
        }
    }
}

// MARK: - 报告格式

enum ReportFormat: String, CaseIterable {
    case text = "text"
    case json = "json"
    case html = "html"
}

// MARK: - 测试断言

/// 测试断言工具
class TestAssertions {
    static func assertEqual<T: Equatable>(_ expected: T, _ actual: T, _ message: String = "") throws {
        guard expected == actual else {
            throw TestError.assertionFailed("Expected: \(expected), Actual: \(actual). \(message)")
        }
    }
    
    static func assertTrue(_ condition: Bool, _ message: String = "") throws {
        guard condition else {
            throw TestError.assertionFailed("Expected true, got false. \(message)")
        }
    }
    
    static func assertFalse(_ condition: Bool, _ message: String = "") throws {
        guard !condition else {
            throw TestError.assertionFailed("Expected false, got true. \(message)")
        }
    }
    
    static func assertNotNil<T>(_ value: T?, _ message: String = "") throws {
        guard value != nil else {
            throw TestError.assertionFailed("Expected non-nil value. \(message)")
        }
    }
    
    static func assertNil<T>(_ value: T?, _ message: String = "") throws {
        guard value == nil else {
            throw TestError.assertionFailed("Expected nil, got \(value!). \(message)")
        }
    }
}

// MARK: - 模拟对象

/// 模拟对象协议
protocol Mockable {
    associatedtype Mock
    static func mock() -> Mock
}

/// 模拟测试服务
class MockTestService: Mockable {
    let id: UUID
    var callCount: Int
    var lastCall: Date?
    
    init() {
        self.id = UUID()
        self.callCount = 0
    }
    
    func performOperation() {
        callCount += 1
        lastCall = Date()
    }
    
    static func mock() -> MockTestService {
        return MockTestService()
    }
}

extension MockTestService: Mockable where Self == MockTestService {
    typealias Mock = MockTestService
}
