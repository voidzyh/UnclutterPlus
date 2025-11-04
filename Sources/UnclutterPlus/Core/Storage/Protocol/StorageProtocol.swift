import Foundation

/// 通用存储协议
protocol StorageProtocol {
    associatedtype Item: Codable & Identifiable where Item.ID == UUID
    associatedtype Index: Codable

    /// 创建项目
    func create(_ item: Item) async throws

    /// 读取单个项目
    func read(id: UUID) async throws -> Item?

    /// 批量读取
    func readBatch(ids: [UUID]) async throws -> [Item]

    /// 更新项目
    func update(_ item: Item) async throws

    /// 删除项目
    func delete(id: UUID) async throws

    /// 批量删除
    func deleteBatch(ids: [UUID]) async throws

    /// 搜索项目
    func search(query: String) async throws -> [Index]

    /// 列出项目
    func list(limit: Int, offset: Int) async throws -> [Index]

    /// 获取所有索引
    func getAllIndexes() async throws -> [Index]

    /// 清空所有数据
    func clear() async throws
}

/// 存储配置
struct StorageConfiguration {
    let baseURL: URL
    let maxCacheSize: Int
    let enableCompression: Bool
    let enableEncryption: Bool

    static var `default`: StorageConfiguration {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("UnclutterPlus")

        return StorageConfiguration(
            baseURL: baseURL,
            maxCacheSize: 100,
            enableCompression: false,
            enableEncryption: false
        )
    }
}

/// 存储错误类型
enum StorageError: LocalizedError {
    case notFound
    case corrupted
    case diskFull
    case unauthorized
    case migrationFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "数据未找到"
        case .corrupted:
            return "数据损坏"
        case .diskFull:
            return "磁盘空间不足"
        case .unauthorized:
            return "无权限访问"
        case .migrationFailed:
            return "数据迁移失败"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}