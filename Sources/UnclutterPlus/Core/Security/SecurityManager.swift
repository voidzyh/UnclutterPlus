import Foundation

/// 安全验证结果
public struct SecurityValidation {
    public let safe: Bool
    public let reason: String

    public init(safe: Bool, reason: String) {
        self.safe = safe
        self.reason = reason
    }
}

/// 安全管理器 - 负责验证各种安全操作
@MainActor
public final class SecurityManager {
    public static let shared = SecurityManager()

    private init() {}

    public func validateOperation(_ operation: SecurityOperation) -> SecurityValidation {
        switch operation {
        case .sqlQuery(let query):
            return validateSQLQuery(query)
        case .fileAccess(let path):
            return validateFileAccess(path)
        case .networkRequest(let url):
            return validateNetworkRequest(url)
        }
    }

    private func validateSQLQuery(_ query: String) -> SecurityValidation {
        let dangerousKeywords = ["DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "TRUNCATE"]
        let upperQuery = query.uppercased()

        for keyword in dangerousKeywords {
            if upperQuery.contains(keyword) {
                return SecurityValidation(safe: false, reason: "包含危险关键字: \(keyword)")
            }
        }

        return SecurityValidation(safe: true, reason: "查询安全")
    }

    private func validateFileAccess(_ path: String) -> SecurityValidation {
        // 简单的路径验证
        if path.contains("..") || path.contains("~") {
            return SecurityValidation(safe: false, reason: "包含非法路径字符")
        }
        return SecurityValidation(safe: true, reason: "路径安全")
    }

    private func validateNetworkRequest(_ url: URL) -> SecurityValidation {
        // 检查是否是安全的协议
        let safeSchemes = ["https", "http"]
        if let scheme = url.scheme, safeSchemes.contains(scheme.lowercased()) {
            return SecurityValidation(safe: true, reason: "网络请求安全")
        }
        return SecurityValidation(safe: false, reason: "不安全的协议: \(url.scheme ?? "unknown")")
    }
}
