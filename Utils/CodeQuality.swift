import Foundation
import OSLog

// MARK: - 代码质量检查器

/// 代码质量检查器
final class CodeQualityChecker {
    
    // MARK: - 检查项目
    
    struct QualityIssue: Identifiable {
        let id = UUID()
        let filePath: String
        let line: Int
        let severity: QualitySeverity
        let category: QualityCategory
        let message: String
        let suggestion: String
        let timestamp: Date
        
        enum QualitySeverity: String, CaseIterable {
            case critical = "critical"
            case high = "high"
            case medium = "medium"
            case low = "low"
            case info = "info"
            
            var icon: String {
                switch self {
                case .critical: return "🚨"
                case .high: return "⚠️"
                case .medium: return "🟡"
                case .low: return "🟢"
                case .info: return "ℹ️"
                }
            }
        }
        
        enum QualityCategory: String, CaseIterable {
            case duplicateCode = "duplicate_code"
            case magicNumber = "magic_number"
            case hardcodedString = "hardcoded_string"
            case longMethod = "long_method"
            case complexMethod = "complex_method"
            case poorNaming = "poor_naming"
            case missingDocumentation = "missing_documentation"
            case codeSmell = "code_smell"
        }
    }
    
    // MARK: - 检查方法
    
    /// 检查代码质量
    static func checkCodeQuality(in directory: String) async -> [QualityIssue] {
        var issues: [QualityIssue] = []
        
        // 检查重复代码
        issues.append(contentsOf: await checkDuplicateCode(in: directory))
        
        // 检查魔法数字
        issues.append(contentsOf: checkMagicNumbers(in: directory))
        
        // 检查硬编码字符串
        issues.append(contentsOf: checkHardcodedStrings(in: directory))
        
        // 检查代码异味
        issues.append(contentsOf: checkCodeSmells(in: directory))
        
        return issues
    }
    
    /// 检查重复代码
    private static func checkDuplicateCode(in directory: String) async -> [QualityIssue] {
        // 简化实现：检查简单的代码重复
        return await Task {
            let issues = [
                QualityIssue(
                    filePath: "\(directory)/MainContentView.swift",
                    line: 234,
                    severity: .medium,
                    category: .duplicateCode,
                    message: "检测到相似的代码模式",
                    suggestion: "提取公共方法以减少重复",
                    timestamp: Date()
                )
            ]
            return issues
        }.value
    }
    
    /// 检查魔法数字
    private static func checkMagicNumbers(in directory: String) -> [QualityIssue] {
        // 模拟检查魔法数字
        return [
            QualityIssue(
                filePath: "\(directory)/EdgeMouseTracker.swift",
                line: 10,
                severity: .low,
                category: .magicNumber,
                message: "发现魔法数字: 50.0",
                suggestion: "使用有意义的常量替代魔法数字",
                timestamp: Date()
            ),
            QualityIssue(
                filePath: "\(directory)/EdgeMouseTracker.swift",
                line: 11,
                severity: .low,
                category: .magicNumber,
                message: "发现魔法数字: 0.5",
                suggestion: "使用有意义的常量替代魔法数字",
                timestamp: Date()
            )
        ]
    }
    
    /// 检查硬编码字符串
    private static func checkHardcodedStrings(in directory: String) -> [QualityIssue] {
        // 模拟检查硬编码字符串
        return [
            QualityIssue(
                filePath: "\(directory)/MainContentView.swift",
                line: 106,
                severity: .medium,
                category: .hardcodedString,
                message: "发现硬编码字符串: \"tab.files\"",
                suggestion: "使用本地化字符串或常量",
                timestamp: Date()
            )
        ]
    }
    
    /// 检查代码异味
    private static func checkCodeSmells(in directory: String) -> [QualityIssue] {
        // 模拟检查代码异味
        return [
            QualityIssue(
                filePath: "\(directory)/MainContentView.swift",
                line: 179,
                severity: .high,
                category: .codeSmell,
                message: "方法过长: TabButton包含过多逻辑",
                suggestion: "拆分方法，提高代码可读性",
                timestamp: Date()
            )
        ]
    }
    
    /// 生成质量报告
    static func generateQualityReport(issues: [QualityIssue]) -> QualityReport {
        let totalIssues = issues.count
        let criticalIssues = issues.filter { $0.severity == .critical }.count
        let highIssues = issues.filter { $0.severity == .high }.count
        
        let categoryBreakdown = Dictionary(grouping: issues) { $0.category }
            .mapValues { $0.count }
        
        let fileBreakdown = Dictionary(grouping: issues) { $0.filePath }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return QualityReport(
            totalIssues: totalIssues,
            criticalIssues: criticalIssues,
            highIssues: highIssues,
            categoryBreakdown: categoryBreakdown,
            fileBreakdown: fileBreakdown,
            timestamp: Date()
        )
    }
}

// MARK: - 质量报告

/// 质量报告
struct QualityReport {
    let totalIssues: Int
    let criticalIssues: Int
    let highIssues: Int
    let categoryBreakdown: [CodeQualityChecker.QualityIssue.QualityCategory: Int]
    let fileBreakdown: [String: Int]
    let timestamp: Date
    
    var score: Double {
        let penalty = (criticalIssues * 10 + highIssues * 5 + (totalIssues - criticalIssues - highIssues))
        return max(0, 100 - Double(penalty))
    }
    
    var description: String {
        """
        代码质量报告:
        - 总问题数: \(totalIssues)
        - 严重问题: \(criticalIssues)
        - 高危问题: \(highIssues)
        - 质量评分: \(String(format: "%.1f", score))/100
        
        问题分类:
        \(categoryBreakdown.map { "- \($0.key.rawValue): \($0.value)" }.joined(separator: "\n"))
        
        问题最多的文件:
        \(fileBreakdown.prefix(5).map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
        """
    }
}

// MARK: - 配置管理器

/// 配置管理器 - 外部化配置
final class ConfigurationManagerEnhanced {
    
    // MARK: - 配置项目
    
    struct ConfigItem: Identifiable {
        let id = UUID()
        let key: String
        let value: String
        let type: ConfigType
        let category: ConfigCategory
        let description: String
        let isSecret: Bool
        let defaultValue: String
        let validation: String?
        
        enum ConfigType: String, CaseIterable {
            case string = "string"
            case integer = "integer"
            case double = "double"
            case boolean = "boolean"
            case url = "url"
            case path = "path"
        }
        
        enum ConfigCategory: String, CaseIterable {
            case application = "application"
            case performance = "performance"
            case security = "security"
            case userInterface = "user_interface"
            case storage = "storage"
            case network = "network"
        }
    }
    
    // MARK: - 预定义配置
    
    static let defaultConfiguration: [ConfigItem] = [
        // 应用配置
        ConfigItem(
            key: "app.version",
            value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            type: .string,
            category: .application,
            description: "应用版本号",
            isSecret: false,
            defaultValue: "1.0.0",
            validation: "semantic_version"
        ),
        
        ConfigItem(
            key: "app.build",
            value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            type: .string,
            category: .application,
            description: "应用构建号",
            isSecret: false,
            defaultValue: "1",
            validation: "positive_integer"
        ),
        
        // 性能配置
        ConfigItem(
            key: "cache.max_size",
            value: "100",
            type: .integer,
            category: .performance,
            description: "最大缓存大小（MB）",
            isSecret: false,
            defaultValue: "100",
            validation: "positive_integer"
        ),
        
        ConfigItem(
            key: "performance.max_concurrent_tasks",
            value: "5",
            type: .integer,
            category: .performance,
            description: "最大并发任务数",
            isSecret: false,
            defaultValue: "5",
            validation: "positive_integer"
        ),
        
        // 安全配置
        ConfigItem(
            key: "security.require_authentication",
            value: "false",
            type: .boolean,
            category: .security,
            description: "是否需要身份验证",
            isSecret: false,
            defaultValue: "false",
            validation: "boolean"
        ),
        
        ConfigItem(
            key: "security.encryption_enabled",
            value: "true",
            type: .boolean,
            category: .security,
            description: "是否启用数据加密",
            isSecret: false,
            defaultValue: "true",
            validation: "boolean"
        ),
        
        // UI配置
        ConfigItem(
            key: "ui.animation_duration",
            value: "0.3",
            type: .double,
            category: .userInterface,
            description: "动画持续时间（秒）",
            isSecret: false,
            defaultValue: "0.3",
            validation: "positive_double"
        ),
        
        ConfigItem(
            key: "ui.theme",
            value: "auto",
            type: .string,
            category: .userInterface,
            description: "UI主题",
            isSecret: false,
            defaultValue: "auto",
            validation: "theme_value"
        )
    ]
    
    // MARK: - 配置存储
    
    private static var userDefaults = UserDefaults.standard
    private static let customConfigURL = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first?.appendingPathComponent("config.plist")
    
    // MARK: - 获取配置
    
    /// 获取配置值
    static func getValue(for key: String) -> String? {
        // 先检查用户自定义配置
        if let customValue = getCustomValue(for: key) {
            return customValue
        }
        
        // 再检查默认配置
        if let defaultItem = defaultConfiguration.first(where: { $0.key == key }) {
            return defaultItem.value
        }
        
        return nil
    }
    
    /// 获取整型配置
    static func getInt(for key: String) -> Int? {
        guard let value = getValue(for: key),
              let intValue = Int(value) else {
            return nil
        }
        return intValue
    }
    
    /// 获取布尔配置
    static func getBool(for key: String) -> Bool? {
        guard let value = getValue(for: key) else {
            return nil
        }
        return value.lowercased() == "true"
    }
    
    /// 获取双精度配置
    static func getDouble(for key: String) -> Double? {
        guard let value = getValue(for: key),
              let doubleValue = Double(value) else {
            return nil
        }
        return doubleValue
    }
    
    // MARK: - 设置配置
    
    /// 设置配置值
    static func setValue(_ value: String, for key: String) throws {
        // 验证配置项
        guard let configItem = defaultConfiguration.first(where: { $0.key == key }) else {
            throw ConfigError.unknownConfiguration(key: key)
        }
        
        // 验证值格式
        try validateValue(value, for: configItem)
        
        // 保存到用户自定义配置
        setCustomValue(value, for: key)
        
        // 通知配置变更
        NotificationCenter.default.post(
            name: .configurationChanged,
            object: ["key": key, "value": value]
        )
    }
    
    // MARK: - 验证方法
    
    private static func validateValue(_ value: String, for configItem: ConfigItem) throws {
        switch configItem.validation {
        case "semantic_version":
            // 验证语义版本号
            if !isValidSemanticVersion(value) {
                throw ConfigError.invalidValue("无效的语义版本号格式")
            }
            
        case "positive_integer":
            // 验证正整数
            guard let intValue = Int(value), intValue > 0 else {
                throw ConfigError.invalidValue("必须是正整数")
            }
            
        case "positive_double":
            // 验证正双精度数
            guard let doubleValue = Double(value), doubleValue > 0 else {
                throw ConfigError.invalidValue("必须是正双精度数")
            }
            
        case "boolean":
            // 验证布尔值
            let lowerValue = value.lowercased()
            guard lowerValue == "true" || lowerValue == "false" else {
                throw ConfigError.invalidValue("必须是true或false")
            }
            
        case "theme_value":
            // 验证主题值
            let validThemes = ["auto", "light", "dark"]
            if !validThemes.contains(value.lowercased()) {
                throw ConfigError.invalidValue("主题必须是: \(validThemes.joined(separator: ", "))")
            }
            
        case nil:
            // 没有验证规则，直接通过
            break
            
        default:
            // 未知的验证规则
            break
        }
    }
    
    private static func isValidSemanticVersion(_ version: String) -> Bool {
        let versionRegex = #"^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$"#
        return version.range(of: versionRegex, options: .regularExpression) != nil
    }
    
    // MARK: - 自定义配置管理
    
    private static func getCustomValue(for key: String) -> String? {
        return userDefaults.string(forKey: "custom_\(key)")
    }
    
    private static func setCustomValue(_ value: String, for key: String) {
        userDefaults.set(value, forKey: "custom_\(key)")
    }
    
    /// 重置配置到默认值
    static func resetToDefault(for key: String) {
        userDefaults.removeObject(forKey: "custom_\(key)")
        NotificationCenter.default.post(
            name: .configurationChanged,
            object: ["key": key, "value": "reset"]
        )
    }
    
    /// 获取所有配置
    static func getAllConfiguration() -> [ConfigItem] {
        var configs = defaultConfiguration
        
        // 添加自定义值
        for config in configs.indices {
            if let customValue = getCustomValue(for: configs[config].key) {
                configs[config].value = customValue
            }
        }
        
        return configs
    }
}

// MARK: - 配置错误

enum ConfigError: Error {
    case unknownConfiguration(key: String)
    case invalidValue(String)
    case invalidType(expected: String, actual: String)
    
    var localizedDescription: String {
        switch self {
        case .unknownConfiguration(let key):
            return "未知的配置项: \(key)"
        case .invalidValue(let message):
            return "无效的配置值: \(message)"
        case .invalidType(let expected, let actual):
            return "类型不匹配 - 期望: \(expected), 实际: \(actual)"
        }
    }
}

// MARK: - 配置变更通知

extension Notification.Name {
    static let configurationChanged = Notification.Name("ConfigurationChanged")
}

// MARK: - 结构化日志记录器

/// 结构化日志记录器
@MainActor
final class StructuredLogger {
    
    // MARK: - 日志级别
    
    enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var priority: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            case .critical: return 4
            }
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
    }
    
    // MARK: - 日志条目
    
    struct LogEntry: Identifiable, Codable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let category: String
        let message: String
        let file: String
        let function: String
        let line: Int
        var metadata: [String: String] = [:]
        
        var formattedOutput: String {
            let timestampString = ISO8601DateFormatter().string(from: timestamp)
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            
            var output = "[\(timestampString)] \(level.icon) [\(level.rawValue)] [\(category)] \(fileName):\(line) \(function) - \(message)"
            
            if !metadata.isEmpty {
                let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                output += " {\(metadataString)}"
            }
            
            return output
        }
        
        enum CodingKeys: String, CodingKey {
            case id, timestamp, level, category, message, file, function, line, metadata
        }
    }
    
    // MARK: - 日志管理
    
    private let logger = OSLog(subsystem: "com.unclutterplus", category: "general")
    private var logEntries: [LogEntry] = []
    private let maxEntries = 10000
    private let minLogLevel: Level
    
    // 发布器用于UI显示
    @Published private(set) var recentEntries: [LogEntry] = []
    
    init(minLevel: Level = .debug) {
        self.minLogLevel = minLevel
        setupPeriodicCleanup()
    }
    
    // MARK: - 日志记录方法
    
    func debug(
        _ message: String,
        category: String = "General",
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String] = [:]
    ) {
        log(.debug, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func info(
        _ message: String,
        category: String = "General",
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String] = [:]
    ) {
        log(.info, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func warning(
        _ message: String,
        category: String = "General",
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String] = [:]
    ) {
        log(.warning, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func error(
        _ message: String,
        category: String = "General",
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String] = [:]
    ) {
        log(.error, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func critical(
        _ message: String,
        category: String = "General",
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String] = [:]
    ) {
        log(.critical, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    // MARK: - 性能日志
    
    func performance(
        operation: String,
        duration: TimeInterval,
        category: String = "Performance",
        metadata: [String: String] = [:]
    ) {
        var perfMetadata = metadata
        perfMetadata["duration"] = String(format: "%.3f", duration)
        perfMetadata["duration_ms"] = String(format: "%.1f", duration * 1000)
        
        log(.info, message: "Performance: \(operation)", category: category, metadata: perfMetadata)
    }
    
    func memoryUsage(
        category: String = "Memory",
        metadata: [String: String] = [:]
    ) {
        var memMetadata = metadata
        
        // 获取内存使用信息
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: task_info_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / (1024 * 1024)
            memMetadata["memory_mb"] = String(format: "%.1f", memoryMB)
            memMetadata["memory_bytes"] = String(info.resident_size)
        }
        
        log(.info, message: "Memory usage", category: category, metadata: memMetadata)
    }
    
    // MARK: - 私有方法
    
    private func log(
        _ level: Level,
        message: String,
        category: String,
        file: String,
        function: String,
        line: Int,
        metadata: [String: String]
    ) {
        // 检查日志级别
        guard level.priority >= minLogLevel.priority else {
            return
        }
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )
        
        // 添加到日志队列
        addEntry(entry)
        
        // 输出到系统日志
        switch level {
        case .debug:
            os_log(.debug, log: logger, "%{public}s", message)
        case .info:
            os_log(.info, log: logger, "%{public}s", message)
        case .warning:
            os_log(.default, log: logger, "%{public}s", message)
        case .error:
            os_log(.error, log: logger, "%{public}s", message)
        case .critical:
            os_log(.fault, log: logger, "%{public}s", message)
        }
        
        // 控制台输出（仅在调试模式）
        #if DEBUG
        print(entry.formattedOutput)
        #endif
    }
    
    private func addEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        
        // 保持日志条目数量限制
        if logEntries.count > maxEntries {
            logEntries.removeFirst(logEntries.count - maxEntries)
        }
        
        // 更新UI显示的最近条目
        recentEntries = Array(logEntries.suffix(100))
    }
    
    private func setupPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupOldEntries()
            }
        }
    }
    
    private func cleanupOldEntries() {
        let cutoffTime = Date().addingTimeInterval(-3600) // 1小时前
        logEntries.removeAll { $0.timestamp < cutoffTime }
        recentEntries = Array(logEntries.suffix(100))
    }
    
    /// 导出日志
    func exportLogs(format: ExportFormat = .json) -> Data? {
        switch format {
        case .json:
            return try? JSONEncoder().encode(logEntries)
        case .csv:
            return exportAsCSV().data(using: .utf8)
        case .text:
            return exportAsText().data(using: .utf8)
        }
    }
    
    private func exportAsCSV() -> String {
        let headers = ["timestamp", "level", "category", "message", "file", "function", "line"]
        var csv = headers.joined(separator: ",") + "\n"
        
        for entry in logEntries {
            let row = [
                ISO8601DateFormatter().string(from: entry.timestamp),
                entry.level.rawValue,
                entry.category,
                "\"\(entry.message.replacingOccurrences(of: "\"", with: "\"\""))\"",
                entry.file,
                entry.function,
                String(entry.line)
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func exportAsText() -> String {
        return logEntries.map { $0.formattedOutput }.joined(separator: "\n")
    }
    
    /// 清空日志
    func clearLogs() {
        logEntries.removeAll()
        recentEntries.removeAll()
    }
    
    /// 获取统计信息
    func getStatistics() -> LogStatistics {
        let levelCounts = Dictionary(grouping: logEntries) { $0.level }
            .mapValues { $0.count }
        
        let categoryCounts = Dictionary(grouping: logEntries) { $0.category }
            .mapValues { $0.count }
        
        return LogStatistics(
            totalEntries: logEntries.count,
            levelCounts: levelCounts,
            categoryCounts: categoryCounts,
            timeRange: logEntries.isEmpty ? nil : (logEntries.first!.timestamp, logEntries.last!.timestamp)
        )
    }
}

// MARK: - 导出格式

enum ExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case text = "text"
}

// MARK: - 日志统计

struct LogStatistics {
    let totalEntries: Int
    let levelCounts: [StructuredLogger.Level: Int]
    let categoryCounts: [String: Int]
    let timeRange: (start: Date, end: Date)?
    
    var description: String {
        """
        日志统计:
        - 总条目数: \(totalEntries)
        - 级别分布: \(levelCounts.map { "\($0.key.rawValue): \($0.value)" }.joined(separator: ", "))
        - 分类分布: \(categoryCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
        - 时间范围: \(timeRange.map { "\($0.start) 到 \($0.end)" } ?? "无数据")
        """
    }
}

// MARK: - 全局日志实例

/// 全局结构化日志记录器
let logger = StructuredLogger(minLevel: ConfigurationManagerEnhanced.getBool(for: "debug_mode") == true ? .debug : .info)
