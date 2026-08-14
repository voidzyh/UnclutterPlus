import Foundation

/// 搜索输入防抖器（Task 化，替代 Notes/Clipboard/Files 三个 VM 重复的 Combine debounce 样板）
///
/// 用法：
/// ```swift
/// @Published var searchText: String = "" { didSet { debouncer.queryChanged(searchText) } }
/// private lazy var debouncer = SearchDebouncer { [weak self] _ in self?.applyFilters() }
/// ```
@MainActor
final class SearchDebouncer {
    private let interval: TimeInterval
    private let onQuery: @MainActor (String) -> Void
    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - interval: 防抖间隔（默认 0.3s，与原三段式一致）
    ///   - onQuery: 防抖结束后在主线程执行的回调
    init(interval: TimeInterval = 0.3, onQuery: @escaping @MainActor (String) -> Void) {
        self.interval = interval
        self.onQuery = onQuery
    }

    /// 查询文本变化：取消窗口内的旧任务并重新计时
    func queryChanged(_ query: String) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.onQuery(query)
        }
    }

    /// 取消未决的防抖任务
    func cancel() {
        task?.cancel()
        task = nil
    }
}
