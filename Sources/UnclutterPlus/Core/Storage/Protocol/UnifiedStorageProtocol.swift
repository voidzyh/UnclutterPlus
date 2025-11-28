import Foundation
import Combine

// MARK: - 统一存储协议

/// 统一存储协议 - 消除存储系统复杂性
protocol UnifiedStorageProtocol: AnyObject {
    associatedtype Item: Storable & Identifiable
    associatedtype Index: StorageIndex
    
    // MARK: - 核心操作
    
    /// 创建项目（支持批量）
    func create(_ items: [Item]) async -> Result<Void, StorageOperationError>
    
    /// 读取单个项目（带缓存）
    func read(id: UUID) async -> Result<Item?, StorageOperationError>
    
    /// 批量读取项目
    func readBatch(ids: [UUID]) async -> Result<[Item], StorageOperationError>
    
    /// 更新项目
    func update(_ items: [Item]) async -> Result<Void, StorageOperationError>
    
    /// 删除项目
    func delete(ids: [UUID]) async -> Result<Void, StorageOperationError>
    
    // MARK: - 查询操作
    
    /// 搜索项目（全文搜索）
    func search(query: String, limit: Int?) async -> Result<[Index], StorageOperationError>
    
    /// 获取所有索引（分页支持）
    func getAllIndexes(limit: Int?, offset: Int?) async -> Result<[Index], StorageOperationError>
    
    /// 按条件过滤
    func filter(by predicate: @escaping (Index) -> Bool, limit: Int?) async -> Result<[Index], StorageOperationError>
    
    // MARK: - 统计和管理
    
    /// 获取项目总数
    func count() async -> Result<Int, StorageOperationError>
    
    /// 清空所有数据
    func clear() async -> Result<Void, StorageOperationError>
    
    /// 获取存储统计信息
    func getStatistics() async -> Result<StorageStatistics, StorageOperationError>
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

/// 存储操作错误 - 提供详细的错误信息和恢复建议
enum StorageOperationError: LocalizedError, Equatable {
    case itemNotFound(id: UUID)
    case corruptedData(location: String)
    case diskFull(requiredSpace: Int64)
    case unauthorized(accessPath: String)
    case networkUnavailable
    case serializationFailed(underlying: Error)
    case deserializationFailed(underlying: Error)
    case migrationFailed(from: String, to: String, underlying: Error)
    case cacheExpired(id: UUID)
    case operationCancelled
    case unknown(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "项目未找到 (ID: \(id.uuidString))"
        case .corruptedData(let location):
            return "数据损坏，位置: \(location)"
        case .diskFull(let requiredSpace):
            let size = ByteCountFormatter.string(fromByteCount: requiredSpace, countStyle: .file)
            return "磁盘空间不足，需要 \(size) 空间"
        case .unauthorized(let path):
            return "无权限访问路径: \(path)"
        case .networkUnavailable:
            return "网络连接不可用"
        case .serializationFailed(let error):
            return "数据序列化失败: \(error.localizedDescription)"
        case .deserializationFailed(let error):
            return "数据反序列化失败: \(error.localizedDescription)"
        case .migrationFailed(let from, let to, let error):
            return "数据迁移失败 (\(from) → \(to)): \(error.localizedDescription)"
        case .cacheExpired(let id):
            return "缓存已过期 (ID: \(id.uuidString))"
        case .operationCancelled:
            return "操作被取消"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .diskFull:
            return "请清理磁盘空间或选择其他存储位置"
        case .unauthorized:
            return "请检查文件权限或选择其他存储位置"
        case .corruptedData:
            return "可能需要恢复备份或重新初始化存储"
        case .networkUnavailable:
            return "请检查网络连接或稍后重试"
        case .cacheExpired:
            return "数据可能已更新，请刷新后重试"
        default:
            return nil
        }
    }
    
    // 用于测试的相等性检查
    static func == (lhs: StorageOperationError, rhs: StorageOperationError) -> Bool {
        switch (lhs, rhs) {
        case (.itemNotFound(let lhsId), .itemNotFound(let rhsId)):
            return lhsId == rhsId
        case (.corruptedData(let lhsLoc), .corruptedData(let rhsLoc)):
            return lhsLoc == rhsLoc
        case (.diskFull(let lhsSpace), .diskFull(let rhsSpace)):
            return lhsSpace == rhsSpace
        case (.unauthorized(let lhsPath), .unauthorized(let rhsPath)):
            return lhsPath == rhsPath
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.serializationFailed(let lhs), .serializationFailed(let rhs)):
            return lhs.localizedDescription == rhs.localizedDescription
        case (.deserializationFailed(let lhs), .deserializationFailed(let rhs)):
            return lhs.localizedDescription == rhs.localizedDescription
        case (.migrationFailed(let lhsFrom, let lhsTo, let lhsErr), 
              .migrationFailed(let rhsFrom, let rhsTo, let rhsErr)):
            return lhsFrom == rhsFrom && lhsTo == rhsTo && lhsErr.localizedDescription == rhsErr.localizedDescription
        case (.cacheExpired(let lhsId), .cacheExpired(let rhsId)):
            return lhsId == rhsId
        case (.operationCancelled, .operationCancelled):
            return true
        case (.unknown(let lhs), .unknown(let rhs)):
            return lhs.localizedDescription == rhs.localizedDescription
        default:
            return false
        }
    }
}

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
    
    func create(_ items: [Item]) async -> Result<Void, StorageOperationError> {
        return await withTaskGroup(of: Result<Void, StorageOperationError>.self) { group in
            for item in items {
                group.addTask {
                    return await self.create([item])
                }
            }
            
            var results: [Result<Void, StorageOperationError>] = []
            for await result in group {
                results.append(result)
            }
            
            // 如果所有操作都成功，返回成功；否则返回第一个错误
            let successCount = results.filter { result in
                if case .success = result { return true }
                return false
            }.count
            
            if successCount == results.count {
                return .success(())
            } else if let firstError = results.compactMap({ result in
                if case .failure(let error) = result { return error }
                return nil
            }).first {
                return .failure(firstError)
            } else {
                return .failure(.unknown(underlying: NSError(domain: "UnifiedStorage", code: -1)))
            }
        }
    }
    
    func readBatch(ids: [UUID]) async -> Result<[Item], StorageOperationError> {
        return await withTaskGroup(of: (UUID, Result<Item?, StorageOperationError>).self) { group in
            for id in ids {
                group.addTask {
                    let result = await self.read(id: id)
                    return (id, result)
                }
            }
            
            var items: [UUID: Item] = [:]
            var errors: [StorageOperationError] = []
            
            for await (id, result) in group {
                switch result {
                case .success(let item):
                    if let item = item {
                        items[id] = item
                    }
                case .failure(let error):
                    errors.append(error)
                }
            }
            
            if errors.isEmpty {
                let orderedItems = ids.compactMap { items[$0] }
                return .success(orderedItems)
            } else {
                return .failure(errors.first ?? .unknown(underlying: NSError(domain: "UnifiedStorage", code: -2)))
            }
        }
    }
    
    func update(_ items: [Item]) async -> Result<Void, StorageOperationError> {
        return await create(items) // 复用默认实现
    }
    
    func delete(ids: [UUID]) async -> Result<Void, StorageOperationError> {
        return await withTaskGroup(of: Result<Void, StorageOperationError>.self) { group in
            for id in ids {
                group.addTask {
                    return await self.delete(ids: [id])
                }
            }
            
            var errors: [StorageOperationError] = []
            for await result in group {
                if case .failure(let error) = result {
                    errors.append(error)
                }
            }
            
            if errors.isEmpty {
                return .success(())
            } else {
                return .failure(errors.first ?? .unknown(underlying: NSError(domain: "UnifiedStorage", code: -3)))
            }
        }
    }
    
    func getAllIndexes(limit: Int? = nil, offset: Int? = nil) async -> Result<[Index], StorageOperationError> {
        let result = await search(query: "", limit: nil)
        switch result {
        case .success(var indexes):
            // 应用分页
            if let offset = offset {
                indexes = Array(indexes.dropFirst(offset))
            }
            if let limit = limit {
                indexes = Array(indexes.prefix(limit))
            }
            return .success(indexes)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func count() async -> Result<Int, StorageOperationError> {
        let result = await getAllIndexes()
        switch result {
        case .success(let indexes):
            return .success(indexes.count)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func filter(by predicate: @escaping (Index) -> Bool, limit: Int? = nil) async -> Result<[Index], StorageOperationError> {
        let result = await getAllIndexes()
        switch result {
        case .success(var indexes):
            indexes = indexes.filter(predicate)
            if let limit = limit {
                indexes = Array(indexes.prefix(limit))
            }
            return .success(indexes)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func getStatistics() async -> Result<StorageStatistics, StorageOperationError> {
        let countResult = await count()
        switch countResult {
        case .success(let count):
            let stats = StorageStatistics(
                totalItems: count,
                totalSize: 0, // 子类需要重写以提供实际大小
                cacheSize: 0, // 子类需要重写以提供实际缓存大小
                lastModified: Date(),
                storageType: .hybrid // 默认类型
            )
            return .success(stats)
        case .failure(let error):
            return .failure(error)
        }
    }
}
