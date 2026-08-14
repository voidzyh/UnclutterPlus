import SwiftUI
import Combine

// MARK: - Error State

/// 错误状态模型
struct ErrorState: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let suggestion: String?
    let category: ErrorCategory
    let errorCode: String
    let timestamp: Date

    init(
        title: String,
        message: String,
        suggestion: String? = nil,
        category: ErrorCategory,
        errorCode: String
    ) {
        self.title = title
        self.message = message
        self.suggestion = suggestion
        self.category = category
        self.errorCode = errorCode
        self.timestamp = Date()
    }

    /// 从 UnclutterError 创建 ErrorState
    init(from error: UnclutterError) {
        self.title = error.category.rawValue
        self.message = error.userMessage
        self.suggestion = error.recoverySuggestion
        self.category = error.category
        self.errorCode = error.errorCode
        self.timestamp = Date()
    }

    /// 从普通 Error 创建 ErrorState
    init(from error: Error) {
        let unclutterError = error.asUnclutterError()
        self.title = unclutterError.category.rawValue
        self.message = unclutterError.userMessage
        self.suggestion = unclutterError.recoverySuggestion
        self.category = unclutterError.category
        self.errorCode = unclutterError.errorCode
        self.timestamp = Date()
    }

    // MARK: - Equatable

    static func == (lhs: ErrorState, rhs: ErrorState) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Global Error Handler

/// 全局错误处理器
///
/// 负责集中处理所有应用级别的错误，提供统一的错误展示和恢复机制
@MainActor
final class GlobalErrorHandler: ObservableObject {
    // MARK: - Singleton

    static let shared = GlobalErrorHandler()

    // MARK: - Published Properties

    /// 当前活跃的错误（用于显示错误对话框）
    @Published private(set) var currentError: ErrorState?

    /// 错误历史记录（最多保留 100 条）
    @Published private(set) var errorHistory: [ErrorState] = []

    /// 错误统计
    @Published private(set) var errorStatistics: ErrorStatistics = ErrorStatistics()

    // MARK: - Private Properties

    private var errorQueue: [ErrorState] = []
    private let maxHistorySize = 100
    private let debounceDelay: TimeInterval = 0.5 // 防抖延迟（秒）

    // MARK: - Initialization

    private init() {
        logger.info("全局错误处理器初始化完成", category: "Service")
    }

    // MARK: - Public Methods

    /// 处理错误（主要方法）
    ///
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文信息（如执行的操作）
    ///   - showAlert: 是否立即显示错误对话框（默认 true）
    ///   - file: 错误发生的文件
    ///   - function: 错误发生的函数
    ///   - line: 错误发生的行号
    func handle(
        _ error: Error,
        context: String = "",
        showAlert: Bool = true,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // 转换为 UnclutterError
        let unclutterError = error.asUnclutterError()

        // 创建 ErrorState
        let errorState = ErrorState(from: unclutterError)

        // 记录错误日志
        unclutterError.log(context: context, file: file, function: function, line: line)

        // 更新统计
        updateStatistics(for: unclutterError)

        // 添加到历史记录
        addToHistory(errorState)

        // 决定是否显示错误对话框
        if showAlert {
            showError(errorState)
        } else {
            // 如果不立即显示，加入队列
            errorQueue.append(errorState)
        }
    }

    /// 处理 UnclutterError（便捷方法）
    func handle(
        _ error: UnclutterError,
        context: String = "",
        showAlert: Bool = true
    ) {
        handle(
            error as Error,
            context: context,
            showAlert: showAlert
        )
    }

    /// 清除当前错误
    func clearCurrentError() {
        currentError = nil
    }

    /// 清除错误历史
    func clearHistory() {
        errorHistory.removeAll()
        errorStatistics = ErrorStatistics()
        logger.info("错误历史已清空", category: "Service")
    }

    /// 显示错误队列中的下一个错误
    func showNextError() {
        if !errorQueue.isEmpty {
            let nextError = errorQueue.removeFirst()
            showError(nextError)
        }
    }

    /// 获取最近的 N 个错误
    func recentErrors(count: Int = 10) -> [ErrorState] {
        return Array(errorHistory.prefix(count))
    }

    /// 按分类获取错误
    func errors(by category: ErrorCategory) -> [ErrorState] {
        return errorHistory.filter { $0.category == category }
    }

    // MARK: - Private Methods

    /// 显示错误对话框
    private func showError(_ errorState: ErrorState) {
        // 使用防抖避免错误对话框闪烁
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: UInt64(self.debounceDelay * 1_000_000_000))

            // 如果没有当前错误，或者新错误更严重，则显示
            if self.currentError == nil ||
               self.shouldReplaceError(current: self.currentError!, new: errorState) {
                self.currentError = errorState
            }
        }
    }

    /// 判断是否应该替换当前错误
    private func shouldReplaceError(current: ErrorState, new: ErrorState) -> Bool {
        // 如果时间间隔超过 2 秒，替换
        let timeInterval = new.timestamp.timeIntervalSince(current.timestamp)
        if timeInterval > 2.0 {
            return true
        }

        // 如果新错误更严重，替换
        let severityOrder: [ErrorCategory] = [
            .permission, .storage, .system, .validation, .network, .unknown
        ]

        if let currentIdx = severityOrder.firstIndex(of: current.category),
           let newIdx = severityOrder.firstIndex(of: new.category) {
            return newIdx < currentIdx
        }

        return false
    }

    /// 添加到历史记录
    private func addToHistory(_ errorState: ErrorState) {
        errorHistory.insert(errorState, at: 0)

        // 限制历史记录大小
        if errorHistory.count > maxHistorySize {
            errorHistory = Array(errorHistory.prefix(maxHistorySize))
        }

        // 发布更新通知
        objectWillChange.send()
    }

    /// 更新错误统计
    private func updateStatistics(for error: UnclutterError) {
        errorStatistics.totalCount += 1

        switch error.category {
        case .storage:
            errorStatistics.storageCount += 1
        case .network:
            errorStatistics.networkCount += 1
        case .validation:
            errorStatistics.validationCount += 1
        case .permission:
            errorStatistics.permissionCount += 1
        case .system:
            errorStatistics.systemCount += 1
        case .unknown:
            errorStatistics.unknownCount += 1
        }

        // 更新最后错误时间
        errorStatistics.lastErrorTime = Date()
    }

    // MARK: - Error Recovery

    /// 尝试从错误中恢复
    ///
    /// - Parameters:
    ///   - errorState: 错误状态
    ///   - recoveryAction: 恢复操作（如重试、打开设置等）
    func recover(from errorState: ErrorState, recoveryAction: (() -> Void)? = nil) {
        logger.info("尝试从错误恢复: \(errorState.errorCode)", category: "Service")

        // 清除当前错误
        clearCurrentError()

        // 执行恢复操作
        recoveryAction?()

        // 如果队列中有其他错误，显示下一个
        showNextError()
    }

    /// 重试操作（带错误处理）
    ///
    /// - Parameters:
    ///   - operation: 要重试的操作
    ///   - maxRetries: 最大重试次数（默认 3）
    ///   - delay: 重试延迟（秒，默认 1.0）
    /// - Returns: 操作结果
    func retry<T>(
        _ operation: @escaping () async throws -> T,
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // 如果是最后一次尝试，抛出错误
                if attempt == maxRetries - 1 {
                    break
                }

                // 记录重试
                logger.warning(
                    "操作失败，\(delay) 秒后重试（第 \(attempt + 1)/\(maxRetries) 次）",
                    category: "Service"
                )

                // 等待后重试
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // 所有重试都失败，处理错误
        if let error = lastError {
            handle(error, context: "重试失败", showAlert: true)
            throw error
        }

        fatalError("retry: 逻辑错误")
    }
}

// MARK: - Error Statistics

/// 错误统计信息
struct ErrorStatistics {
    var totalCount: Int = 0
    var storageCount: Int = 0
    var networkCount: Int = 0
    var validationCount: Int = 0
    var permissionCount: Int = 0
    var systemCount: Int = 0
    var unknownCount: Int = 0
    var lastErrorTime: Date?

    /// 按分类获取错误数量
    func count(for category: ErrorCategory) -> Int {
        switch category {
        case .storage:    return storageCount
        case .network:    return networkCount
        case .validation: return validationCount
        case .permission: return permissionCount
        case .system:     return systemCount
        case .unknown:    return unknownCount
        }
    }

    /// 获取最常见的错误分类
    var mostCommonCategory: ErrorCategory? {
        let categories: [ErrorCategory] = [
            .storage, .network, .validation, .permission, .system, .unknown
        ]

        return categories.max { category1, category2 in
            count(for: category1) < count(for: category2)
        }
    }
}

// MARK: - Convenience Extensions

/// 便捷的错误处理扩展
extension Result {
    /// 处理 Result 类型，自动处理错误（异步方法）
    @discardableResult
    func handleError(
        context: String = "",
        showAlert: Bool = true,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async -> Success? {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            await GlobalErrorHandler.shared.handle(
                error,
                context: context,
                showAlert: showAlert,
                file: file,
                function: function,
                line: line
            )
            return nil
        }
    }
}

/// 便捷的异步错误处理
extension Task where Failure == Error {
    /// 启动任务并自动处理错误
    @discardableResult
    static func withErrorHandling(
        operation: @escaping () async throws -> Success,
        context: String = "",
        showAlert: Bool = true
    ) -> Task<Success, Error> {
        Task {
            do {
                return try await operation()
            } catch {
                await GlobalErrorHandler.shared.handle(
                    error,
                    context: context,
                    showAlert: showAlert
                )
                throw error  // 重新抛出错误
            }
        }
    }
}
