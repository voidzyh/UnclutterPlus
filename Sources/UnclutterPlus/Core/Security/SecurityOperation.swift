import Foundation

/// 安全操作类型
public enum SecurityOperation {
    case sqlQuery(String)
    case fileAccess(String)
    case networkRequest(URL)

    public var description: String {
        switch self {
        case .sqlQuery(let query):
            return "SQL Query: \(query)"
        case .fileAccess(let path):
            return "File Access: \(path)"
        case .networkRequest(let url):
            return "Network Request: \(url.absoluteString)"
        }
    }
}
