import Foundation
@testable import UnclutterPlus

/// 内存模拟笔记存储 - 用于测试
final class MockNoteStorage: UnifiedStorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex
    
    // 内存存储
    var items: [UUID: Note] = [:]
    var indexes: [UUID: NoteIndex] = [:]
    
    // 模拟行为配置
    var shouldFailNextRequest: Bool = false
    var simulatedError: StorageError = .writeFailed(underlying: NSError(domain: "Mock", code: -1))
    var simulatedDelay: TimeInterval = 0
    
    // 调用记录（用于验证）
    var createCalledCount = 0
    var readCalledCount = 0
    var updateCalledCount = 0
    var deleteCalledCount = 0
    
    init() {}
    
    // MARK: - Helper Methods
    
    private func simulateDelay() async {
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
    }
    
    private func checkFailure() throws {
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw simulatedError
        }
    }
    
    // MARK: - UnifiedStorageProtocol Implementation
    
    func create(_ items: [Note]) async throws {
        await simulateDelay()
        createCalledCount += 1
        try checkFailure()
        
        for item in items {
            self.items[item.id] = item
            self.indexes[item.id] = NoteIndex(from: item)
        }
    }
    
    func read(id: UUID) async throws -> Note? {
        await simulateDelay()
        readCalledCount += 1
        
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw simulatedError
        }
        
        return items[id]
    }
    
    func readBatch(ids: [UUID]) async throws -> [Note] {
        await simulateDelay()
        
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw simulatedError
        }
        
        return ids.compactMap { items[$0] }
    }
    
    func update(_ items: [Note]) async throws {
        await simulateDelay()
        updateCalledCount += 1
        try checkFailure()
        
        for item in items {
            // 只有存在的项目才更新
            if self.items[item.id] != nil {
                self.items[item.id] = item
                self.indexes[item.id] = NoteIndex(from: item)
            } else {
                throw StorageError.notFound(item.id)
            }
        }
    }
    
    func delete(ids: [UUID]) async throws {
        await simulateDelay()
        deleteCalledCount += 1
        try checkFailure()
        
        for id in ids {
            self.items.removeValue(forKey: id)
            self.indexes.removeValue(forKey: id)
        }
    }
    
    func search(query: String, limit: Int?) async throws -> [NoteIndex] {
        await simulateDelay()
        
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw simulatedError
        }
        
        let lowerQuery = query.lowercased()
        var result = indexes.values.filter { index in
            if query.isEmpty { return true }
            return index.title.lowercased().contains(lowerQuery) || 
                   index.preview.lowercased().contains(lowerQuery)
        }.sorted { $0.modifiedAt > $1.modifiedAt }
        
        if let limit = limit {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [NoteIndex] {
        await simulateDelay()
        
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw simulatedError
        }
        
        var result = Array(indexes.values).sorted { $0.modifiedAt > $1.modifiedAt }
        
        if let offset = offset {
            if offset < result.count {
                result = Array(result.dropFirst(offset))
            } else {
                result = []
            }
        }
        
        if let limit = limit {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    func filter(by predicate: @escaping (NoteIndex) -> Bool, limit: Int?) async throws -> [NoteIndex] {
        await simulateDelay()
        
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw simulatedError
        }
        
        var result = indexes.values.filter(predicate).sorted { $0.modifiedAt > $1.modifiedAt }
        
        if let limit = limit {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    func count() async throws -> Int {
        await simulateDelay()
        return items.count
    }
    
    func clear() async throws {
        await simulateDelay()
        items.removeAll()
        indexes.removeAll()
    }
    
    func getStatistics() async throws -> StorageStatistics {
        await simulateDelay()
        
        return StorageStatistics(
            totalItems: items.count,
            totalSize: 0,
            cacheSize: items.count,
            lastModified: Date(),
            storageType: .simple
        )
    }
}
