import Foundation

/// 简化版日志记录器 - 用于修复构建错误
struct Logger {
    static let shared = Logger()
    
    func info(_ message: String) {
        print("[INFO] \(message)")
    }
    
    func performance(_ message: String) {
        print("[PERFORMANCE] \(message)")
    }
    
    func critical(_ message: String) {
        print("[CRITICAL] \(message)")
    }
    
    func warning(_ message: String, category: String = "") {
        print("[WARNING] \(category): \(message)")
    }
    
    func debug(_ message: String, category: String = "") {
        print("[DEBUG] \(category): \(message)")
    }
}

/// 全局日志实例
let logger = Logger.shared