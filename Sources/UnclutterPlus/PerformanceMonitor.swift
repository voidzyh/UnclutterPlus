import Foundation
import Cocoa
import SwiftUI

// MARK: - Performance Monitor
// 性能监控工具：实时监控应用性能指标

/// 性能指标
struct PerformanceMetric {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Int64
    let activeThreads: Int
    let operationCount: Int
    let averageResponseTime: Double

    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .file)
    }

    var formattedCpu: String {
        String(format: "%.1f%%", cpuUsage * 100)
    }

    var formattedResponseTime: String {
        String(format: "%.2fms", averageResponseTime)
    }
}

/// 性能监控器
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    @Published var currentMetrics: PerformanceMetric?
    @Published var metricsHistory: [PerformanceMetric] = []
    @Published var isMonitoring = false

    private var monitoringTimer: Timer?
    private let maxHistoryCount = 100
    private let monitoringInterval: TimeInterval = 2.0

    // 性能计数器
    private var operationCount = 0
    private var responseTimeSum = 0.0
    private var responseTimeCount = 0

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.collectMetrics()
            }
        }

        print("🚀 Performance monitoring started")
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil

        print("⏹️ Performance monitoring stopped")
    }

    func recordOperation(responseTime: TimeInterval) {
        operationCount += 1
        responseTimeSum += responseTime
        responseTimeCount += 1
    }

    func recordOperation<T>(_ operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let responseTime = (endTime - startTime) * 1000 // 转换为毫秒
            recordOperation(responseTime: responseTime)
        }

        return try await operation()
    }

    func recordOperation<T>(_ operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let responseTime = (endTime - startTime) * 1000 // 转换为毫秒
            recordOperation(responseTime: responseTime)
        }

        return try operation()
    }

    // MARK: - Private Methods

    private func collectMetrics() async {
        let metrics = await calculateMetrics()

        await MainActor.run {
            currentMetrics = metrics
            addToHistory(metrics)
            cleanupHistory()
        }
    }

    private func calculateMetrics() async -> PerformanceMetric {
        let task = Task.detached {
            return await withCheckedContinuation { continuation in
                var info = mach_task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / MemoryLayout<integer_t>.size

                let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        task_info(mach_task_self_,
                                 task_flavor_t(MACH_TASK_BASIC_INFO),
                                 $0,
                                 &count)
                    }
                }

                let cpuUsage = getCPUUsage()
                let memoryUsage: Int64

                if kerr == KERN_SUCCESS {
                    memoryUsage = Int64(info.resident_size)
                } else {
                    memoryUsage = 0
                }

                let activeThreads = getActiveThreadCount()
                let averageResponseTime = responseTimeCount > 0 ? responseTimeSum / Double(responseTimeCount) : 0.0

                let metrics = PerformanceMetric(
                    timestamp: Date(),
                    cpuUsage: cpuUsage,
                    memoryUsage: memoryUsage,
                    activeThreads: activeThreads,
                    operationCount: self.operationCount,
                    averageResponseTime: averageResponseTime
                )

                continuation.resume(returning: metrics)
            }
        }

        return await task.value
    }

    private func getCPUUsage() -> Double {
        var info = task_cpu_usage_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_cpu_usage_info>.size) / MemoryLayout<integer_t>.size

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(TASK_CPU_USAGE_INFO),
                         $0,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            // CPU使用率计算（简化版）
            return Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
        }

        return 0.0
    }

    private func getActiveThreadCount() -> Int {
        var threads: thread_act_array_t?
        var count = mach_msg_type_number_t()

        let result = withUnsafeMutablePointer(to: &threads) {
            $0.withMemoryRebound(to: thread_act_t.self, capacity: 0) {
                task_threads(mach_task_self(), $0, &count)
            }
        }

        if result == KERN_SUCCESS, let threads = threads {
            let threadCount = Int(count)
            vm_deallocate(mach_task_self(),
                         vm_address_t(bitPattern: threads),
                         vm_size_t(count) * MemoryLayout<thread_t>.size)
            return threadCount
        }

        return 0
    }

    private func addToHistory(_ metrics: PerformanceMetric) {
        metricsHistory.append(metrics)

        // 保持历史记录在限制内
        if metricsHistory.count > maxHistoryCount {
            metricsHistory.removeFirst(metricsHistory.count - maxHistoryCount)
        }
    }

    private func cleanupHistory() {
        let cutoff = Date().addingTimeInterval(-3600) // 保留1小时历史
        metricsHistory.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Analysis

    func getAverageMetrics(for timeInterval: TimeInterval) -> PerformanceMetric? {
        let cutoff = Date().addTimeInterval(-timeInterval)
        let recentMetrics = metricsHistory.filter { $0.timestamp >= cutoff }

        guard !recentMetrics.isEmpty else { return nil }

        let count = Double(recentMetrics.count)
        let averageCpu = recentMetrics.reduce(0.0) { $0 + $1.cpuUsage } / count
        let averageMemory = Int64(recentMetrics.reduce(0) { $0 + $1.memoryUsage }) / Int(count)
        let averageThreads = recentMetrics.reduce(0) { $0 + $1.activeThreads } / Int(count)
        let averageResponseTime = recentMetrics.reduce(0.0) { $0 + $1.averageResponseTime } / count

        return PerformanceMetric(
            timestamp: Date(),
            cpuUsage: averageCpu,
            memoryUsage: averageMemory,
            activeThreads: averageThreads,
            operationCount: operationCount,
            averageResponseTime: averageResponseTime
        )
    }

    func getPerformanceReport() -> String {
        guard let current = currentMetrics else {
            return "No performance data available"
        }

        let cpuStatus = cpuStatus(current.cpuUsage)
        let memoryStatus = memoryStatus(current.memoryUsage)
        let responseStatus = responseTimeStatus(current.averageResponseTime)

        return """
        📊 Performance Report
        ====================
        CPU Usage: \(current.formattedCpu) (\(cpuStatus))
        Memory: \(current.formattedMemory) (\(memoryStatus))
        Active Threads: \(current.activeThreads)
        Avg Response: \(current.formattedResponseTime) (\(responseStatus))
        Operations: \(current.operationCount)

        Last Updated: \(current.timestamp.formatted(.dateTime.hour().minute().second()))
        """

    }

    private func cpuStatus(_ usage: Double) -> String {
        switch usage {
        case 0..<5: return "🟢 Excellent"
        case 5..<15: return "🟡 Good"
        case 15..<30: return "🟠 Fair"
        default: return "🔴 High"
        }
    }

    private func memoryStatus(_ usage: Int64) -> String {
        let mb = Double(usage) / (1024 * 1024)
        switch mb {
        case 0..<100: return "🟢 Low"
        case 100..<300: return "🟡 Moderate"
        case 300..<500: return "🟠 High"
        default: return "🔴 Very High"
        }
    }

    private func responseTimeStatus(_ time: Double) -> String {
        switch time {
        case 0..<10: return "🟢 Fast"
        case 10..<50: return "🟡 Normal"
        case 50..<100: return "🟠 Slow"
        default: return "🔴 Very Slow"
        }
    }
}

// MARK: - Performance View

struct PerformanceMonitorView: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📈 Performance")
                    .font(.headline)

                Spacer()

                Button(monitor.isMonitoring ? "Stop" : "Start") {
                    if monitor.isMonitoring {
                        monitor.stopMonitoring()
                    } else {
                        monitor.startMonitoring()
                    }
                }
                .buttonStyle(.bordered)
            }

            if let metrics = monitor.currentMetrics {
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(label: "CPU", value: metrics.formattedCpu, color: cpuColor(metrics.cpuUsage))
                    MetricRow(label: "Memory", value: metrics.formattedMemory, color: memoryColor(metrics.memoryUsage))
                    MetricRow(label: "Threads", value: "\(metrics.activeThreads)", color: .secondary)
                    MetricRow(label: "Response", value: metrics.formattedResponseTime, color: responseColor(metrics.averageResponseTime))

                    if showDetails {
                        Divider()
                        Text("Operations: \(metrics.operationCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Monitoring inactive")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            if !monitor.metricsHistory.isEmpty {
                Button("View Details") {
                    showDetails.toggle()
                }
                .font(.caption)
            }
        }
        .padding()
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }

    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<5: return .green
        case 5..<15: return .yellow
        case 15..<30: return .orange
        default: return .red
        }
    }

    private func memoryColor(_ usage: Int64) -> Color {
        let mb = Double(usage) / (1024 * 1024)
        switch mb {
        case 0..<100: return .green
        case 100..<300: return .yellow
        case 300..<500: return .orange
        default: return .red
        }
    }

    private func responseColor(_ time: Double) -> Color {
        switch time {
        case 0..<10: return .green
        case 10..<50: return .yellow
        case 50..<100: return .orange
        default: return .red
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Date Extension

extension Date {
    func formatted(_ formatter: DateFormatter) -> String {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return format.string(from: self)
    }
}
