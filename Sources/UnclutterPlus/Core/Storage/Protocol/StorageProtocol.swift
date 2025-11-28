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
    let cacheSizeLimit: Int  // 重命名避免冲突
    
    static var `default`: StorageConfiguration {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("UnclutterPlus")

        return StorageConfiguration(
            baseURL: baseURL,
            cacheSizeLimit: 100
        )
    }
}