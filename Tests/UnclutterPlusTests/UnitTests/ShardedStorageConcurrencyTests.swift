import XCTest
@testable import UnclutterPlus

/// 分片存储 actor 并发模型测试：并发读写删、跨实例持久化、索引重建。
final class ShardedStorageConcurrencyTests: XCTestCase {

    private var baseURL: URL!

    override func setUp() async throws {
        baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sharded-test-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: baseURL)
    }

    private func makeItem(_ name: String) -> ClipboardItem {
        ClipboardItem(content: .text(name))
    }

    // MARK: - 并发读写

    func testConcurrentCreatesThenReads() async throws {
        let storage = ShardedStorage<ClipboardItem>(baseURL: baseURL, strategy: .byHash(buckets: 4))
        let items = (0..<50).map { makeItem("item-\($0)") }

        // When - 并发创建 50 项
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    try? await storage.create(item)
                }
            }
        }

        // Then - 并发读取全部命中
        let readResults = await withTaskGroup(of: (UUID, String?).self) { group in
            for item in items {
                group.addTask {
                    let loaded = try? await storage.read(id: item.id)
                    if case .text(let text)? = loaded?.content {
                        return (item.id, text)
                    }
                    return (item.id, nil)
                }
            }

            var results: [UUID: String?] = [:]
            for await (id, text) in group {
                results[id] = text
            }
            return results
        }

        for item in items {
            XCTAssertEqual(readResults[item.id] ?? nil, item.preview, "\(item.id) 应读取到自身内容")
        }

        // 全部 50 项内容正确
        let all = try await storage.loadAll()
        XCTAssertEqual(all.count, 50)
    }

    func testConcurrentDeleteBatch() async throws {
        let storage = ShardedStorage<ClipboardItem>(baseURL: baseURL, strategy: .byCount(4))
        let items = (0..<30).map { makeItem("delete-\($0)") }

        for item in items {
            try await storage.create(item)
        }

        // When - 批量删除前半
        let toDelete = items.prefix(15).map(\.id)
        try await storage.deleteBatch(ids: toDelete)

        // Then
        let remaining = try await storage.loadAll()
        XCTAssertEqual(remaining.count, 15)
        for id in toDelete {
            let loaded = try await storage.read(id: id)
            XCTAssertNil(loaded)
        }
    }

    // MARK: - 跨实例持久化与索引重建

    func testPersistenceAcrossInstancesAndIndexRebuild() async throws {
        let first = ShardedStorage<ClipboardItem>(baseURL: baseURL, strategy: .individual)
        let items = (0..<10).map { makeItem("persist-\($0)") }
        for item in items {
            try await first.create(item)
        }
        // 不等待防抖索引落盘，直接新开实例（索引可能只有部分条目甚至为空）
        let second = ShardedStorage<ClipboardItem>(baseURL: baseURL, strategy: .individual)

        // Then - 通过目录扫描兜底，全部条目可读
        for item in items {
            let loaded = try await second.read(id: item.id)
            XCTAssertEqual(loaded?.preview, item.preview, "跨实例 + 索引未落盘时应通过目录扫描兜底读取")
        }
        let all = try await second.loadAll()
        XCTAssertEqual(all.count, 10)
    }

    func testClearRemovesEverything() async throws {
        let storage = ShardedStorage<ClipboardItem>(baseURL: baseURL, strategy: .byMonth)
        for index in 0..<5 {
            try await storage.create(makeItem("clear-\(index)"))
        }

        try await storage.clear()

        let all = try await storage.loadAll()
        XCTAssertTrue(all.isEmpty)
    }
}
