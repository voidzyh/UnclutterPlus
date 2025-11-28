import Foundation

// MARK: - 统一应用错误协议

/// 统一应用错误协议
protocol AppError: LocalizedError, CustomDebugStringConvertible {
    var errorId: String { get }
    var timestamp: Date { get }
    var userMessage: String { get }
    var recoverySuggestion: String? { get }
    var underlyingError: Error? { get }
    var severity: ErrorSeverity { get }
    var category: ErrorCategory { get }
}

// MARK: - 错误严重程度

/// 错误严重程度
enum ErrorSeverity: String, CaseIterable {
    case critical = "critical"    // 致命错误，应用无法继续
    case high = "high"           // 严重错误，功能受限
    case medium = "medium"       // 中等错误，部分功能可用
    case low = "low"             // 轻微错误，不影响主要功能
    case info = "info"           // 信息提示
    
    var displayName: String {
        switch self {
        case .critical: return "致命"
        case .high: return "严重"
        case .medium: return "中等"
        case .low: return "轻微"
        case .info: return "信息"
        }
    }
    
    var priority: Int {
        switch self {
        case .critical: return 1
        case .high: return 2
        case .medium: return 3
        case .low: return 4
        case .info: return 5
        }
    }
}

// MARK: - 错误分类

/// 错误分类
enum ErrorCategory: String, CaseIterable {
    case storage = "storage"           // 存储相关
    case network = "network"           // 网络相关
    case ui = "ui"                     // 用户界面
    case permissions = "permissions"   // 权限相关
    case data = "data"                 // 数据处理
    case system = "system"             // 系统相关
    case userInput = "userInput"       // 用户输入
    case configuration = "configuration" // 配置相关
    case unknown = "unknown"           // 未知
    
    var displayName: String {
        switch self {
        case .storage: return "存储"
        case .network: return "网络"
        case .ui: return "界面"
        case .permissions: return "权限"
        case .data: return "数据"
        case .system: return "系统"
        case .userInput: return "输入"
        case .configuration: return "配置"
        case .unknown: return "未知"
        }
    }
}

// MARK: - 具体错误实现

/// 统一应用错误实现
struct UnifiedAppError: AppError {
    let errorId: String
    let timestamp: Date
    let userMessage: String
    let recoverySuggestion: String?
    let underlyingError: Error?
    let severity: ErrorSeverity
    let category: ErrorCategory
    
    // CustomDebugStringConvertible
    var debugDescription: String {
        """
        Error: \(errorId)
        Category: \(category.displayName)
        Severity: \(severity.displayName)
        Message: \(userMessage)
        Suggestion: \(recoverySuggestion ?? "无")
        Underlying: \(underlyingError?.localizedDescription ?? "无")
        Time: \(timestamp)
        """
    }
    
    // LocalizedError
    var errorDescription: String? {
        userMessage
    }
    
    var failureReason: String? {
        underlyingError?.localizedDescription
    }
    
    var recoverySuggestionMessage: String? {
        recoverySuggestion
    }
}

// MARK: - 错误构造器

/// 错误构造器 - 简化错误创建过程
enum ErrorBuilder {
    /// 创建存储相关错误
    static func storage(
        _ message: String,
        underlying: Error? = nil,
        severity: ErrorSeverity = .medium,
        suggestion: String? = nil
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "STO_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: message,
            recoverySuggestion: suggestion ?? "请检查磁盘空间和文件权限",
            underlyingError: underlying,
            severity: severity,
            category: .storage
        )
    }
    
    /// 创建网络相关错误
    static func network(
        _ message: String,
        underlying: Error? = nil,
        severity: ErrorSeverity = .medium,
        suggestion: String? = nil
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "NET_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: message,
            recoverySuggestion: suggestion ?? "请检查网络连接或稍后重试",
            underlyingError: underlying,
            severity: severity,
            category: .network
        )
    }
    
    /// 创建权限相关错误
    static func permissions(
        _ message: String,
        underlying: Error? = nil,
        severity: ErrorSeverity = .high,
        suggestion: String? = nil
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "PER_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: message,
            recoverySuggestion: suggestion ?? "请在系统设置中授予相应权限",
            underlyingError: underlying,
            severity: severity,
            category: .permissions
        )
    }
    
    /// 创建数据相关错误
    static func data(
        _ message: String,
        underlying: Error? = nil,
        severity: ErrorSeverity = .medium,
        suggestion: String? = nil
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "DAT_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: message,
            recoverySuggestion: suggestion ?? "请检查数据格式或重新输入",
            underlyingError: underlying,
            severity: severity,
            category: .data
        )
    }
    
    /// 创建用户输入错误
    static func userInput(
        _ message: String,
        severity: ErrorSeverity = .low,
        suggestion: String? = nil
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "INP_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: message,
            recoverySuggestion: suggestion ?? "请检查输入内容并重试",
            underlyingError: nil,
            severity: severity,
            category: .userInput
        )
    }
    
    /// 创建配置相关错误
    static func configuration(
        _ message: String,
        underlying: Error? = nil,
        severity: ErrorSeverity = .medium,
        suggestion: String? = nil
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "CFG_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: message,
            recoverySuggestion: suggestion ?? "请检查应用设置或重置为默认值",
            underlyingError: underlying,
            severity: severity,
            category: .configuration
        )
    }
    
    /// 创建系统错误
    static func system(
        _ message: String,
        underlying: Error? = nil,
        severity: ErrorSeverity = .high,
        suggestion: String? = nil
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "SYS_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: message,
            recoverySuggestion: suggestion ?? "请重启应用或系统",
            underlyingError: underlying,
            severity: severity,
            category: .system
        )
    }
    
    /// 创建未知错误
    static func unknown(
        _ underlying: Error,
        severity: ErrorSeverity = .medium
    ) -> UnifiedAppError {
        UnifiedAppError(
            errorId: "UNK_\(Int(Date().timeIntervalSince1970))",
            timestamp: Date(),
            userMessage: "发生未知错误",
            recoverySuggestion: "请稍后重试或联系技术支持",
            underlyingError: underlying,
            severity: severity,
            category: .unknown
        )
    }
}

// MARK: - 错误转换器

/// 错误转换器 - 将其他类型错误转换为统一错误
enum ErrorConverter {
    /// 转换存储错误
    static func fromStorageError(_ error: StorageOperationError) -> UnifiedAppError {
        switch error {
        case .itemNotFound(let id):
            return ErrorBuilder.storage("项目未找到 (ID: \(id.uuidString))", severity: .low)
        case .corruptedData(let location):
            return ErrorBuilder.storage("数据损坏：\(location)", severity: .high, suggestion: "请尝试恢复备份或重新初始化")
        case .diskFull(let requiredSpace):
            let size = ByteCountFormatter.string(fromByteCount: requiredSpace, countStyle: .file)
            return ErrorBuilder.storage("磁盘空间不足，需要 \(size)", severity: .high, suggestion: "请清理磁盘空间或选择其他存储位置")
        case .unauthorized(let path):
            return ErrorBuilder.permissions("无权限访问：\(path)", severity: .high)
        case .networkUnavailable:
            return ErrorBuilder.network("网络连接不可用", severity: .medium)
        case .serializationFailed(let underlying):
            return ErrorBuilder.data("数据序列化失败", underlying: underlying)
        case .deserializationFailed(let underlying):
            return ErrorBuilder.data("数据反序列化失败", underlying: underlying)
        case .migrationFailed(let from, let to, let underlying):
            return ErrorBuilder.storage("数据迁移失败：\(from) → \(to)", underlying: underlying, severity: .high)
        case .cacheExpired(let id):
            return ErrorBuilder.storage("缓存已过期 (ID: \(id.uuidString))", severity: .low, suggestion: "数据可能已更新，请刷新后重试")
        case .operationCancelled:
            return ErrorBuilder.data("操作被取消", severity: .info)
        case .unknown(let underlying):
            return ErrorBuilder.unknown(underlying)
        }
    }
    
    /// 转换标准错误
    static func fromStandardError(_ error: Error, context: ErrorCategory = .unknown) -> UnifiedAppError {
        // 如果已经是统一错误，直接返回
        if let appError = error as? UnifiedAppError {
            return appError
        }
        
        // 根据错误类型进行分类转换
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("disk") || errorDescription.contains("space") {
            return ErrorBuilder.storage("磁盘相关错误", underlying: error)
        } else if errorDescription.contains("permission") || errorDescription.contains("unauthorized") {
            return ErrorBuilder.permissions("权限相关错误", underlying: error)
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            return ErrorBuilder.network("网络相关错误", underlying: error)
        } else if errorDescription.contains("corrupt") || errorDescription.contains("invalid") {
            return ErrorBuilder.data("数据格式错误", underlying: error)
        } else {
            return ErrorBuilder.unknown(error)
        }
    }
}

// MARK: - 错误处理器

/// 全局错误处理器
@MainActor
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    // MARK: - Properties
    
    private(set) var recentErrors: [UnifiedAppError] = []
    private(set) var errorCount: Int = 0
    private let maxRecentErrors = 50
    
    // 错误统计
    private var errorStatistics: [ErrorCategory: Int] = [:]
    private var criticalErrorCount: Int = 0
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 处理错误
    func handle(_ error: some AppError) {
        let unifiedError = error as? UnifiedAppError ?? ErrorConverter.fromStandardError(error)
        
        // 添加到最近错误列表
        addToRecentErrors(unifiedError)
        
        // 更新统计
        updateStatistics(unifiedError)
        
        // 记录到日志系统
        logError(unifiedError)
        
        // 根据严重程度进行不同处理
        handleBySeverity(unifiedError)
    }
    
    /// 安全地处理可能抛出错误的异步操作
    func safeAsync<T>(
        _ operation: @escaping () async throws -> T,
        onSuccess: ((T) -> Void)? = nil,
        onError: ((UnifiedAppError) -> Void)? = nil
    ) async {
        do {
            let result = try await operation()
            onSuccess?(result)
        } catch {
            let appError = error as? UnifiedAppError ?? ErrorConverter.fromStandardError(error)
            handle(appError)
            onError?(appError)
        }
    }
    
    /// 安全地处理可能抛出错误的同步操作
    func safeSync<T>(
        _ operation: () throws -> T,
        onSuccess: ((T) -> Void)? = nil,
        onError: ((UnifiedAppError) -> Void)? = nil
    ) {
        do {
            let result = try operation()
            onSuccess?(result)
        } catch {
            let appError = error as? UnifiedAppError ?? ErrorConverter.fromStandardError(error)
            handle(appError)
            onError?(appError)
        }
    }
    
    /// 获取错误统计
    func getStatistics() -> ErrorStatistics {
        ErrorStatistics(
            totalErrors: errorCount,
            criticalErrors: criticalErrorCount,
            recentErrorsCount: recentErrors.count,
            categoryStatistics: errorStatistics,
            lastErrorTime: recentErrors.last?.timestamp
        )
    }
    
    /// 清除错误历史
    func clearHistory() {
        recentErrors.removeAll()
        errorStatistics.removeAll()
        criticalErrorCount = 0
        errorCount = 0
    }
    
    // MARK: - Private Methods
    
    private func addToRecentErrors(_ error: UnifiedAppError) {
        recentErrors.insert(error, at: 0)
        
        // 保持列表大小
        if recentErrors.count > maxRecentErrors {
            recentErrors = Array(recentErrors.prefix(maxRecentErrors))
        }
        
        errorCount += 1
    }
    
    private func updateStatistics(_ error: UnifiedAppError) {
        errorStatistics[error.category, default: 0] += 1
        
        if error.severity == .critical {
            criticalErrorCount += 1
        }
    }
    
    private func logError(_ error: UnifiedAppError) {
        // 这里应该集成真实的日志系统
        // 现在使用print作为占位符
        if error.severity == .critical {
            print("🚨 CRITICAL ERROR: \(error.debugDescription)")
        } else if error.severity == .high {
            print("⚠️ HIGH ERROR: \(error.userMessage)")
        } else {
            print("⚡ ERROR: \(error.userMessage)")
        }
    }
    
    private func handleBySeverity(_ error: UnifiedAppError) {
        switch error.severity {
        case .critical:
            handleCriticalError(error)
        case .high:
            handleHighSeverityError(error)
        case .medium:
            handleMediumSeverityError(error)
        case .low, .info:
            // 低优先级错误只是记录，不需要特殊处理
            break
        }
    }
    
    private func handleCriticalError(_ error: UnifiedAppError) {
        // 致命错误：显示对话框，可能需要重启应用
        showCriticalErrorAlert(error)
        
        // 如果连续出现致命错误，可能需要提示用户重启
        if criticalErrorCount > 5 {
            showRestartSuggestion()
        }
    }
    
    private func handleHighSeverityError(_ error: UnifiedAppError) {
        // 严重错误：显示错误提示
        showErrorNotification(error)
    }
    
    private func handleMediumSeverityError(_ error: UnifiedAppError) {
        // 中等错误：显示非侵入性提示
        showNonIntrusiveNotification(error)
    }
    
    // MARK: - Error Display (Placeholder implementations)
    
    private func showCriticalErrorAlert(_ error: UnifiedAppError) {
        // 在实际应用中，这里会显示模态对话框
        print("🚨 Critical Error Alert: \(error.userMessage)")
    }
    
    private func showErrorNotification(_ error: UnifiedAppError) {
        // 在实际应用中，这里会显示通知
        print("⚠️ Error Notification: \(error.userMessage)")
    }
    
    private func showNonIntrusiveNotification(_ error: UnifiedAppError) {
        // 在实际应用中，这里会显示非侵入性提示
        print("ℹ️ Non-intrusive Error: \(error.userMessage)")
    }
    
    private func showRestartSuggestion() {
        // 建议用户重启应用
        print("💡 建议重启应用以解决连续错误")
    }
}

// MARK: - 错误统计

/// 错误统计信息
struct ErrorStatistics {
    let totalErrors: Int
    let criticalErrors: Int
    let recentErrorsCount: Int
    let categoryStatistics: [ErrorCategory: Int]
    let lastErrorTime: Date?
    
    var description: String {
        """
        错误统计:
        - 总错误数: \(totalErrors)
        - 致命错误: \(criticalErrors)
        - 最近错误: \(recentErrorsCount)
        - 最后错误时间: \(lastErrorTime?.description ?? "无")
        - 分类统计: \(categoryStatistics.map { "\($0.key.displayName): \($0.value)" }.joined(separator: ", "))
        """
    }
}

// MARK: - 便捷扩展

extension ErrorHandler {
    /// 创建并处理存储错误
    func handleStorageError(_ error: StorageOperationError) {
        let appError = ErrorConverter.fromStorageError(error)
        handle(appError)
    }
    
    /// 安全执行异步操作并处理错误
    func safeAsyncOperation<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try await operation()
                    continuation.resume(returning: result)
                } catch {
                    let appError = error as? UnifiedAppError ?? ErrorConverter.fromStandardError(error)
                    handle(appError)
                    continuation.resume(throwing: appError)
                }
            }
        }
    }
}
