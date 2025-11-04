import Foundation

/// 性能监控工具类
/// 用于测量和记录关键操作的性能指标
final class PerformanceMonitor {

    // MARK: - Configuration

    /// 是否启用性能监控
    /// - 可通过 UserDefaults 动态配置
    /// - DEBUG 模式默认开启
    static var isEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "PerformanceMonitor.Enabled") != false
        #else
        return UserDefaults.standard.bool(forKey: "PerformanceMonitor.Enabled")
        #endif
    }

    /// 性能警告阈值（毫秒）
    /// 超过此阈值的操作将被标记为慢操作
    static var warningThreshold: Double {
        UserDefaults.standard.double(forKey: "PerformanceMonitor.WarningThreshold").nonZeroOr(16.67)
    }

    // MARK: - Measurement Methods

    /// 测量同步操作的执行时间
    /// - Parameters:
    ///   - label: 操作标签，用于日志输出
    ///   - operation: 要测量的操作闭包
    /// - Returns: 操作的返回值
    @discardableResult
    static func measure<T>(_ label: String, _ operation: () -> T) -> T {
        guard isEnabled else { return operation() }

        let start = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        logPerformance(label: label, elapsed: elapsed)
        return result
    }

    /// 测量同步抛出操作的执行时间
    /// - Parameters:
    ///   - label: 操作标签
    ///   - operation: 要测量的操作闭包
    /// - Returns: 操作的返回值
    /// - Throws: 操作可能抛出的错误
    @discardableResult
    static func measure<T>(_ label: String, _ operation: () throws -> T) throws -> T {
        guard isEnabled else { return try operation() }

        let start = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        logPerformance(label: label, elapsed: elapsed)
        return result
    }

    /// 测量异步操作的执行时间
    /// - Parameters:
    ///   - label: 操作标签
    ///   - operation: 要测量的异步操作闭包
    /// - Returns: 操作的返回值
    @discardableResult
    static func measureAsync<T>(_ label: String, _ operation: () async -> T) async -> T {
        guard isEnabled else { return await operation() }

        let start = CFAbsoluteTimeGetCurrent()
        let result = await operation()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        logPerformance(label: label, elapsed: elapsed)
        return result
    }

    /// 测量异步抛出操作的执行时间
    /// - Parameters:
    ///   - label: 操作标签
    ///   - operation: 要测量的异步操作闭包
    /// - Returns: 操作的返回值
    /// - Throws: 操作可能抛出的错误
    @discardableResult
    static func measureAsync<T>(_ label: String, _ operation: () async throws -> T) async throws -> T {
        guard isEnabled else { return try await operation() }

        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        logPerformance(label: label, elapsed: elapsed)
        return result
    }

    // MARK: - Logging

    /// 记录性能指标
    /// - Parameters:
    ///   - label: 操作标签
    ///   - elapsed: 耗时（毫秒）
    private static func logPerformance(label: String, elapsed: Double) {
        let threshold = warningThreshold

        if elapsed > threshold {
            // 慢操作警告
            print("⚠️ [Performance] [\(label)] took \(String(format: "%.2f", elapsed))ms (threshold: \(String(format: "%.2f", threshold))ms)")
        } else if elapsed > threshold * 0.7 {
            // 接近阈值的操作
            print("⏱️ [Performance] [\(label)] took \(String(format: "%.2f", elapsed))ms")
        } else {
            // 正常操作（可选日志）
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "PerformanceMonitor.VerboseLogging") {
                print("✅ [Performance] [\(label)] took \(String(format: "%.2f", elapsed))ms")
            }
            #endif
        }
    }

    // MARK: - Statistics

    /// 性能统计数据
    private static var statistics: [String: PerformanceStats] = [:]
    private static let statisticsLock = NSLock()

    /// 记录统计数据
    /// - Parameters:
    ///   - label: 操作标签
    ///   - elapsed: 耗时（毫秒）
    static func recordStats(label: String, elapsed: Double) {
        statisticsLock.lock()
        defer { statisticsLock.unlock() }

        var stats = statistics[label] ?? PerformanceStats(label: label)
        stats.record(elapsed)
        statistics[label] = stats
    }

    /// 获取统计报告
    /// - Returns: 格式化的统计报告字符串
    static func getStatisticsReport() -> String {
        statisticsLock.lock()
        defer { statisticsLock.unlock() }

        guard !statistics.isEmpty else {
            return "No performance statistics available."
        }

        var report = "📊 Performance Statistics Report\n"
        report += String(repeating: "=", count: 50) + "\n"

        let sortedStats = statistics.values.sorted { $0.averageTime > $1.averageTime }

        for stats in sortedStats {
            report += stats.description + "\n"
        }

        return report
    }

    /// 清空统计数据
    static func clearStatistics() {
        statisticsLock.lock()
        defer { statisticsLock.unlock() }
        statistics.removeAll()
    }
}

// MARK: - Performance Statistics

/// 性能统计数据结构
private struct PerformanceStats: CustomStringConvertible {
    let label: String
    var count: Int = 0
    var totalTime: Double = 0
    var minTime: Double = .infinity
    var maxTime: Double = 0

    var averageTime: Double {
        count > 0 ? totalTime / Double(count) : 0
    }

    mutating func record(_ elapsed: Double) {
        count += 1
        totalTime += elapsed
        minTime = min(minTime, elapsed)
        maxTime = max(maxTime, elapsed)
    }

    var description: String {
        let avg = String(format: "%.2f", averageTime)
        let min = String(format: "%.2f", minTime)
        let max = String(format: "%.2f", maxTime)
        return "[\(label)] count: \(count), avg: \(avg)ms, min: \(min)ms, max: \(max)ms"
    }
}

// MARK: - Helper Extensions

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}

// MARK: - UserDefaults Extension for Easy Configuration

extension UserDefaults {
    /// 性能监控配置键
    enum PerformanceMonitorKeys {
        static let enabled = "PerformanceMonitor.Enabled"
        static let warningThreshold = "PerformanceMonitor.WarningThreshold"
        static let verboseLogging = "PerformanceMonitor.VerboseLogging"
    }

    /// 启用性能监控
    func enablePerformanceMonitoring(warningThreshold: Double = 16.67, verbose: Bool = false) {
        set(true, forKey: PerformanceMonitorKeys.enabled)
        set(warningThreshold, forKey: PerformanceMonitorKeys.warningThreshold)
        set(verbose, forKey: PerformanceMonitorKeys.verboseLogging)
    }

    /// 禁用性能监控
    func disablePerformanceMonitoring() {
        set(false, forKey: PerformanceMonitorKeys.enabled)
    }
}
