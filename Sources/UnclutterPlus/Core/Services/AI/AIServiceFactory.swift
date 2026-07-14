import Foundation

/// AI 服务工厂 —— 按 ConfigurationManager 配置返回对应实现。
///
/// - "http" → HTTPAPIEngine（OpenAI 兼容 API）
/// - "cli"  → LocalCLIEngine（ollama 等本地工具）
enum AIServiceFactory {

    /// 当前是否已完成必要配置（用于 UI 决定是否启用 AI 功能）。
    static var isConfigured: Bool {
        let config = ConfigurationManager.shared
        switch config.aiServiceType {
        case "cli":
            return !config.aiCliPath.isEmpty && !config.aiCliModel.isEmpty
        default: // "http"
            return !config.aiEndpoint.isEmpty && !config.aiAPIKey.isEmpty
        }
    }

    /// 创建当前配置对应的 AI 服务实例。未配置时返回 nil。
    static func makeService() -> AIService? {
        let config = ConfigurationManager.shared
        switch config.aiServiceType {
        case "cli":
            guard !config.aiCliPath.isEmpty, !config.aiCliModel.isEmpty else { return nil }
            return LocalCLIEngine(cliPath: config.aiCliPath, cliModel: config.aiCliModel, timeout: config.aiTimeout)
        default: // "http"
            guard !config.aiEndpoint.isEmpty, !config.aiAPIKey.isEmpty else { return nil }
            return HTTPAPIEngine(endpoint: config.aiEndpoint, apiKey: config.aiAPIKey, model: config.aiModel, timeout: config.aiTimeout)
        }
    }
}
