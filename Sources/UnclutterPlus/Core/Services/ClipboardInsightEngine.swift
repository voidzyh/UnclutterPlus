import Foundation
import Combine

/// 剪贴板洞察引擎 —— 频率检测 + AI 相似聚类 + 文档总结。
///
/// 设计（用户确认）：
/// - 频率：基于 `useCount` 的本地精确统计，即时，不调 AI。
/// - 相似性：AI 知识库关联，按需触发批处理（不每次粘贴调 AI，控成本）。
///
/// 主流程 `generateInsights()`：
///   取高频文本项 → `AIService.cluster`（AI 聚类）→ 对每组 `AIService.summarize`（AI 总结）→ 产出 DocumentDraft。
@MainActor
final class ClipboardInsightEngine: ObservableObject {
    static let shared = ClipboardInsightEngine()

    // MARK: - Published

    /// 当前分析状态
    @Published private(set) var status: InsightStatus = .idle

    /// 最近一次高频项（供 UI 展示排行）
    @Published private(set) var highFrequencyItems: [HighFrequencyItem] = []

    /// 最近一次生成的文档草稿
    @Published private(set) var drafts: [DocumentDraft] = []

    /// 最近一次聚类结果（供 UI 展示分组）
    @Published private(set) var clusters: [AICluster] = []

    /// 最近一次错误
    @Published var lastError: String?

    // MARK: - Private

    private let repository = AppStorageManager.shared.clipboardRepository
    private var generateTask: Task<Void, Never>?

    // MARK: - Status

    enum InsightStatus: Equatable {
        case idle
        case analyzing(stage: AnalyzeStage)
        case completed
        case failed

        enum AnalyzeStage: String {
            case collecting = "正在收集高频项"
            case clustering = "正在 AI 聚类"
            case summarizing = "正在生成文档"
        }
    }

    /// 高频项视图模型
    struct HighFrequencyItem: Identifiable {
        let id: UUID
        let text: String
        let useCount: Int
        let sourceAppName: String?
        let lastUsed: Date
    }

    // MARK: - 频率检测（本地，即时，不调 AI）

    /// 从 repository 提取 useCount ≥ 阈值 的文本项，按频率排序。
    @discardableResult
    func refreshHighFrequencyItems() -> [HighFrequencyItem] {
        let threshold = ConfigurationManager.shared.insightsFrequencyThreshold
        return refreshHighFrequencyItems(threshold: threshold)
    }

    @discardableResult
    func refreshHighFrequencyItems(threshold: Int) -> [HighFrequencyItem] {
        var items: [HighFrequencyItem] = []
        for index in repository.clipboardIndexes where index.type == .text && index.useCount >= threshold {
            items.append(HighFrequencyItem(
                id: index.id,
                text: index.preview,
                useCount: index.useCount,
                sourceAppName: index.sourceApp,
                lastUsed: index.timestamp
            ))
        }
        items.sort { $0.useCount > $1.useCount }
        highFrequencyItems = items
        return items
    }

    /// 既有主题（从已生成草稿的标签汇聚），供 AI 聚类时归类到既有体系。
    private var existingTopics: [String] {
        Array(Set(drafts.flatMap { $0.tags })).sorted()
    }

    // MARK: - 生成洞察（AI 批处理，按需触发）

    /// 主流程：高频项 → AI 聚类 → 每组 AI 总结 → 文档草稿。
    /// 幂等：若已有进行中的任务则忽略。
    func generateInsights() {
        guard generateTask == nil else { return }
        guard AIServiceFactory.isConfigured else {
            lastError = "AI 服务未配置，请在偏好设置中配置"
            status = .failed
            return
        }

        guard let service = AIServiceFactory.makeService() else {
            lastError = "无法创建 AI 服务"
            status = .failed
            return
        }

        generateTask = Task { [weak self] in
            guard let self else { return }
            defer { self.generateTask = nil }

            self.lastError = nil
            self.status = .analyzing(stage: .collecting)

            // 1. 收集高频项（使用全部正文的预览；超长项截断以控制 token）
            let threshold = ConfigurationManager.shared.insightsFrequencyThreshold
            let freqItems = self.refreshHighFrequencyItems(threshold: threshold)
            guard !freqItems.isEmpty else {
                self.status = .completed
                self.drafts = []
                self.clusters = []
                return
            }

            // 取每项的文本作为聚类输入；单条上限 500 字符
            let inputs = freqItems.map { String($0.text.prefix(500)) }

            // 2. AI 聚类
            self.status = .analyzing(stage: .clustering)
            let clusters: [AICluster]
            do {
                clusters = try await service.cluster(items: inputs, existingTopics: self.existingTopics)
            } catch {
                self.lastError = error.localizedDescription
                self.status = .failed
                return
            }
            self.clusters = clusters

            // 3. 逐组 AI 总结
            self.status = .analyzing(stage: .summarizing)
            var newDrafts: [DocumentDraft] = []
            for cluster in clusters {
                if Task.isCancelled { break }
                do {
                    let draft = try await service.summarize(cluster: cluster)
                    newDrafts.append(draft)
                } catch {
                    // 单组失败不中断整体，记录日志
                    logger.error("总结聚类「\(cluster.topic)」失败：\(error.localizedDescription)", category: "InsightEngine")
                }
            }

            self.drafts = newDrafts
            self.status = newDrafts.isEmpty ? .failed : .completed
            if newDrafts.isEmpty, self.lastError == nil {
                self.lastError = "未能生成任何文档"
            }
        }
    }

    /// 取消正在进行的分析。
    func cancel() {
        generateTask?.cancel()
        generateTask = nil
        status = .idle
    }

    /// 清空已生成的草稿与聚类（不删除高频项统计）。
    func clearDrafts() {
        drafts = []
        clusters = []
        status = .idle
    }
}
