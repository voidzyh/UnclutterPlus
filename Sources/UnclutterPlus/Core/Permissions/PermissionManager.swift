import Foundation

/// 权限类型
public enum PermissionType {
    case fileSystem
    case clipboard
    case screenCapture
    case accessibility
}

/// 权限状态
public enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
}

/// 权限管理器 - 负责管理系统权限
@MainActor
public final class PermissionManager {
    public static let shared = PermissionManager()

    private init() {}

    /// 检查指定类型的权限状态
    public func checkPermission(_ type: PermissionType) async -> PermissionStatus {
        // 模拟权限检查
        // 在实际实现中，这里会调用 macOS 的权限 API
        // 例如:
        // - fileSystem: 使用 FileManager 权限检查
        // - clipboard: 使用 NSPasteboard 权限检查
        // - screenCapture: 使用 ScreenCaptureKit 权限检查
        // - accessibility: 使用 Accessibility API 检查

        return .authorized
    }

    /// 请求指定类型的权限
    public func requestPermission(_ type: PermissionType) async -> PermissionStatus {
        // 模拟权限请求
        // 在实际实现中，这里会触发系统权限请求对话框
        return await checkPermission(type)
    }
}
