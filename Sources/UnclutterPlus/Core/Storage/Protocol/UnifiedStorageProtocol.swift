import Foundation
import Combine

// MARK: - 统一存储协议

/// 统一存储协议 - 消除存储系统复杂性
protocol UnifiedStorageProtocol<Item, Index>: AnyObject {
    associatedtype Item: Storable & Identifiable
    associatedtype Index: StorageIndex
    
    // MARK: - 核心操作
    
    /// 创建项目（支持批量）
    func create(_ items: [Item]) async throws
    
    /// 读取单个项目（带缓存）
    func read(id: UUID) async throws -> Item?
    
    /// 批量读取项目
    func readBatch(ids: [UUID]) async throws -> [Item]
    
    /// 更新项目
    func update(_ items: [Item]) async throws
    
    /// 删除项目
    func delete(ids: [UUID]) async throws
    
    // MARK: - 查询操作
    
    /// 搜索项目（全文搜索）
    func search(query: String, limit: Int?) async throws -> [Index]
    
    /// 获取所有索引（分页支持）
    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [Index]
    
    /// 按条件过滤
    func filter(by predicate: @escaping (Index) -> Bool, limit: Int?) async throws -> [Index]
    
    // MARK: - 统计和管理
    
    /// 获取项目总数
    func count() async throws -> Int
    
    /// 清空所有数据
    func clear() async throws
    
    /// 获取存储统计信息
    func getStatistics() async throws -> StorageStatistics
}

// MARK: - 可存储协议

/// 所有可存储项目必须遵循的协议
protocol Storable: Codable, Identifiable where ID == UUID {
    var id: UUID { get }
    var createdAt: Date { get }
    var modifiedAt: Date { get }
}

// MARK: - 统一的存储索引协议

protocol StorageIndex: Identifiable where ID == UUID {
    associatedtype SortKey: Comparable
    
    var id: UUID { get }
    var sortKey: SortKey { get }
    var isFavorite: Bool { get }
    var preview: String { get }
}

// MARK: - 统一错误处理

// 存储层错误统一使用 Core/Errors/UnclutterError.swift 的 StorageError；
// 此处不再保留独立的错误枚举。

// MARK: - 存储统计信息

/// 存储使用统计
struct StorageStatistics: Sendable, Codable {
    let totalItems: Int
    let totalSize: Int64
    let cacheSize: Int
    let lastModified: Date
    let storageType: StorageType
    
    enum StorageType: String, CaseIterable, Codable {
        case modern = "modern"        // 现代存储（SQLite + FTS）
        case sharded = "sharded"      // 分片存储
        case simple = "simple"        // 简单文件存储
        case hybrid = "hybrid"        // 混合存储
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var description: String {
        """
        存储统计:
        - 项目总数: \(totalItems)
        - 总大小: \(formattedSize)
        - 缓存大小: \(cacheSize)
        - 存储类型: \(storageType.rawValue)
        - 最后修改: \(lastModified)
        """
    }
}

// MARK: - 存储配置

/// 存储配置
struct StorageConfiguration {
    let baseURL: URL
    let cacheSizeLimit: Int
    
    static var `default`: StorageConfiguration {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("UnclutterPlus")

        return StorageConfiguration(
            baseURL: baseURL,
            cacheSizeLimit: 100
        )
    }
}

// MARK: - 存储配置扩展

extension StorageConfiguration {
    /// 创建开发环境配置
    static var development: StorageConfiguration {
        StorageConfiguration(
            baseURL: StorageConfiguration.default.baseURL,
            cacheSizeLimit: 50
        )
    }
    
    /// 创建生产环境配置
    static var production: StorageConfiguration {
        StorageConfiguration(
            baseURL: StorageConfiguration.default.baseURL,
            cacheSizeLimit: 200
        )
    }
}



// MARK: - 默认实现扩展

extension UnifiedStorageProtocol {
    
    // MARK: - 默认实现（便于兼容性）
    
    func create(_ items: [Item]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    try await self.create([item])
                }
            }
            try await group.waitForAll()
        }
    }
    
    func readBatch(ids: [UUID]) async throws -> [Item] {
        try await withThrowingTaskGroup(of: Item?.self) { group in
            for id in ids {
                group.addTask {
                    try await self.read(id: id)
                }
            }
            
            var items: [Item] = []
            for try await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            return items
        }
    }
    
    func update(_ items: [Item]) async throws {
        try await create(items) // 复用默认实现
    }
    
    func delete(ids: [UUID]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask {
                    try await self.delete(ids: [id])
                }
            }
            try await group.waitForAll()
        }
    }
    
    func getAllIndexes(limit: Int? = nil, offset: Int? = nil) async throws -> [Index] {
        let indexes = try await search(query: "", limit: nil)
        var result = indexes
        
        // 应用分页
        if let offset = offset {
            result = Array(result.dropFirst(offset))
        }
        if let limit = limit {
            result = Array(result.prefix(limit))
        }
        return result
    }
    
    func count() async throws -> Int {
        let indexes = try await getAllIndexes(limit: nil, offset: nil)
        return indexes.count
    }
    
    func filter(by predicate: @escaping (Index) -> Bool, limit: Int? = nil) async throws -> [Index] {
        var indexes = try await getAllIndexes(limit: nil, offset: nil)
        indexes = indexes.filter(predicate)
        if let limit = limit {
            indexes = Array(indexes.prefix(limit))
        }
        return indexes
    }
    
    func getStatistics() async throws -> StorageStatistics {
        let count = try await self.count()
        return StorageStatistics(
            totalItems: count,
            totalSize: 0, // 子类需要重写以提供实际大小
            cacheSize: 0, // 子类需要重写以提供实际缓存大小
            lastModified: Date(),
            storageType: .hybrid // 默认类型
        )
    }
}
