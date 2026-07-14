import Foundation
@testable import UnclutterPlus

/// 泛型内存模拟存储 - 用于测试遵循 UnifiedStorageProtocol 的组件
final class MockGenericStorage<Item: Storable & Identifiable, Index: StorageIndex>: UnifiedStorageProtocol {
    
    // 内存存储
    var items: [UUID: Item] = [:]
    var indexes: [Index] = [] // 简化处理，通常 Index 是 Item 的子集或转换
    
    // 用于辅助生成 Index 的闭包（因为协议没规定 Index 必须能从 Item 生成）
    var indexFactory: ((Item) -> Index)?
    
    // 模拟行为配置
    var shouldThrowError: Bool = false
    var simulatedError: Error = NSError(domain: "MockStorage", code: -1, userInfo: nil)
    
    init() {}
    
    // MARK: - Helper Methods
    
    private func checkError() throws {
        if shouldThrowError {
            shouldThrowError = false
            throw simulatedError
        }
    }
    
    // MARK: - UnifiedStorageProtocol Implementation
    
    func create(_ items: [Item]) async throws {
        try checkError()
        for item in items {
            self.items[item.id] = item
            if let factory = indexFactory {
                self.indexes.append(factory(item))
            }
        }
    }
    
    func read(id: UUID) async throws -> Item? {
        try checkError()
        return items[id]
    }
    
    func readBatch(ids: [UUID]) async throws -> [Item] {
        try checkError()
        return ids.compactMap { items[$0] }
    }
    
    func update(_ items: [Item]) async throws {
        try checkError()
        for item in items {
            // 只有存在的才更新，模拟真实行为
            if self.items[item.id] != nil {
                self.items[item.id] = item
                // 简单起见，这里不更新 indexes 列表中的对应项（因为没有 id 映射），测试时需注意
            } else {
                throw NSError(domain: "MockStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
            }
        }
    }
    
    func delete(ids: [UUID]) async throws {
        try checkError()
        for id in ids {
            items.removeValue(forKey: id)
        }
    }
    
    func search(query: String, limit: Int?) async throws -> [Index] {
        try checkError()
        // Mock 简单的搜索：直接返回所有（或者如果在测试中配置了特定返回）
        return indexes
    }
    
    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [Index] {
        try checkError()
        return indexes
    }
    
    func filter(by predicate: @escaping (Index) -> Bool, limit: Int?) async throws -> [Index] {
        try checkError()
        return indexes.filter(predicate)
    }
    
    func count() async throws -> Int {
        try checkError()
        return items.count
    }
    
    func clear() async throws {
        try checkError()
        items.removeAll()
        indexes.removeAll()
    }
    
    func getStatistics() async throws -> StorageStatistics {
        try checkError()
        return StorageStatistics(
            totalItems: items.count,
            totalSize: 0,
            cacheSize: items.count,
            lastModified: Date(),
            storageType: .simple
        )
    }
}
