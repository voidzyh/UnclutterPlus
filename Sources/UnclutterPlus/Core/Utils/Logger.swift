import Foundation
import OSLog
import SwiftUI

/// 统一日志记录器 - 增强版（支持动态日志级别控制）
final class StructuredLogger: ObservableObject {
    static let shared = StructuredLogger()

    // MARK: - 日志级别

    enum LogLevel: Int, Comparable, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

        var icon: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }

        var description: String {
            switch self {
            case .debug: return "调试"
            case .info: return "信息"
            case .warning: return "警告"
            case .error: return "错误"
            case .critical: return "严重"
            }
        }
    }

    // MARK: - 日志分类

    enum Category: String, CaseIterable {
        case general = "General"
        case storage = "Storage"
        case service = "Service"
        case ui = "UI"
        case performance = "Performance"
        case security = "Security"
        case network = "Network"

        var description: String {
            switch self {
            case .general: return "通用"
            case .storage: return "存储"
            case .service: return "服务"
            case .ui: return "界面"
            case .performance: return "性能"
            case .security: return "安全"
            case .network: return "网络"
            }
        }
    }

    // MARK: - 配置

    /// 当前全局日志级别（可动态调整）
    @Published private(set) var currentLevel: LogLevel {
        didSet {
            // 保存到用户偏好
            UserDefaults.standard.set(currentLevel.rawValue, forKey: "logging.level")
        }
    }

    /// 启用的日志分类（空数组表示全部启用）
    @Published private(set) var enabledCategories: Set<String> = [] {
        didSet {
            // 保存到用户偏好
            UserDefaults.standard.set(Array(enabledCategories), forKey: "logging.categories")
        }
    }

    // MARK: - 私有属性

    private let dateFormatter: ISO8601DateFormatter

    // MARK: - 初始化

    private init() {
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        // 从用户偏好加载配置
        if let savedLevel = UserDefaults.standard.object(forKey: "logging.level") as? Int,
           let level = LogLevel(rawValue: savedLevel) {
            self.currentLevel = level
        } else {
            // 默认日志级别
            #if DEBUG
            self.currentLevel = .debug
            #else
            self.currentLevel = .info
            #endif
        }

        // 加载启用的分类
        if let savedCategories = UserDefaults.standard.array(forKey: "logging.categories") as? [String] {
            self.enabledCategories = Set(savedCategories)
        }
    }

    // MARK: - 公共配置方法

    /// 设置日志级别
    func setLogLevel(_ level: LogLevel) {
        currentLevel = level
        info("日志级别已更改为: \(level.description)", category: Category.general.rawValue)
    }

    /// 启用指定分类
    func enableCategory(_ category: String) {
        enabledCategories.insert(category)
    }

    /// 禁用指定分类
    func disableCategory(_ category: String) {
        enabledCategories.remove(category)
    }

    /// 重置为默认配置
    func resetToDefaults() {
        #if DEBUG
        currentLevel = .debug
        #else
        currentLevel = .info
        #endif
        enabledCategories.removeAll()
        info("日志配置已重置为默认值", category: Category.general.rawValue)
    }

    // MARK: - 公共日志方法

    /// Debug 级别日志 - 仅用于开发调试
    func debug(_ message: String, category: String = Category.general.rawValue, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message, file: file, function: function, line: line)
    }

    /// Info 级别日志 - 一般信息流
    func info(_ message: String, category: String = Category.general.rawValue, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message, file: file, function: function, line: line)
    }

    /// Warning 级别日志 - 警告信息
    func warning(_ message: String, category: String = Category.general.rawValue, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message, file: file, function: function, line: line)
    }

    /// Error 级别日志 - 错误信息
    func error(_ message: String, category: String = Category.general.rawValue, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message, file: file, function: function, line: line)
    }

    /// Critical 级别日志 - 严重错误
    func critical(_ message: String, category: String = Category.general.rawValue, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, category: category, message, file: file, function: function, line: line)
    }

    /// 性能日志
    func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: Category.performance.rawValue, message, file: file, function: function, line: line)
    }

    // MARK: - 私有日志方法

    private func log(_ level: LogLevel, category: String, _ message: String, file: String, function: String, line: Int) {
        // 检查日志级别
        guard level >= currentLevel else { return }

        // 检查分类过滤（如果配置了分类过滤）
        if !enabledCategories.isEmpty && !enabledCategories.contains(category) {
            return
        }

        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        _ = function.components(separatedBy: "(").first ?? function  // 保留以备将来使用

        // 格式化日志消息
        let logMessage = "[\(timestamp)] [\(level.icon)] [\(category)] [\(filename):\(line)] \(message)"

        // 输出到控制台
        print(logMessage)

        // 输出到系统日志
        let osLogType: OSLogType
        switch level {
        case .debug: osLogType = .debug
        case .info: osLogType = .info
        case .warning: osLogType = .default
        case .error: osLogType = .error
        case .critical: osLogType = .fault
        }

        let osLog = OSLog(subsystem: "com.unclutterplus", category: category)
        os_log("%{public}@", log: osLog, type: osLogType, message)
    }

    // MARK: - 统计信息

    /// 获取当前日志配置摘要
    var configurationSummary: String {
        let levelDesc = currentLevel.description
        let categoryFilter = enabledCategories.isEmpty ? "全部" : enabledCategories.joined(separator: ", ")
        return "级别: \(levelDesc) | 分类: \(categoryFilter)"
    }
}

/// 全局日志实例
let logger = StructuredLogger.shared
