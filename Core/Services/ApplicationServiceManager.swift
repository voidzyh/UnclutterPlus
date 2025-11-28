import Foundation
import SwiftUI
import Combine

/// 应用服务管理器 - 统一协调所有优化后的组件
@MainActor
final class ApplicationServiceManager: ObservableObject {
    static let shared = ApplicationServiceManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var initializationProgress: Double = 0.0
    @Published private(set) var initializationStatus: String = "准备初始化..."
    @Published private(set) var healthStatus: HealthStatus = .unknown
    
    // MARK: - Service Instances
    
    /// 笔记服务 (优化版本)
    private(set) var notesService: NotesService?
    
    /// 错误处理器
    private(set) var errorHandler: ErrorHandler?
    
    /// 安全管理器
    private(set) var securityManager: SecurityManager?
    
    /// 任务管理器
    private(set) var taskManager: AsyncTaskManager?
    
    /// 缓存管理器
    private(set) var globalCacheManager: GlobalCacheManager?
    
    /// 结构化日志记录器
    private(set) var structuredLogger: StructuredLogger?
    
    /// 配置管理器
    private(set) var configurationManager: ConfigurationManagerEnhanced?
    
    /// 性能监控器
    private(set) var performanceMonitor: PerformanceMonitor?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let initializationQueue = DispatchQueue(label: "app.service.initialization", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        logger.info("应用服务管理器正在初始化")
    }
    
    // MARK: - Public Methods
    
    /// 初始化所有服务
    func initialize() async throws {
        logger.info("🚀 开始初始化UnclutterPlus服务系统")
        
        try await initializeInPhases()
        
        isInitialized = true
        healthStatus = .healthy
        logger.info("✅ 应用服务管理器初始化完成")
    }
    
    /// 获取笔记服务 (延迟初始化)
    func getNotesService() async throws -> NotesService {
        if let existingService = notesService {
            return existingService
        }
        
        logger.info("📝 创建笔记服务")
        let service = NotesService()
        notesService = service
        return service
    }
    
    /// 执行健康检查
    func performHealthCheck() async -> HealthReport {
        var checks: [HealthCheck] = []
        
        // 检查核心服务状态
        checks.append(await checkCoreServices())
        checks.append(await checkStorageHealth())
        checks.append(await checkMemoryHealth())
        checks.append(await checkSecurityHealth())
        checks.append(await checkPerformanceHealth())
        
        let report = HealthReport(
            timestamp: Date(),
            overallStatus: determineOverallStatus(from: checks),
            checks: checks
        )
        
        // 记录健康检查结果
        if report.overallStatus == .healthy {
            logger.debug("✅ 健康检查通过", category: "Health")
        } else {
            logger.warning("⚠️ 健康检查发现问题: \(report.overallStatus.rawValue)", category: "Health")
        }
        
        return report
    }
    
    /// 关闭所有服务
    func shutdown() async {
        logger.info("🛑 正在关闭应用服务...")
        
        // 清理缓存
        globalCacheManager?.clearAllCaches()
        
        // 停止安全监控
        securityManager?.stopSecurityMonitoring()
        
        // 清理任务队列
        taskManager?.cleanupCompletedTasks()
        
        isInitialized = false
        healthStatus = .stopped
        
        logger.info("✅ 应用服务已关闭")
    }
    
    // MARK: - Private Methods
    
    private func initializeInPhases() async throws {
        // Phase 1: 基础服务 (20%)
        await updateProgress(0.1, "初始化基础服务...")
        try await initializeBasicServices()
        
        // Phase 2: 核心服务 (40%)
        await updateProgress(0.3, "初始化核心服务...")
        try await initializeCoreServices()
        
        // Phase 3: 高级服务 (60%)
        await updateProgress(0.5, "初始化高级服务...")
        try await initializeAdvancedServices()
        
        // Phase 4: 安全和监控 (80%)
        await updateProgress(0.7, "初始化安全和监控...")
        try await initializeSecurityAndMonitoring()
        
        // Phase 5: 完成初始化 (100%)
        await updateProgress(0.9, "完成初始化...")
        
        // 预热缓存
        await warmupCaches()
        
        await updateProgress(1.0, "初始化完成")
        logger.info("🎉 所有服务初始化完成")
    }
    
    private func initializeBasicServices() async throws {
        // 配置管理器
        configurationManager = ConfigurationManagerEnhanced()
        logger.debug("✅ 配置管理器初始化完成")
        
        // 结构化日志
        structuredLogger = StructuredLogger()
        logger.debug("✅ 结构化日志系统初始化完成")
        
        // 错误处理器
        errorHandler = ErrorHandler.shared
        logger.debug("✅ 错误处理器初始化完成")
    }
    
    private func initializeCoreServices() async throws {
        // 任务管理器
        taskManager = AsyncTaskManager.shared
        logger.debug("✅ 任务管理器初始化完成")
        
        // 全局缓存管理器
        globalCacheManager = GlobalCacheManager.shared
        logger.debug("✅ 缓存管理器初始化完成")
        
        // 性能监控器
        performanceMonitor = PerformanceMonitor()
        logger.debug("✅ 性能监控器初始化完成")
    }
    
    private func initializeAdvancedServices() async throws {
        // 笔记服务
        notesService = NotesService()
        logger.debug("✅ 笔记服务初始化完成")
    }
    
    private func initializeSecurityAndMonitoring() async throws {
        // 安全管理器
        securityManager = SecurityManager.shared
        securityManager?.startSecurityMonitoring()
        logger.debug("✅ 安全管理器初始化完成")
        
        // 启动性能监控
        await startPerformanceMonitoring()
        logger.debug("✅ 性能监控启动完成")
    }
    
    private func startPerformanceMonitoring() async {
        // 记录内存使用情况
        structuredLogger?.memoryUsage()
        
        // 启动定期性能监控
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logPeriodicMetrics()
            }
        }
    }
    
    private func warmupCaches() async {
        logger.info("🔥 预热缓存系统...")
        globalCacheManager?.warmupCaches()
        logger.debug("✅ 缓存预热完成")
    }
    
    private func updateProgress(_ progress: Double, _ status: String) async {
        initializationProgress = progress
        initializationStatus = status
        
        // 记录初始化进度
        logger.debug("🔄 初始化进度: \(Int(progress * 100))% - \(status)")
    }
    
    private func logPeriodicMetrics() {
        // 记录定期指标
        structuredLogger?.memoryUsage(category: "Periodic")
        logger.info("📊 记录定期性能指标", category: "Performance")
    }
    
    // MARK: - Health Checks
    
    private func checkCoreServices() async -> HealthCheck {
        let services = [
            ("ErrorHandler", errorHandler != nil),
            ("TaskManager", taskManager != nil),
            ("CacheManager", globalCacheManager != nil),
            ("Logger", structuredLogger != nil)
        ]
        
        let healthyServices = services.filter { $0.1 }.count
        let totalServices = services.count
        
        return HealthCheck(
            name: "CoreServices",
            status: healthyServices == totalServices ? .healthy : .unhealthy,
            details: "核心服务: \(healthyServices)/\(totalServices) 已初始化",
            timestamp: Date()
        )
    }
    
    private func checkStorageHealth() async -> HealthCheck {
        // 检查笔记服务存储状态
        if let notesService = notesService {
            do {
                let stats = await notesService.getStatistics()
                return HealthCheck(
                    name: "Storage",
                    status: stats.storageType == "modern" ? .healthy : .degraded,
                    details: "存储类型: \(stats.storageType), 笔记数: \(stats.totalNotes)",
                    timestamp: Date()
                )
            } catch {
                return HealthCheck(
                    name: "Storage",
                    status: .unhealthy,
                    details: "存储检查失败: \(error.localizedDescription)",
                    timestamp: Date()
                )
            }
        }
        
        return HealthCheck(
            name: "Storage",
            status: .unknown,
            details: "笔记服务未初始化",
            timestamp: Date()
        )
    }
    
    private func checkMemoryHealth() async -> HealthCheck {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: task_info_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / (1024 * 1024)
            let threshold = 200.0 // 200MB阈值
            
            return HealthCheck(
                name: "Memory",
                status: memoryMB < threshold ? .healthy : (memoryMB < threshold * 1.5 ? .degraded : .unhealthy),
                details: "内存使用: \(String(format: "%.1f", memoryMB))MB",
                timestamp: Date()
            )
        }
        
        return HealthCheck(
            name: "Memory",
            status: .unknown,
            details: "无法获取内存信息",
            timestamp: Date()
        )
    }
    
    private func checkSecurityHealth() async -> HealthCheck {
        if let securityManager = securityManager {
            return HealthCheck(
                name: "Security",
                status: securityManager.securityStatus == .secure ? .healthy : .degraded,
                details: "安全状态: \(securityManager.securityStatus.rawValue), 威胁数: \(securityManager.activeThreats.count)",
                timestamp: Date()
            )
        }
        
        return HealthCheck(
            name: "Security",
            status: .unknown,
            details: "安全管理器未初始化",
            timestamp: Date()
        )
    }
    
    private func checkPerformanceHealth() async -> HealthCheck {
        if let taskManager = taskManager {
            let stats = taskManager.getStatistics()
            return HealthCheck(
                name: "Performance",
                status: stats.averageExecutionTime < 1.0 ? .healthy : .degraded,
                details: "平均执行时间: \(String(format: "%.3f", stats.averageExecutionTime))s, 成功率: \(String(format: "%.1f", stats.successRate * 100))%",
                timestamp: Date()
            )
        }
        
        return HealthCheck(
            name: "Performance",
            status: .unknown,
            details: "任务管理器未初始化",
            timestamp: Date()
        )
    }
    
    private func determineOverallStatus(from checks: [HealthCheck]) -> HealthStatus {
        let unhealthyCount = checks.filter { $0.status == .unhealthy }.count
        let degradedCount = checks.filter { $0.status == .degraded }.count
        
        if unhealthyCount > 0 {
            return .unhealthy
        } else if degradedCount > 0 {
            return .degraded
        } else {
            return .healthy
        }
    }
    
    deinit {
        Task {
            await shutdown()
        }
    }
}

// MARK: - Health Status Types

enum HealthStatus: String, CaseIterable {
    case unknown = "unknown"
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
    case stopped = "stopped"
}

struct HealthCheck: Identifiable {
    let id = UUID()
    let name: String
    let status: HealthStatus
    let details: String
    let timestamp: Date
}

struct HealthReport {
    let timestamp: Date
    let overallStatus: HealthStatus
    let checks: [HealthCheck]
    
    var isHealthy: Bool {
        overallStatus == .healthy
    }
    
    var description: String {
        """
        健康检查报告 (\(timestamp)):
        总体状态: \(overallStatus.rawValue)
        
        检查项目:
        \(checks.map { "- \($0.name): \($0.status.rawValue) - \($0.details)" }.joined(separator: "\n"))
        """
    }
}
