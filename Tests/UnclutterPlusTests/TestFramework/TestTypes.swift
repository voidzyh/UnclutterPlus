import Foundation
import SwiftUI

/// 测试结果类型
struct TestResult: Identifiable {
    let id = UUID()
    let testName: String
    let suiteName: String
    let status: TestStatus
    let duration: TimeInterval
    let memoryUsage: Int64?
    let error: Error?
    let timestamp: Date

    enum TestStatus {
        case passed
        case failed
        case skipped
        case timedOut
        case crashed

        var icon: String {
            switch self {
            case .passed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .skipped: return "pause.circle.fill"
            case .timedOut: return "clock.circle.fill"
            case .crashed: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .passed: return .green
            case .failed: return .red
            case .skipped: return .orange
            case .timedOut: return .yellow
            case .crashed: return .red
            }
        }
    }
}

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

    init(totalTests: Int, passed: Int, failed: Int, skipped: Int, totalDuration: TimeInterval, averageDuration: TimeInterval, successRate: Double, memoryUsage: Int64?) {
        self.totalTests = totalTests
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
        self.totalDuration = totalDuration
        self.averageDuration = averageDuration
        self.successRate = successRate
        self.memoryUsage = memoryUsage
    }

    init?(results: [TestResult]) {
        guard !results.isEmpty else { return nil }

        self.totalTests = results.count
        self.passed = results.filter { $0.status == .passed }.count
        self.failed = results.filter { $0.status == .failed }.count
        self.skipped = results.filter { $0.status == .skipped }.count
        self.totalDuration = results.reduce(0) { $0 + $1.duration }
        self.averageDuration = totalDuration / Double(totalTests)
        self.successRate = totalTests > 0 ? Double(passed) / Double(totalTests) : 0
        self.memoryUsage = nil
    }
}

/// 基准测试结果
struct BenchmarkResult: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String
    let timestamp: Date
}

/// 性能基准测试报告
struct PerformanceBenchmarkReport {
    let timestamp: Date
    let results: [BenchmarkResult]

    var description: String {
        """
        Performance Benchmark Report:
        \(results.map { "- \($0.name): \($0.value) \($0.unit)" }.joined(separator: "\n"))
        """
    }
}
