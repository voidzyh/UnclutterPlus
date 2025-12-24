import Foundation

/// 异步任务管理器 - 负责管理和执行异步任务
@MainActor
public final class AsyncTaskManager {
    public static let shared = AsyncTaskManager()

    private init() {}

    /// 执行异步任务
    public func execute<T>(
        name: String,
        task: @escaping () async throws -> T
    ) async throws -> T {
        logger.info("开始执行异步任务: \(name)", category: "Performance")
        let startTime = Date()

        do {
            let result = try await task()
            let duration = Date().timeIntervalSince(startTime)
            logger.info("完成异步任务: \(name) (耗时: \(String(format: "%.2f", duration))秒)", category: "Performance")
            return result
        } catch {
            logger.error("异步任务失败: \(name) - \(error)", category: "Performance")
            throw error
        }
    }

    /// 执行带超时的异步任务
    public func executeWithTimeout<T>(
        name: String,
        timeout: TimeInterval,
        task: @escaping () async throws -> T
    ) async throws -> T {
        logger.info("执行带超时的异步任务: \(name) (超时: \(timeout)秒)", category: "Performance")

        let result = try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await self.execute(name: name, task: task)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw CancellationError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        return result
    }
}
