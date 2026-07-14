import Foundation

// MARK: - AI 服务协议

/// AI 服务抽象 —— 支持整理笔记、聚类相似剪贴板片段、总结成文档。
///
/// 有两个实现：
/// - `HTTPAPIEngine`：调用 OpenAI/DeepSeek/GLM 等兼容 Chat Completions 的 HTTP API
/// - `LocalCLIEngine`：调用 ollama 等本地命令行工具
///
/// 通过 `AIServiceFactory.shared.makeService()` 按配置选择实现。
protocol AIService: AnyObject, Sendable {
    /// 整理笔记内容（润色/重写/生成标题摘要/打标签）。
    func organize(content: String, instruction: OrganizeInstruction) async throws -> OrganizeResult

    /// 将多条剪贴板片段按主题聚类（相似关联）。
    /// - Parameter items: 待聚类的片段列表（通常是高频项）
    /// - Parameter existingTopics: 已有的主题/标签，便于归类到既有体系
    func cluster(items: [String], existingTopics: [String]) async throws -> [AICluster]

    /// 将一个聚类组总结成一篇可学习文档。
    func summarize(cluster: AICluster) async throws -> DocumentDraft

    /// 服务标识（用于日志与诊断）。
    var displayName: String { get }
}

// MARK: - 整理指令与结果

/// AI 整理动作类型
enum OrganizeAction: String, Codable, Sendable, CaseIterable {
    case polish          // 润色正文
    case rewrite         // 重写
    case titleAndSummary // 生成标题与摘要
    case autoTag         // 自动打标签
}

/// 整理指令
struct OrganizeInstruction: Sendable {
    let action: OrganizeAction
    /// 额外上下文（如已有标签、风格要求），可选
    let context: String?

    init(action: OrganizeAction, context: String? = nil) {
        self.action = action
        self.context = context
    }
}

/// 整理结果
struct OrganizeResult: Sendable {
    let content: String      // 整理后的正文（润色/重写场景）
    let title: String?       // 生成的标题（titleAndSummary 场景）
    let summary: String?     // 生成的摘要（titleAndSummary 场景）
    let tags: [String]       // 建议标签（autoTag / 其他场景附带）
}

// MARK: - 聚类与文档

/// 一个聚类组：主题 + 该组包含的片段
struct AICluster: Identifiable, Sendable, Codable {
    let id: UUID
    let topic: String        // 主题名称（如"Git 操作"）
    let description: String  // 主题简述
    let items: [String]      // 该组包含的原始片段

    init(id: UUID = UUID(), topic: String, description: String, items: [String]) {
        self.id = id
        self.topic = topic
        self.description = description
        self.items = items
    }
}

/// AI 总结生成的文档草稿（用于导出 Obsidian / 存为笔记）
struct DocumentDraft: Identifiable, Sendable, Codable {
    let id: UUID
    let title: String
    let content: String  // Markdown 正文
    let tags: [String]
    let sourceClusterTopic: String?

    init(id: UUID = UUID(), title: String, content: String, tags: [String] = [], sourceClusterTopic: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.sourceClusterTopic = sourceClusterTopic
    }
}

// MARK: - 错误

/// AI 服务错误
enum AIServiceError: LocalizedError, Sendable {
    case notConfigured          // 未配置（缺 endpoint / key / CLI 路径）
    case invalidEndpoint(String)
    case requestFailed(String)  // 网络/HTTP 错误
    case invalidResponse(String) // 响应解析失败
    case apiError(code: Int, message: String) // API 返回业务错误
    case executionFailed(String) // CLI 执行失败
    case timedOut

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI 服务未配置"
        case .invalidEndpoint(let detail):
            return "AI 端点无效：\(detail)"
        case .requestFailed(let detail):
            return "AI 请求失败：\(detail)"
        case .invalidResponse(let detail):
            return "AI 响应解析失败：\(detail)"
        case .apiError(let code, let message):
            return "AI 服务错误（\(code)）：\(message)"
        case .executionFailed(let detail):
            return "AI 执行失败：\(detail)"
        case .timedOut:
            return "AI 请求超时"
        }
    }
}
