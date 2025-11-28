import Foundation
import Combine

// MARK: - 任务状态

/// 异步任务状态
enum TaskState: String, CaseIterable {
    case pending = "pending"      // 等待执行
    case running = "running"     // 正在执行
    case completed = "completed" // 已完成
    case cancelled = "cancelled" // 已取消
    case failed = "failed"       // 执行失败
    case timeout = "timeout"     // 超时
    
    var isActive: Bool {
        switch self {
        case .pending, .running:
            return true
        case .completed, .cancelled, .failed, .timeout:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .pending: return "等待中"
        case .running: return "执行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .failed: return "执行失败"
        case .timeout: return "执行超时"
        }
    }
}

// MARK: - 任务结果

/// 异步任务结果
enum AsyncTaskResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
    case cancelled
    case timeout
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
    
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }
    
    var isTimeout: Bool {
        if case .timeout = self { return true }
        return false
    }
}

// MARK: - 任务配置

/// 异步任务配置
struct AsyncTaskConfiguration {
    let timeout: TimeInterval      // 超时时间
    let retryCount: Int            // 重试次数
    let retryDelay: TimeInterval   // 重试延迟
    let exponentialBackoff: Bool   // 指数退避
    let cancellable: Bool          // 是否可取消
    
    static let `default` = AsyncTaskConfiguration(
        timeout: 30.0,
        retryCount: 3,
        retryDelay: 1.0,
        exponentialBackoff: true,
        cancellable: true
    )
    
    static let fast = AsyncTaskConfiguration(
        timeout: 5.0,
        retryCount: 1,
        retryDelay: 0.5,
        exponentialBackoff: false,
        cancellable: true
    )
    
    static let background = AsyncTaskConfiguration(
        timeout: 120.0,
        retryCount: 5,
        retryDelay: 2.0,
        exponentialBackoff: true,
        cancellable: true
    )
    
    static let critical = AsyncTaskConfiguration(
        timeout: 60.0,
        retryCount: 10,
        retryDelay: 0.1,
        exponentialBackoff: true,
        cancellable: false
    )
}

// MARK: - 异步任务协议

/// 异步任务协议
protocol AsyncTask {
    associatedtype ResultType
    
    var id: UUID { get }
    var name: String { get }
    var configuration: AsyncTaskConfiguration { get }
    var state: TaskState { get }
    var progress: Double { get }
    var createdAt: Date { get }
    var startedAt: Date? { get }
    var completedAt: Date? { get }
    
    func execute() async -> AsyncTaskResult<ResultType, Error>
    func cancel()
    func pause()
    func resume()
}

// MARK: - 具体任务实现

/// 基础异步任务实现
final class BaseAsyncTask<ResultType>: AsyncTask {
    let id = UUID()
    let name: String
    let configuration: AsyncTaskConfiguration
    let operation: () async throws -> ResultType
    
    // 状态管理
    private let stateQueue = DispatchQueue(label: "task.state", qos: .userInitiated)
    private var _state: TaskState = .pending
    private var _progress: Double = 0.0
    private var _startedAt: Date?
    private var _completedAt: Date?
    
    // 取消机制
    private var isCancelled = false
    private var isPaused = false
    private let pauseResumeSemaphore = DispatchSemaphore(value: 1)
    
    // 进度回调
    var onProgress: ((Double) -> Void)?
    var onStateChange: ((TaskState) -> Void)?
    
    var state: TaskState {
        get { stateQueue.sync { _state } }
        set {
            stateQueue.async {
                self._state = newValue
                DispatchQueue.main.async {
                    self.onStateChange?(newValue)
                }
            }
        }
    }
    
    var progress: Double {
        get { stateQueue.sync { _progress } }
        set {
            stateQueue.async {
                self._progress = newValue
                DispatchQueue.main.async {
                    self.onProgress?(newValue)
                }
            }
        }
    }
    
    var startedAt: Date? {
        stateQueue.sync { _startedAt }
    }
    
    var completedAt: Date? {
        stateQueue.sync { _completedAt }
    }
    
    init(
        name: String,
        configuration: AsyncTaskConfiguration = .default,
        operation: @escaping () async throws -> ResultType
    ) {
        self.name = name
        self.configuration = configuration
        self.operation = operation
    }
    
    func execute() async -> AsyncTaskResult<ResultType, Error> {
        guard configuration.cancellable else {
            state = .running
            _startedAt = Date()
            return await performExecution()
        }
        
        // 检查是否已取消
        if isCancelled {
            state = .cancelled
            return .cancelled
        }
        
        state = .running
        _startedAt = Date()
        
        // 执行重试逻辑
        return await executeWithRetry()
    }
    
    private func executeWithRetry() async -> AsyncTaskResult<ResultType, Error> {
        var lastError: Error?
        var attempt = 0
        
        while attempt <= configuration.retryCount {
            // 检查取消状态
            if isCancelled {
                state = .cancelled
                return .cancelled
            }
            
            // 等待暂停恢复
            pauseResumeSemaphore.wait()
            pauseResumeSemaphore.signal()
            
            if isPaused {
                // 等待恢复
                await waitForResume()
            }
            
            // 执行操作
            let result = await performExecution()
            
            switch result {
            case .success:
                return result
            case .cancelled:
                return result
            case .timeout:
                return result
            case .failure(let error):
                lastError = error
                attempt += 1
                
                if attempt <= configuration.retryCount {
                    // 计算延迟时间
                    let delay = calculateRetryDelay(attempt: attempt)
                    await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 所有重试都失败
        state = .failed
        _completedAt = Date()
        return .failure(lastError!)
    }
    
    private func performExecution() async -> AsyncTaskResult<ResultType, Error> {
        // 创建超时任务
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(configuration.timeout * 1_000_000_000))
            return AsyncTaskResult<ResultType, Error>.timeout
        }
        
        // 创建主任务
        let mainTask = Task {
            do {
                // 检查取消状态
                if configuration.cancellable && isCancelled {
                    timeoutTask.cancel()
                    return .cancelled
                }
                
                // 执行实际操作
                let result = try await operation()
                timeoutTask.cancel()
                return .success(result)
                
            } catch {
                timeoutTask.cancel()
                return .failure(error)
            }
        }
        
        // 等待任一任务完成
        for await result in [mainTask, timeoutTask].async {
            switch result {
            case .success(let successResult):
                state = .completed
                _completedAt = Date()
                return successResult
            case .timeout:
                state = .timeout
                _completedAt = Date()
                return .timeout
            case .cancelled:
                state = .cancelled
                _completedAt = Date()
                return .cancelled
            case .failure(let error):
                state = .failed
                _completedAt = Date()
                return .failure(error)
            }
        }
        
        return .timeout
    }
    
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        if configuration.exponentialBackoff {
            return configuration.retryDelay * pow(2.0, Double(attempt - 1))
        } else {
            return configuration.retryDelay
        }
    }
    
    private func waitForResume() async {
        while isPaused {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒检查一次
        }
    }
    
    func cancel() {
        guard configuration.cancellable else { return }
        
        stateQueue.async {
            self.isCancelled = true
        }
    }
    
    func pause() {
        guard configuration.cancellable else { return }
        
        stateQueue.async {
            self.isPaused = true
        }
    }
    
    func resume() {
        guard configuration.cancellable else { return }
        
        stateQueue.async {
            self.isPaused = false
        }
    }
}

// MARK: - 任务管理器

/// 异步任务管理器
@MainActor
final class AsyncTaskManager: ObservableObject {
    static let shared = AsyncTaskManager()
    
    // MARK: - Properties
    
    private var tasks: [UUID: any AsyncTask] = [:]
    private var taskQueue = DispatchQueue(label: "task.manager.queue", qos: .userInitiated)
    private var taskObservers: [UUID: [TaskObserver]] = [:]
    
    @Published private(set) var activeTasks: [UUID: TaskState] = [:]
    @Published private(set) var completedTasks: [UUID: (state: TaskState, duration: TimeInterval)] = [:]
    
    // 统计
    private var totalTasksExecuted: Int64 = 0
    private var totalTasksCompleted: Int64 = 0
    private var totalTasksFailed: Int64 = 0
    private var totalTasksCancelled: Int64 = 0
    private var totalExecutionTime: TimeInterval = 0
    
    private init() {
        setupCleanupTimer()
    }
    
    // MARK: - Public Methods
    
    /// 执行异步任务
    func execute<Success>(
        name: String,
        configuration: AsyncTaskConfiguration = .default,
        operation: @escaping () async throws -> Success
    ) async -> AsyncTaskResult<Success, Error> {
        
        let task = BaseAsyncTask<Success>(
            name: name,
            configuration: configuration,
            operation: operation
        )
        
        return await executeTask(task)
    }
    
    /// 执行带进度的异步任务
    func executeWithProgress<Success>(
        name: String,
        configuration: AsyncTaskConfiguration = .default,
        progressHandler: @escaping (Double) -> Void,
        operation: @escaping (Double) async throws -> Success
    ) async -> AsyncTaskResult<Success, Error> {
        
        let task = BaseAsyncTask<Success>(
            name: name,
            configuration: configuration
        ) {
            let result = try await operation(progressHandler)
            return result
        }
        
        return await executeTask(task)
    }
    
    /// 批量执行任务
    func executeBatch<Success>(
        tasks: [(String, AsyncTaskConfiguration, () async throws -> Success)],
        concurrent: Bool = true,
        maxConcurrent: Int = 5
    ) async -> [AsyncTaskResult<Success, Error>] {
        
        if concurrent {
            return await executeConcurrent(tasks, maxConcurrent: maxConcurrent)
        } else {
            return await executeSequential(tasks)
        }
    }
    
    /// 取消任务
    func cancelTask(_ id: UUID) {
        guard let task = tasks[id] else { return }
        
        task.cancel()
        updateTaskState(id, to: .cancelled)
        removeTaskAfterDelay(id, delay: 5.0)
    }
    
    /// 暂停任务
    func pauseTask(_ id: UUID) {
        guard let task = tasks[id] else { return }
        task.pause()
        updateTaskState(id, to: .pending)
    }
    
    /// 恢复任务
    func resumeTask(_ id: UUID) {
        guard let task = tasks[id] else { return }
        task.resume()
        updateTaskState(id, to: .running)
    }
    
    /// 获取任务状态
    func getTaskState(_ id: UUID) -> TaskState? {
        activeTasks[id] ?? completedTasks[id]?.state
    }
    
    /// 获取任务统计
    func getStatistics() -> TaskStatistics {
        TaskStatistics(
            totalTasks: totalTasksExecuted,
            activeTasks: activeTasks.count,
            completedTasks: totalTasksCompleted,
            failedTasks: totalTasksFailed,
            cancelledTasks: totalTasksCancelled,
            averageExecutionTime: totalTasksCompleted > 0 ? totalExecutionTime / Double(totalTasksCompleted) : 0
        )
    }
    
    /// 清除已完成的任务
    func cleanupCompletedTasks() {
        completedTasks.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func executeTask<Success>(_ task: BaseAsyncTask<Success>) async -> AsyncTaskResult<Success, Error> {
        let taskId = task.id
        
        // 添加到任务列表
        tasks[taskId] = task
        activeTasks[taskId] = .pending
        
        // 设置回调
        task.onStateChange = { [weak self] state in
            self?.updateTaskState(taskId, to: state)
        }
        
        task.onProgress = { [weak self] progress in
            // 进度更新不需要特别处理，因为TaskState已经包含了状态管理
        }
        
        totalTasksExecuted += 1
        
        // 执行任务
        let result = await task.execute()
        
        // 记录结果
        recordTaskResult(taskId, result: result, startTime: task.startedAt ?? Date())
        
        return result
    }
    
    private func executeSequential<Success>(_ tasks: [(String, AsyncTaskConfiguration, () async throws -> Success)]) async -> [AsyncTaskResult<Success, Error>] {
        var results: [AsyncTaskResult<Success, Error>] = []
        
        for (name, config, operation) in tasks {
            let result = await execute(name: name, configuration: config, operation: operation)
            results.append(result)
        }
        
        return results
    }
    
    private func executeConcurrent<Success>(_ tasks: [(String, AsyncTaskConfiguration, () async throws -> Success)], maxConcurrent: Int) async -> [AsyncTaskResult<Success, Error>] {
        var results: [AsyncTaskResult<Success, Error>] = []
        var semaphore = DispatchSemaphore(value: maxConcurrent)
        
        await withTaskGroup(of: (Int, AsyncTaskResult<Success, Error>).self) { group in
            for (index, (name, config, operation)) in tasks.enumerated() {
                group.addTask {
                    semaphore.wait()
                    defer { semaphore.signal() }
                    
                    let result = await AsyncTaskManager.shared.execute(name: name, configuration: config, operation: operation)
                    return (index, result)
                }
            }
            
            for await (index, result) in group {
                results.append(result)
            }
        }
        
        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
    
    private func updateTaskState(_ id: UUID, to state: TaskState) {
        if state.isActive {
            activeTasks[id] = state
        } else {
            if let completedState = activeTasks[id] {
                completedTasks[id] = (state: state, duration: 0) // 实际duration在recordTaskResult中设置
            }
            activeTasks.removeValue(forKey: id)
            removeTaskAfterDelay(id, delay: 30.0)
        }
    }
    
    private func recordTaskResult<Success>(_ id: UUID, result: AsyncTaskResult<Success, Error>, startTime: Date) {
        let duration = Date().timeIntervalSince(startTime)
        totalExecutionTime += duration
        totalTasksCompleted += 1
        
        switch result {
        case .failure:
            totalTasksFailed += 1
        case .cancelled:
            totalTasksCancelled += 1
        case .success, .timeout:
            break
        }
        
        // 更新完成时间
        if var taskRecord = completedTasks[id] {
            taskRecord.duration = duration
            completedTasks[id] = taskRecord
        }
        
        // 清理原始任务
        tasks.removeValue(forKey: id)
        
        // 通知观察者
        notifyObservers(id, result: result)
    }
    
    private func removeTaskAfterDelay(_ id: UUID, delay: TimeInterval) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            completedTasks.removeValue(forKey: id)
        }
    }
    
    private func notifyObservers<Success>(_ id: UUID, result: AsyncTaskResult<Success, Error>) {
        guard let observers = taskObservers[id] else { return }
        
        for observer in observers {
            observer.onCompleted(result)
        }
        
        taskObservers.removeValue(forKey: id)
    }
    
    private func setupCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupCompletedTasks()
        }
    }
}

// MARK: - 任务观察者

/// 任务观察者协议
protocol TaskObserver {
    func onCompleted<Success>(_ result: AsyncTaskResult<Success, Error>)
}

extension AsyncTaskManager {
    /// 添加任务观察者
    func addObserver<Success>(_ observer: TaskObserver, forTask id: UUID) {
        if taskObservers[id] == nil {
            taskObservers[id] = []
        }
        taskObservers[id]?.append(observer)
    }
    
    /// 移除任务观察者
    func removeObserver(_ observer: TaskObserver, forTask id: UUID) {
        taskObservers[id]?.removeAll { $0 === observer }
    }
}

// MARK: - 任务统计

/// 任务统计信息
struct TaskStatistics: Sendable {
    let totalTasks: Int64
    let activeTasks: Int
    let completedTasks: Int64
    let failedTasks: Int64
    let cancelledTasks: Int64
    let averageExecutionTime: TimeInterval
    
    var successRate: Double {
        guard completedTasks > 0 else { return 0 }
        return Double(completedTasks - failedTasks - cancelledTasks) / Double(completedTasks)
    }
    
    var failureRate: Double {
        guard completedTasks > 0 else { return 0 }
        return Double(failedTasks) / Double(completedTasks)
    }
    
    var cancellationRate: Double {
        guard completedTasks > 0 else { return 0 }
        return Double(cancelledTasks) / Double(completedTasks)
    }
    
    var description: String {
        """
        异步任务统计:
        - 总任务数: \(totalTasks)
        - 活跃任务: \(activeTasks)
        - 已完成: \(completedTasks)
        - 执行失败: \(failedTasks)
        - 已取消: \(cancelledTasks)
        - 成功率: \(String(format: "%.2f%%", successRate * 100))
        - 平均执行时间: \(String(format: "%.3f秒", averageExecutionTime))
        """
    }
}

// MARK: - 便捷方法

extension AsyncTaskManager {
    /// 快速执行网络请求
    func executeNetworkRequest<Success>(
        name: String,
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 3,
        request: @escaping () async throws -> Success
    ) async -> AsyncTaskResult<Success, Error> {
        
        let config = AsyncTaskConfiguration(
            timeout: timeout,
            retryCount: maxRetries,
            retryDelay: 1.0,
            exponentialBackoff: true,
            cancellable: true
        )
        
        return await execute(name: name, configuration: config, operation: request)
    }
    
    /// 快速执行文件操作
    func executeFileOperation<Success>(
        name: String,
        operation: @escaping () async throws -> Success
    ) async -> AsyncTaskResult<Success, Error> {
        
        return await execute(name: name, configuration: .default, operation: operation)
    }
    
    /// 执行后台任务
    func executeBackgroundTask<Success>(
        name: String,
        operation: @escaping () async throws -> Success
    ) async -> AsyncTaskResult<Success, Error> {
        
        return await execute(name: name, configuration: .background, operation: operation)
    }
}
