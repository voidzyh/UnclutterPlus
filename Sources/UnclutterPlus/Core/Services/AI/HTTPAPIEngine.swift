import Foundation

/// HTTP API 引擎 —— 调用 OpenAI/DeepSeek/GLM 等兼容 Chat Completions 的 API。
///
/// 这是项目首个基于 URLSession 的网络客户端。endpoint/apiKey/model 从
/// ConfigurationManager 读取，apiKey 经 KeychainWrapper 安全存储。
final class HTTPAPIEngine: AIService {
    let displayName = "HTTP AI API"

    private let endpoint: String
    private let apiKey: String
    private let model: String
    private let timeout: TimeInterval
    private let session: URLSession

    /// 直接配置（便于测试）。生产环境用 `AIServiceFactory`。
    init(endpoint: String, apiKey: String, model: String, timeout: TimeInterval = 60) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.timeout = timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - AIService

    func organize(content: String, instruction: OrganizeInstruction) async throws -> OrganizeResult {
        let prompt = Self.makeOrganizePrompt(content: content, action: instruction.action, context: instruction.context)
        switch instruction.action {
        case .titleAndSummary, .autoTag:
            let raw = try await chat(system: "你是笔记整理助手。只输出 JSON。", user: prompt, jsonMode: true)
            return try Self.decodeOrganize(raw: raw, action: instruction.action, fallbackContent: content)
        case .polish, .rewrite:
            let text = try await chat(system: "你是文字编辑助手，直接输出整理后的正文，不要解释。", user: prompt, jsonMode: false)
            return OrganizeResult(content: text.trimmingCharacters(in: .whitespacesAndNewlines), title: nil, summary: nil, tags: [])
        }
    }

    func cluster(items: [String], existingTopics: [String]) async throws -> [AICluster] {
        let prompt = Self.makeClusterPrompt(items: items, existingTopics: existingTopics)
        let raw = try await chat(system: "你是知识整理助手，擅长把相似指令归类。只输出 JSON。", user: prompt, jsonMode: true)
        return try Self.decodeClusters(raw: raw)
    }

    func summarize(cluster: AICluster) async throws -> DocumentDraft {
        let prompt = Self.makeSummarizePrompt(cluster: cluster)
        let raw = try await chat(system: "你是技术文档撰写助手，输出 Markdown，最终用 JSON 包裹。", user: prompt, jsonMode: true)
        return try Self.decodeSummary(raw: raw, cluster: cluster)
    }

    // MARK: - Chat Completion

    /// 发起一次 chat completion 请求，返回助手消息文本。
    private func chat(system: String, user: String, jsonMode: Bool) async throws -> String {
        guard !endpoint.isEmpty else { throw AIServiceError.notConfigured }
        guard !apiKey.isEmpty else { throw AIServiceError.notConfigured }

        guard let url = URL(string: endpoint) else {
            throw AIServiceError.invalidEndpoint(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.3
        ]
        if jsonMode {
            body["response_format"] = ["type": "json_object"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .timedOut { throw AIServiceError.timedOut }
            throw AIServiceError.requestFailed(urlError.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse("非 HTTP 响应")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.apiError(code: http.statusCode, message: message)
        }

        // 解析 OpenAI 兼容响应：choices[0].message.content
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse("无法解析 choices[0].message.content")
        }
        return content
    }

    // MARK: - Prompt 构建（供 LocalCLIEngine 复用）

    static func makeOrganizePrompt(content: String, action: OrganizeAction, context: String?) -> String {
        let ctx = context.map { "\n\n参考上下文：\($0)" } ?? ""
        switch action {
        case .polish:
            return "请润色以下文本，修正语法与表述，保持原意，不要改变技术细节：\n\n\(content)\(ctx)"
        case .rewrite:
            return "请重写以下文本，使其更清晰、专业，可调整结构：\n\n\(content)\(ctx)"
        case .titleAndSummary:
            return "为以下笔记生成标题与一句话摘要，并附带 3-5 个标签。仅返回 JSON：{\"title\":...,\"summary\":...,\"tags\":[...]}。\n\n\(content)\(ctx)"
        case .autoTag:
            return "为以下内容生成 3-5 个合适的标签。仅返回 JSON：{\"tags\":[\"...\"]}。\n\n\(content)\(ctx)"
        }
    }

    static func makeClusterPrompt(items: [String], existingTopics: [String]) -> String {
        let list = items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let topics = existingTopics.isEmpty ? "（无）" : existingTopics.joined(separator: "、")
        return """
        以下是用户高频使用的指令/片段。请将它们按主题聚类。同一指令的不同变体（如大小写/参数差异）归为一组。
        尽量归类到既有主题：\(topics)；如有新主题可新建。

        片段：
        \(list)

        仅返回 JSON：{"clusters":[{"topic":"主题名","description":"简述","items":["原片段"]}]}
        每个片段必须出现在某个组内，不要遗漏。
        """
    }

    static func makeSummarizePrompt(cluster: AICluster) -> String {
        let list = cluster.items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return """
        主题：\(cluster.topic)
        描述：\(cluster.description)

        以下是该主题下的指令片段：
        \(list)

        请撰写一篇 Markdown 学习文档，总结这些指令的用途、用法要点与常见场景。
        仅返回 JSON：{"title":"文档标题","content":"Markdown 正文","tags":["标签"]}
        """
    }

    // MARK: - JSON 解码（供 LocalCLIEngine 复用）

    struct TitleSummaryResponse: Decodable { let title: String; let summary: String; let tags: [String]? }
    struct TagsResponse: Decodable { let tags: [String] }
    struct ClusterResponse: Decodable { let clusters: [ClusterItem]; struct ClusterItem: Decodable { let topic: String; let description: String; let items: [String] } }
    struct SummaryResponse: Decodable { let title: String; let content: String; let tags: [String] }

    static func decodeOrganize(raw: String, action: OrganizeAction, fallbackContent: String) throws -> OrganizeResult {
        switch action {
        case .titleAndSummary:
            let parsed: TitleSummaryResponse = try decodeJSON(raw)
            return OrganizeResult(content: fallbackContent, title: parsed.title, summary: parsed.summary, tags: parsed.tags ?? [])
        case .autoTag:
            let parsed: TagsResponse = try decodeJSON(raw)
            return OrganizeResult(content: fallbackContent, title: nil, summary: nil, tags: parsed.tags)
        case .polish, .rewrite:
            return OrganizeResult(content: raw.trimmingCharacters(in: .whitespacesAndNewlines), title: nil, summary: nil, tags: [])
        }
    }

    static func decodeClusters(raw: String) throws -> [AICluster] {
        let parsed: ClusterResponse = try decodeJSON(raw)
        return parsed.clusters.map { AICluster(topic: $0.topic, description: $0.description, items: $0.items) }
    }

    static func decodeSummary(raw: String, cluster: AICluster) throws -> DocumentDraft {
        let parsed: SummaryResponse = try decodeJSON(raw)
        return DocumentDraft(title: parsed.title, content: parsed.content, tags: parsed.tags, sourceClusterTopic: cluster.topic)
    }

    static func decodeJSON<T: Decodable>(_ raw: String) throws -> T {
        let cleaned = extractJSONBlock(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw AIServiceError.invalidResponse("无法转码响应")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AIServiceError.invalidResponse("JSON 解码失败：\(error.localizedDescription)，原始：\(cleaned.prefix(200))")
        }
    }

    /// 从可能含 markdown 围栏的文本中提取首个 JSON 对象块。
    static func extractJSONBlock(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNL = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNL)...])
            }
            if s.hasSuffix("```") {
                s = String(s.dropLast(3))
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }
}
