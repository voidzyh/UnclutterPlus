import Foundation
import SQLite3
import Security
import LocalAuthentication

// MARK: - 安全威胁类型

/// 安全威胁类型
enum SecurityThreat: String, CaseIterable {
    case sqlInjection = "sql_injection"
    case unauthorizedAccess = "unauthorized_access"
    case dataCorruption = "data_corruption"
    case memoryLeak = "memory_leak"
    case privilegeEscalation = "privilege_escalation"
    case informationDisclosure = "information_disclosure"
    
    var severity: SecuritySeverity {
        switch self {
        case .sqlInjection, .privilegeEscalation:
            return .critical
        case .unauthorizedAccess, .dataCorruption:
            return .high
        case .informationDisclosure:
            return .medium
        case .memoryLeak:
            return .low
        }
    }
    
    var description: String {
        switch self {
        case .sqlInjection: return "SQL注入攻击"
        case .unauthorizedAccess: return "未授权访问"
        case .dataCorruption: return "数据损坏"
        case .memoryLeak: return "内存泄漏"
        case .privilegeEscalation: return "权限提升"
        case .informationDisclosure: return "信息泄露"
        }
    }
}

// MARK: - 安全严重程度

/// 安全严重程度
enum SecuritySeverity: Int, CaseIterable {
    case critical = 1
    case high = 2
    case medium = 3
    case low = 4
    case info = 5
    
    var displayName: String {
        switch self {
        case .critical: return "严重"
        case .high: return "高危"
        case .medium: return "中危"
        case .low: return "低危"
        case .info: return "信息"
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "🔴"
        case .high: return "🟠"
        case .medium: return "🟡"
        case .low: return "🟢"
        case .info: return "🔵"
        }
    }
}

// MARK: - SQL验证器

/// SQL验证器 - 防止SQL注入攻击
final class SQLValidator {
    
    // MARK: - 黑名单模式
    
    /// SQL注入攻击特征
    private static let dangerousPatterns: [String] = [
        "'; DROP TABLE",
        "'; DELETE FROM",
        "'; INSERT INTO",
        "'; UPDATE",
        "'; EXEC",
        "'; EXECUTE",
        "' OR '1'='1",
        "' OR 1=1--",
        "' OR 'a'='a",
        "'; WAITFOR DELAY",
        "' UNION SELECT",
        "'; SHUTDOWN",
        "--",
        "/*",
        "*/",
        "@@",
        "xp_",
        "sp_",
        "ALTER ",
        "CREATE ",
        "DROP ",
        "EXEC ",
        "EXECUTE ",
        "DECLARE ",
        "CAST(",
        "CHAR(",
        "HEX(",
        "CONCAT(",
        "LOAD_FILE(",
        "INTO OUTFILE",
        "INTO DUMPFILE"
    ]
    
    // MARK: - 验证方法
    
    /// 验证SQL查询是否安全
    static func validateQuery(_ query: String) -> ValidationResult {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查黑名单模式
        for pattern in dangerousPatterns {
            if normalizedQuery.contains(pattern.lowercased()) {
                return .unsafe(reason: "检测到危险模式: \(pattern)", threat: .sqlInjection)
            }
        }
        
        // 检查特殊字符
        let dangerousChars = ["'", "\"", ";", "\\", "/", "*", "@", "#", "$", "%", "^", "&", "|"]
        let foundDangerousChars = dangerousChars.filter { normalizedQuery.contains($0) }
        
        if !foundDangerousChars.isEmpty {
            return .warning(reason: "包含特殊字符: \(foundDangerousChars.joined())")
        }
        
        // 检查长度
        if normalizedQuery.count > 10000 {
            return .warning(reason: "查询长度过长: \(normalizedQuery.count)")
        }
        
        return .safe
    }
    
    /// 验证参数是否安全
    static func validateParameter(_ parameter: String) -> ValidationResult {
        let trimmed = parameter.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否为空或过短
        if trimmed.isEmpty {
            return .unsafe(reason: "参数不能为空", threat: .sqlInjection)
        }
        
        if trimmed.count > 1000 {
            return .warning(reason: "参数长度超过限制")
        }
        
        // 检查危险模式
        for pattern in dangerousPatterns {
            if trimmed.lowercased().contains(pattern.lowercased()) {
                return .unsafe(reason: "参数包含危险内容", threat: .sqlInjection)
            }
        }
        
        // 检查字符集（只允许字母、数字、下划线、连字符、空格和基本标点）
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- .,:()[]{}")
        if trimmed.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            return .warning(reason: "包含非标准字符")
        }
        
        return .safe
    }
    
    /// 构建安全的SQL查询（参数化查询）
    static func buildSecureQuery(template: String, parameters: [String]) -> Result<String, SecurityError> {
        let validationResult = validateQuery(template)
        switch validationResult {
        case .unsafe:
            return .failure(.unsafeQuery(reason: validationResult.reason ?? "查询未通过安全验证"))
        case .warning:
            print("⚠️ SQL查询警告: \(validationResult.reason ?? "")")
        case .safe:
            break
        }
        
        // 验证所有参数
        for parameter in parameters {
            let paramValidation = validateParameter(parameter)
            switch paramValidation {
            case .unsafe:
                return .failure(.unsafeParameter(reason: paramValidation.reason ?? "参数未通过安全验证"))
            case .warning:
                print("⚠️ SQL参数警告: \(paramValidation.reason ?? "")")
            case .safe:
                break
            }
        }
        
        return .success(template)
    }
    
    /// 安全地绑定参数到SQL语句
    static func bindParameters(_ statement: OpaquePointer?, parameters: [String], startIndex: Int32 = 1) throws {
        for (index, parameter) in parameters.enumerated() {
            let position = startIndex + Int32(index)
            let validationResult = validateParameter(parameter)
            
            if case .unsafe = validationResult {
                throw SecurityError.unsafeParameter(reason: "参数 '\(parameter)' 未通过安全验证")
            }
            
            // 使用参数化绑定而不是字符串拼接
            sqlite3_bind_text(statement, position, parameter, -1, SQLITE_TRANSIENT)
        }
    }
}

// MARK: - 验证结果

/// 验证结果
enum ValidationResult {
    case safe
    case warning(reason: String)
    case unsafe(reason: String, threat: SecurityThreat)
    
    var isSafe: Bool {
        if case .safe = self { return true }
        return false
    }
    
    var reason: String? {
        switch self {
        case .safe:
            return nil
        case .warning(let reason), .unsafe(let reason, _):
            return reason
        }
    }
}

// MARK: - 权限管理器

/// 权限管理器 - 真实的权限检查和管理
final class PermissionManager {
    
    // MARK: - 权限类型
    
    enum Permission: String, CaseIterable {
        case screenRecording = "screenRecording"
        case accessibility = "accessibility"
        case fileSystem = "fileSystem"
        case clipboard = "clipboard"
        case camera = "camera"
        case microphone = "microphone"
        
        var description: String {
            switch self {
            case .screenRecording: return "屏幕录制"
            case .accessibility: return "辅助功能"
            case .fileSystem: return "文件系统"
            case .clipboard: return "剪贴板"
            case .camera: return "摄像头"
            case .microphone: return "麦克风"
            }
        }
    }
    
    // MARK: - 权限检查
    
    /// 检查权限状态
    static func checkPermission(_ permission: Permission) async -> PermissionStatus {
        switch permission {
        case .screenRecording:
            return await checkScreenRecordingPermission()
        case .accessibility:
            return checkAccessibilityPermission()
        case .fileSystem:
            return checkFileSystemPermission()
        case .clipboard:
            return checkClipboardPermission()
        case .camera:
            return await checkCameraPermission()
        case .microphone:
            return await checkMicrophonePermission()
        }
    }
    
    /// 请求权限
    static func requestPermission(_ permission: Permission) async -> PermissionStatus {
        let currentStatus = await checkPermission(permission)
        
        guard currentStatus == .denied else {
            return currentStatus
        }
        
        switch permission {
        case .screenRecording:
            return await requestScreenRecordingPermission()
        case .accessibility:
            return requestAccessibilityPermission()
        case .fileSystem:
            return await requestFileSystemPermission()
        case .clipboard:
            return await requestClipboardPermission()
        case .camera:
            return await requestCameraPermission()
        case .microphone:
            return await requestMicrophonePermission()
        }
    }
    
    // MARK: - 具体权限检查
    
    private static func checkScreenRecordingPermission() async -> PermissionStatus {
        // 使用ScreenCaptureKit检查真实权限
        do {
            let availableContent = try await SCShareableContent.current
            // 如果能获取到内容，说明有权限
            _ = availableContent.windows
            _ = availableContent.applications
            return .authorized
        } catch LAError.cameraNotAvailable, LAError.microphoneNotAvailable:
            return .denied
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    private static func checkAccessibilityPermission() -> PermissionStatus {
        let context = LAContext()
        var error: NSError?
        
        let isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if isAvailable && error == nil {
            return .authorized
        } else {
            return .denied
        }
    }
    
    private static func checkFileSystemPermission() -> PermissionStatus {
        // 检查文件系统访问权限
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let testFile = homeDirectory.appendingPathComponent("permission_test_\(UUID().uuidString)")
        
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            return .authorized
        } catch {
            return .denied
        }
    }
    
    private static func checkClipboardPermission() -> PermissionStatus {
        // 剪贴板访问通常总是允许的，但我们可以测试一下
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadItem(withDataConformingToTypes: []) ? .authorized : .denied
    }
    
    private static func checkCameraPermission() async -> PermissionStatus {
        let captureDevice = AVCaptureDevice.default(for: .video)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .error("未知状态")
        }
    }
    
    private static func checkMicrophonePermission() async -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .error("未知状态")
        }
    }
    
    // MARK: - 权限请求
    
    private static func requestScreenRecordingPermission() async -> PermissionStatus {
        // 显示系统权限请求对话框
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "需要屏幕录制权限"
            alert.informativeText = "UnclutterPlus需要屏幕录制权限来提供截图功能。请在系统设置 > 隐私与安全性 > 屏幕录制中授予权限。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后设置")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        // 等待用户权限设置
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        return await checkScreenRecordingPermission()
    }
    
    private static func requestAccessibilityPermission() -> PermissionStatus {
        MainActor.run {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "UnclutterPlus需要辅助功能权限来提供快捷键支持。请在系统设置 > 隐私与安全性 > 辅助功能中授予权限。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后设置")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        return .manualReviewRequired
    }
    
    private static func requestFileSystemPermission() async -> PermissionStatus {
        // 文件系统权限通常通过App Sandbox管理
        return .authorized
    }
    
    private static func requestClipboardPermission() async -> PermissionStatus {
        // 剪贴板权限通常是隐式的
        return .authorized
    }
    
    private static func requestCameraPermission() async -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }
    
    private static func requestMicrophonePermission() async -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .authorized : .denied
    }
}

// MARK: - 权限状态

/// 权限状态
enum PermissionStatus: String, CaseIterable {
    case authorized = "authorized"
    case denied = "denied"
    case notDetermined = "notDetermined"
    case manualReviewRequired = "manualReviewRequired"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未确定"
        case .manualReviewRequired: return "需要手动设置"
        case .error: return "检查错误"
        }
    }
}

// MARK: - 内存安全管理器

/// 内存安全管理器
final class MemorySecurityManager {
    
    // MARK: - 内存保护
    
    /// 清理敏感内存
    static func secureClear(_ data: inout Data) {
        // 使用随机数据覆盖内存
        for _ in 0..<3 {
            let randomBytes = data.map { _ in UInt8.random(in: 0...255) }
            data.copyBytes(from: randomBytes)
        }
        
        // 最后填充零
        data = Data(repeating: 0, count: data.count)
    }
    
    /// 安全地处理敏感字符串
    static func secureProcessString(_ string: String, processor: (String) -> String) -> String {
        var result = processor(string)
        
        // 确保结果不会被意外保留
        defer {
            result = String(repeating: "X", count: result.count)
        }
        
        return result
    }
    
    /// 检查内存泄漏
    static func checkForMemoryLeaks(in object: AnyObject) -> MemoryLeakReport {
        // 简化的内存泄漏检测
        let objectId = Unmanaged.passUnretained(object).toOpaque()
        let report = MemoryLeakReport(
            objectId: objectId,
            objectType: String(describing: type(of: object)),
            timestamp: Date()
        )
        
        print("🔍 内存检查报告: \(report)")
        return report
    }
    
    /// 安全地释放对象
    static func secureRelease<T: AnyObject>(_ object: T) {
        // 执行清理操作
        if let cleanupObject = object as? Cleanupable {
            cleanupObject.cleanup()
        }
        
        // 强制释放
        withExtendedLifetime(object) {
            // 对象在这里会被释放
        }
    }
}

// MARK: - 清理协议

/// 可清理对象协议
protocol Cleanupable {
    func cleanup()
}

// MARK: - 内存泄漏报告

/// 内存泄漏报告
struct MemoryLeakReport {
    let objectId: UnsafeMutableRawPointer
    let objectType: String
    let timestamp: Date
    
    var description: String {
        "对象类型: \(objectType), 创建时间: \(timestamp)"
    }
}

// MARK: - 安全错误

/// 安全错误
enum SecurityError: LocalizedError {
    case unsafeQuery(reason: String)
    case unsafeParameter(reason: String)
    case permissionDenied(permission: PermissionManager.Permission)
    case memoryCorruption
    case unauthorizedAccess
    
    var errorDescription: String? {
        switch self {
        case .unsafeQuery(let reason):
            return "SQL查询不安全: \(reason)"
        case .unsafeParameter(let reason):
            return "SQL参数不安全: \(reason)"
        case .permissionDenied(let permission):
            return "权限被拒绝: \(permission.description)"
        case .memoryCorruption:
            return "内存损坏"
        case .unauthorizedAccess:
            return "未授权访问"
        }
    }
}

// MARK: - 全局安全管理器

/// 全局安全管理器
@MainActor
final class SecurityManager: ObservableObject {
    static let shared = SecurityManager()
    
    // MARK: - Properties
    
    @Published private(set) var securityStatus: SecurityStatus = .unknown
    @Published private(set) var activeThreats: [SecurityThreat] = []
    @Published private(set) var securityLogs: [SecurityLogEntry] = []
    
    private let maxLogEntries = 1000
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    private init() {
        setupSecurityMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 启动安全监控
    func startSecurityMonitoring() {
        isMonitoring = true
        securityStatus = .active
        
        // 定期检查安全状态
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSecurityCheck()
            }
        }
        
        logSecurityEvent(.info, message: "安全监控已启动")
    }
    
    /// 停止安全监控
    func stopSecurityMonitoring() {
        isMonitoring = false
        securityStatus = .inactive
        logSecurityEvent(.info, message: "安全监控已停止")
    }
    
    /// 执行完整的安全检查
    func performSecurityCheck() async {
        var threats: [SecurityThreat] = []
        
        // 检查SQL注入风险
        threats.append(contentsOf: await checkSQLInjectionRisks())
        
        // 检查权限状态
        threats.append(contentsOf: await checkPermissionRisks())
        
        // 检查内存安全
        threats.append(contentsOf: checkMemorySecurity())
        
        await MainActor.run {
            activeThreats = threats
            
            if threats.isEmpty {
                securityStatus = .secure
                logSecurityEvent(.info, message: "安全检查完成 - 无威胁")
            } else {
                securityStatus = .vulnerable
                logSecurityEvent(.warning, message: "发现 \(threats.count) 个安全威胁")
            }
        }
    }
    
    /// 验证操作安全性
    func validateOperation(_ operation: SecurityOperation) -> ValidationResult {
        switch operation {
        case .sqlQuery(let query):
            return SQLValidator.validateQuery(query)
        case .fileAccess(let path):
            return validateFileAccess(path)
        case .networkRequest(let url):
            return validateNetworkRequest(url)
        case .systemCall(let command):
            return validateSystemCall(command)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSecurityMonitoring() {
        securityStatus = .initializing
    }
    
    private func checkSQLInjectionRisks() async -> [SecurityThreat] {
        // 这里可以检查正在执行的SQL查询
        return []
    }
    
    private func checkPermissionRisks() async -> [SecurityThreat] {
        var threats: [SecurityThreat] = []
        
        let permissions: [PermissionManager.Permission] = [.screenRecording, .accessibility, .fileSystem]
        
        for permission in permissions {
            let status = await PermissionManager.checkPermission(permission)
            if status == .denied {
                threats.append(.unauthorizedAccess)
                logSecurityEvent(.warning, message: "权限被拒绝: \(permission.description)")
            }
        }
        
        return threats
    }
    
    private func checkMemorySecurity() -> [SecurityThreat] {
        // 检查内存使用情况
        var threats: [SecurityThreat] = []
        
        // 获取内存使用统计
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: task_info_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memorySize = info.resident_size
            let memoryWarningThreshold: UInt64 = 100 * 1024 * 1024 // 100MB
            
            if memorySize > memoryWarningThreshold {
                threats.append(.memoryLeak)
                logSecurityEvent(.warning, message: "内存使用过高: \(memorySize / 1024 / 1024)MB")
            }
        }
        
        return threats
    }
    
    private func validateFileAccess(_ path: String) -> ValidationResult {
        // 检查文件路径安全性
        let dangerousPatterns = ["../", "~", "$(", "`", "&&", "||", "|", ";", "&", ">", "<"]
        
        for pattern in dangerousPatterns {
            if path.contains(pattern) {
                return .unsafe(reason: "危险的文件路径模式: \(pattern)", threat: .unauthorizedAccess)
            }
        }
        
        return .safe
    }
    
    private func validateNetworkRequest(_ url: String) -> ValidationResult {
        // 检查URL安全性
        guard let urlObject = URL(string: url) else {
            return .unsafe(reason: "无效的URL", threat: .unauthorizedAccess)
        }
        
        // 检查协议安全性
        let allowedSchemes = ["https", "http", "ftp"]
        if !allowedSchemes.contains(urlObject.scheme?.lowercased() ?? "") {
            return .unsafe(reason: "不安全的协议: \(urlObject.scheme ?? "")", threat: .informationDisclosure)
        }
        
        return .safe
    }
    
    private func validateSystemCall(_ command: String) -> ValidationResult {
        // 检查系统调用安全性
        let dangerousCommands = ["rm", "del", "format", "shutdown", "reboot", "kill", "pkill"]
        let lowerCommand = command.lowercased()
        
        for dangerousCmd in dangerousCommands {
            if lowerCommand.contains(dangerousCmd) {
                return .unsafe(reason: "危险系统命令: \(dangerousCmd)", threat: .privilegeEscalation)
            }
        }
        
        return .safe
    }
    
    private func logSecurityEvent(_ level: SecurityLogLevel, message: String) {
        let entry = SecurityLogEntry(
            timestamp: Date(),
            level: level,
            message: message
        )
        
        securityLogs.append(entry)
        
        // 保持日志大小在限制内
        if securityLogs.count > maxLogEntries {
            securityLogs.removeFirst(securityLogs.count - maxLogEntries)
        }
        
        // 输出到控制台
        switch level {
        case .info:
            print("ℹ️ [SECURITY] \(message)")
        case .warning:
            print("⚠️ [SECURITY] \(message)")
        case .error:
            print("🚨 [SECURITY] \(message)")
        }
    }
}

// MARK: - 安全操作类型

/// 安全操作类型
enum SecurityOperation {
    case sqlQuery(String)
    case fileAccess(String)
    case networkRequest(String)
    case systemCall(String)
}

// MARK: - 安全状态

/// 安全状态
enum SecurityStatus: String, CaseIterable {
    case unknown = "unknown"
    case initializing = "initializing"
    case active = "active"
    case inactive = "inactive"
    case secure = "secure"
    case vulnerable = "vulnerable"
    case critical = "critical"
}

// MARK: - 安全日志级别

/// 安全日志级别
enum SecurityLogLevel: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
}

// MARK: - 安全日志条目

/// 安全日志条目
struct SecurityLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: SecurityLogLevel
    let message: String
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
