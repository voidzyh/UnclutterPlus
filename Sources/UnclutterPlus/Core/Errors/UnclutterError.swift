import Foundation

// MARK: - UnclutterError Protocol

/// UnclutterPlus 统一错误协议
///
/// 所有应用内的错误都应遵循此协议，确保错误信息结构化和用户友好
protocol UnclutterError: LocalizedError {
    /// 错误分类
    var category: ErrorCategory { get }

    /// 用户可见的错误描述
    var userMessage: String { get }

    /// 恢复建议（可选）
    var recoverySuggestion: String? { get }

    /// 底层错误（可选）
    var underlyingError: Error? { get }

    /// 错误代码（用于日志和调试）
    var errorCode: String { get }
}

// MARK: - Error Category

/// 错误分类
enum ErrorCategory: String {
    case storage = "存储错误"
    case network = "网络错误"
    case validation = "验证错误"
    case permission = "权限错误"
    case system = "系统错误"
    case unknown = "未知错误"

    /// 默认的恢复建议
    var defaultRecoverySuggestion: String {
        switch self {
        case .storage:
            return "请检查磁盘空间和文件权限"
        case .network:
            return "请检查网络连接"
        case .validation:
            return "请检查输入内容"
        case .permission:
            return "请在系统设置中授予权限"
        case .system:
            return "请重启应用或联系技术支持"
        case .unknown:
            return "请重试或联系技术支持"
        }
    }
}

// MARK: - Storage Errors

/// 存储相关错误
enum StorageError: UnclutterError {
    case notFound(UUID)                           // 资源未找到
    case corrupted(String)                         // 数据损坏
    case quotaExceeded(Int64)                      // 存储空间不足
    case writeFailed(underlying: Error)            // 写入失败
    case readFailed(underlying: Error)             // 读取失败
    case deleteFailed(underlying: Error)           // 删除失败
    case invalidPath(String)                       // 无效路径
    case initializationFailed(underlying: Error)   // 初始化失败

    // MARK: - UnclutterError Implementation

    var category: ErrorCategory {
        return .storage
    }

    var userMessage: String {
        switch self {
        case .notFound(let id):
            return "未找到指定笔记（ID: \(id.uuidString.prefix(8))）"
        case .corrupted(let resource):
            return "数据损坏：\(resource)"
        case .quotaExceeded(let required):
            let formattedSize = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            return "存储空间不足（需要 \(formattedSize)）"
        case .writeFailed:
            return "保存失败"
        case .readFailed:
            return "读取失败"
        case .deleteFailed:
            return "删除失败"
        case .invalidPath(let path):
            return "无效的文件路径：\(path)"
        case .initializationFailed:
            return "存储服务初始化失败"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "该笔记可能已被删除，请刷新列表"
        case .corrupted:
            return "尝试从备份恢复或删除损坏的数据"
        case .quotaExceeded:
            return "清理磁盘空间或删除旧笔记"
        case .writeFailed, .readFailed, .deleteFailed:
            return "检查文件权限或重试"
        case .invalidPath:
            return "请检查应用设置中的存储路径"
        case .initializationFailed:
            return "重启应用或重新安装"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .writeFailed(let error),
             .readFailed(let error),
             .deleteFailed(let error),
             .initializationFailed(let error):
            return error
        default:
            return nil
        }
    }

    var errorCode: String {
        switch self {
        case .notFound:           return "STORAGE_001"
        case .corrupted:          return "STORAGE_002"
        case .quotaExceeded:      return "STORAGE_003"
        case .writeFailed:        return "STORAGE_004"
        case .readFailed:         return "STORAGE_005"
        case .deleteFailed:       return "STORAGE_006"
        case .invalidPath:        return "STORAGE_007"
        case .initializationFailed: return "STORAGE_008"
        }
    }

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        return "[\(errorCode)] \(userMessage)"
    }

    var failureReason: String? {
        return category.rawValue
    }
}

// MARK: - Service Errors

/// 服务层错误
enum ServiceError: UnclutterError {
    case initializationFailed(service: String, underlying: Error)  // 服务初始化失败
    case operationFailed(service: String, operation: String)       // 操作失败
    case timeout(String)                                            // 超时
    case invalidConfiguration(String)                               // 配置无效
    case resourceExhausted(String)                                  // 资源耗尽
    case serviceUnavailable(String)                                 // 服务不可用
    case unknown(underlying: Error)                                 // 未分类错误（asUnclutterError 兜底）

    var category: ErrorCategory {
        return .system
    }

    var userMessage: String {
        switch self {
        case .initializationFailed(let service, _):
            return "\(service) 服务初始化失败"
        case .operationFailed(let service, let operation):
            return "\(service) 执行 \(operation) 失败"
        case .timeout(let operation):
            return "操作超时：\(operation)"
        case .invalidConfiguration(let config):
            return "配置无效：\(config)"
        case .resourceExhausted(let resource):
            return "资源耗尽：\(resource)"
        case .serviceUnavailable(let service):
            return "\(service) 服务暂时不可用"
        case .unknown:
            return "发生未知错误"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "重启应用或检查系统日志"
        case .operationFailed:
            return "重试操作或查看错误详情"
        case .timeout:
            return "稍后重试或检查系统负载"
        case .invalidConfiguration:
            return "检查应用设置中的配置项"
        case .resourceExhausted:
            return "关闭其他应用释放资源"
        case .serviceUnavailable:
            return "稍后重试或联系技术支持"
        case .unknown:
            return "重试操作或联系技术支持"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .initializationFailed(_, let error):
            return error
        case .unknown(let error):
            return error
        default:
            return nil
        }
    }

    var errorCode: String {
        switch self {
        case .initializationFailed: return "SERVICE_001"
        case .operationFailed:      return "SERVICE_002"
        case .timeout:              return "SERVICE_003"
        case .invalidConfiguration: return "SERVICE_004"
        case .resourceExhausted:    return "SERVICE_005"
        case .serviceUnavailable:   return "SERVICE_006"
        case .unknown:              return "SERVICE_007"
        }
    }

    var errorDescription: String? {
        return "[\(errorCode)] \(userMessage)"
    }
}

// MARK: - Validation Errors

/// 验证错误
enum ValidationError: UnclutterError {
    case emptyTitle                                           // 标题为空
    case titleTooLong(maxLength: Int)                         // 标题过长
    case contentTooLarge(maxSize: Int)                        // 内容过大
    case invalidTag(String)                                   // 无效标签
    case invalidURL(String)                                   // 无效 URL
    case missingRequiredField(String)                         // 缺少必填字段
    case invalidData(String)                                  // 无效数据

    var category: ErrorCategory {
        return .validation
    }

    var userMessage: String {
        switch self {
        case .emptyTitle:
            return "笔记标题不能为空"
        case .titleTooLong(let max):
            return "标题过长（最大 \(max) 个字符）"
        case .contentTooLarge(let max):
            return "内容过大（最大 \(ByteCountFormatter.string(fromByteCount: Int64(max), countStyle: .file))）"
        case .invalidTag(let tag):
            return "无效的标签：\(tag)"
        case .invalidURL(let url):
            return "无效的链接：\(url)"
        case .missingRequiredField(let field):
            return "缺少必填字段：\(field)"
        case .invalidData(let message):
            return "数据验证失败：\(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyTitle:
            return "请输入笔记标题"
        case .titleTooLong:
            return "缩短标题或使用缩写"
        case .contentTooLarge:
            return "拆分内容或删除不必要的部分"
        case .invalidTag:
            return "标签只能包含字母、数字和中文"
        case .invalidURL:
            return "检查链接格式（如 https://example.com）"
        case .missingRequiredField:
            return "填写所有必填字段"
        case .invalidData:
            return "检查输入数据格式"
        }
    }

    var underlyingError: Error? {
        return nil
    }

    var errorCode: String {
        switch self {
        case .emptyTitle:          return "VALIDATION_001"
        case .titleTooLong:        return "VALIDATION_002"
        case .contentTooLarge:     return "VALIDATION_003"
        case .invalidTag:          return "VALIDATION_004"
        case .invalidURL:          return "VALIDATION_005"
        case .missingRequiredField: return "VALIDATION_006"
        case .invalidData:         return "VALIDATION_007"
        }
    }

    var errorDescription: String? {
        return "[\(errorCode)] \(userMessage)"
    }
}

// MARK: - Screenshot Errors

/// 截图相关错误
enum ScreenshotError: UnclutterError {
    case captureFailed(underlying: Error)              // 截图捕获失败
    case saveFailed(underlying: Error)                 // 保存失败
    case conversionFailed                               // 图片转换失败
    case metadataFailed(String)                         // 元数据操作失败
    case ocrFailed(underlying: Error)                   // OCR 识别失败
    case fileNotFound(URL)                              // 文件不存在
    case invalidImageData                               // 无效的图片数据

    var category: ErrorCategory {
        return .storage
    }

    var userMessage: String {
        switch self {
        case .captureFailed:
            return "截图捕获失败"
        case .saveFailed:
            return "保存截图失败"
        case .conversionFailed:
            return "图片格式转换失败"
        case .metadataFailed(let operation):
            return "元数据\(operation)失败"
        case .ocrFailed:
            return "OCR 文字识别失败"
        case .fileNotFound(let url):
            return "找不到截图文件：\(url.lastPathComponent)"
        case .invalidImageData:
            return "无效的图片数据"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .captureFailed:
            return "检查系统权限或重试"
        case .saveFailed:
            return "检查磁盘空间或文件权限"
        case .conversionFailed:
            return "尝试其他截图格式或重启应用"
        case .metadataFailed:
            return "清理缓存或重启应用"
        case .ocrFailed:
            return "检查 OCR 配置或手动识别"
        case .fileNotFound:
            return "截图可能已被删除，刷新列表"
        case .invalidImageData:
            return "重新截图或检查源数据"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .captureFailed(let error),
             .saveFailed(let error),
             .ocrFailed(let error):
            return error
        default:
            return nil
        }
    }

    var errorCode: String {
        switch self {
        case .captureFailed:      return "SCREENSHOT_001"
        case .saveFailed:         return "SCREENSHOT_002"
        case .conversionFailed:   return "SCREENSHOT_003"
        case .metadataFailed:     return "SCREENSHOT_004"
        case .ocrFailed:          return "SCREENSHOT_005"
        case .fileNotFound:       return "SCREENSHOT_006"
        case .invalidImageData:   return "SCREENSHOT_007"
        }
    }

    var errorDescription: String? {
        return "[\(errorCode)] \(userMessage)"
    }
}

// MARK: - Permission Errors

/// 权限错误
enum PermissionError: UnclutterError {
    case clipboardAccessDenied                             // 剪贴板权限拒绝
    case fileAccessDenied(path: String)                    // 文件访问拒绝
    case screenRecordingDenied                             // 屏幕录制权限拒绝
    case accessibilityDenied                               // 辅助功能权限拒绝

    var category: ErrorCategory {
        return .permission
    }

    var userMessage: String {
        switch self {
        case .clipboardAccessDenied:
            return "无法访问剪贴板"
        case .fileAccessDenied(let path):
            return "无法访问文件：\(path)"
        case .screenRecordingDenied:
            return "无法录制屏幕"
        case .accessibilityDenied:
            return "需要辅助功能权限"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .clipboardAccessDenied:
            return "在系统设置 > 隐私与安全性 > 剪贴板中授权"
        case .fileAccessDenied:
            return "检查文件权限或在系统设置中授权"
        case .screenRecordingDenied:
            return "在系统设置 > 隐私与安全性 > 屏幕录制中授权"
        case .accessibilityDenied:
            return "在系统设置 > 隐私与安全性 > 辅助功能中授权"
        }
    }

    var underlyingError: Error? {
        return nil
    }

    var errorCode: String {
        switch self {
        case .clipboardAccessDenied:  return "PERMISSION_001"
        case .fileAccessDenied:      return "PERMISSION_002"
        case .screenRecordingDenied: return "PERMISSION_003"
        case .accessibilityDenied:   return "PERMISSION_004"
        }
    }

    var errorDescription: String? {
        return "[\(errorCode)] \(userMessage)"
    }
}

// MARK: - Error Extensions

/// 系统错误扩展
extension Error {
    /// 将系统错误转换为 UnclutterError
    func asUnclutterError() -> UnclutterError {
        // 如果已经是 UnclutterError，直接返回
        if let unclutterError = self as? UnclutterError {
            return unclutterError
        }

        // 根据错误类型进行包装
        let nsError = self as NSError

        // 文件系统错误
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileNoSuchFileError:
                return StorageError.notFound(UUID()) // 使用临时 UUID
            case NSFileWriteOutOfSpaceError:
                return StorageError.quotaExceeded(0)
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return PermissionError.fileAccessDenied(path: nsError.userInfo[NSFilePathErrorKey] as? String ?? "未知路径")
            default:
                return StorageError.writeFailed(underlying: self)
            }
        }

        // 默认包装为系统错误（保留底层错误信息）
        return ServiceError.unknown(underlying: self)
    }

    /// 提取用户友好的错误描述
    func userFriendlyMessage() -> String {
        let unclutterError = self.asUnclutterError()
        return unclutterError.userMessage
    }

    /// 提取恢复建议
    func recoverySuggestion() -> String? {
        let unclutterError = self.asUnclutterError()
        return unclutterError.recoverySuggestion
    }
}

// MARK: - Error Logging Helper

/// 错误日志辅助方法
extension UnclutterError {
    /// 记录错误到日志系统
    func log(context: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(function):\(line)"

        var message = "[\(errorCode)] \(userMessage)"
        if !context.isEmpty {
            message += " | Context: \(context)"
        }
        if let suggestion = recoverySuggestion {
            message += " | Suggestion: \(suggestion)"
        }

        logger.error(
            message + " | Location: \(location)",
            category: category == .storage ? "Storage" :
                     category == .validation ? "Service" :
                     category == .permission ? "Security" :
                     category == .system ? "Service" : "General"
        )

        // 记录底层错误
        if let underlying = underlyingError {
            logger.error(
                "Underlying error: \(underlying.localizedDescription)",
                category: "Service"
            )
        }
    }
}
