import Foundation

/// 存储操作错误类型（已废弃，请使用 UnclutterError.StorageError）
@available(*, deprecated, renamed: "UnclutterError.StorageError", message: "请使用 UnclutterError.StorageError 替代")
enum LegacyStorageError: LocalizedError {
    case unknown(Error)
    case corrupted
    case notFound
    case invalidData
    case permissionDenied
    case diskFull

    var errorDescription: String? {
        switch self {
        case .unknown(let error):
            return "Unknown storage error: \(error.localizedDescription)"
        case .corrupted:
            return "Storage data is corrupted"
        case .notFound:
            return "Item not found in storage"
        case .invalidData:
            return "Invalid data format"
        case .permissionDenied:
            return "Permission denied"
        case .diskFull:
            return "Disk space is full"
        }
    }
}
