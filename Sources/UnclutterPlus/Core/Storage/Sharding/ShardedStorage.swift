import Foundation

/// 分片策略
enum ShardingStrategy {
    /// 按月分片（适用于时间序列数据）
    case byMonth

    /// 按数量分片（每个分片存储固定数量的项目）
    case byCount(Int)

    /// 每个项目独立文件（适用于大型文档）
    case individual

    /// 按哈希分片（均匀分布）
    case byHash(buckets: Int)
}

/// 分片存储实现
class ShardedStorage<Item: Codable & Identifiable> where Item.ID == UUID {
    private let baseURL: URL
    private let strategy: ShardingStrategy
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "sharded.storage", attributes: .concurrent)

    // 分片索引（记录每个 ID 对应的分片位置）
    private var shardIndex: [UUID: String] = [:]
    private let indexURL: URL

    // MARK: - Initialization

    init(baseURL: URL, strategy: ShardingStrategy) {
        self.baseURL = baseURL
        self.strategy = strategy
        self.indexURL = baseURL.appendingPathComponent(".shard_index.json")

        // 配置编码器
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [] // 紧凑格式，节省空间

        // 配置解码器
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        // 创建基础目录
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)

        // 加载分片索引
        loadShardIndex()
    }

    // MARK: - Public Methods

    /// 保存项目
    func save(_ item: Item) async throws {
        let shardPath = getShardPath(for: item)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageError.unknown(NSError()))
                    return
                }

                do {
                    // 确保分片目录存在
                    let directory = shardPath.deletingLastPathComponent()
                    try self.fileManager.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )

                    // 编码并保存
                    let data = try self.encoder.encode(item)
                    try data.write(to: shardPath, options: .atomic)

                    // 更新分片索引
                    self.shardIndex[item.id] = shardPath.lastPathComponent
                    self.saveShardIndex()

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.unknown(error))
                }
            }
        }
    }

    /// 批量保存
    func saveBatch(_ items: [Item]) async throws {
        await withTaskGroup(of: Error?.self) { group in
            for item in items {
                group.addTask { [weak self] in
                    do {
                        try await self?.save(item)
                        return nil
                    } catch {
                        return error
                    }
                }
            }

            // 收集错误
            var errors: [Error] = []
            for await error in group {
                if let error = error {
                    errors.append(error)
                }
            }

            if !errors.isEmpty {
                print("❌ Batch save errors: \(errors)")
            }
        }
    }

    /// 加载项目
    func load(id: UUID) async throws -> Item? {
        guard let shardName = shardIndex[id] else {
            // 尝试查找
            if let path = try await findItemPath(id: id) {
                return try await loadFromPath(path)
            }
            return nil
        }

        let shardPath = getShardDirectory(for: shardName).appendingPathComponent("\(id.uuidString).json")
        return try await loadFromPath(shardPath)
    }

    /// 批量加载
    func loadBatch(ids: [UUID]) async throws -> [Item] {
        return await withTaskGroup(of: Item?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    try? await self?.load(id: id)
                }
            }

            var items: [Item] = []
            for await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            return items
        }
    }

    /// 删除项目
    func delete(id: UUID) async throws {
        guard let shardName = shardIndex[id] else {
            return
        }

        let shardPath = getShardDirectory(for: shardName).appendingPathComponent("\(id.uuidString).json")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                do {
                    try self?.fileManager.removeItem(at: shardPath)
                    self?.shardIndex.removeValue(forKey: id)
                    self?.saveShardIndex()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 获取所有项目
    func loadAll() async throws -> [Item] {
        var items: [Item] = []

        let shardDirs = try fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
            return isDirectory == true && !url.lastPathComponent.hasPrefix(".")
        }

        await withTaskGroup(of: [Item].self) { group in
            for shardDir in shardDirs {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }

                    let files = (try? self.fileManager.contentsOfDirectory(
                        at: shardDir,
                        includingPropertiesForKeys: nil
                    ).filter { $0.pathExtension == "json" }) ?? []

                    var shardItems: [Item] = []
                    for file in files {
                        if let item = try? await self.loadFromPath(file) {
                            shardItems.append(item)
                        }
                    }
                    return shardItems
                }
            }

            for await shardItems in group {
                items.append(contentsOf: shardItems)
            }
        }

        return items
    }

    /// 清空所有数据
    func clear() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                do {
                    // 删除所有分片目录
                    let contents = try self.fileManager.contentsOfDirectory(
                        at: self.baseURL,
                        includingPropertiesForKeys: nil
                    )

                    for item in contents {
                        try self.fileManager.removeItem(at: item)
                    }

                    // 清空索引
                    self.shardIndex.removeAll()
                    self.saveShardIndex()

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// 获取项目的分片路径
    private func getShardPath(for item: Item) -> URL {
        let shardDir: URL

        switch strategy {
        case .byMonth:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthStr = formatter.string(from: Date())
            shardDir = baseURL.appendingPathComponent(monthStr)

        case .byCount(let size):
            let shardIndex = abs(item.id.hashValue) % size
            shardDir = baseURL.appendingPathComponent("shard_\(shardIndex)")

        case .individual:
            shardDir = baseURL.appendingPathComponent("items")

        case .byHash(let buckets):
            let bucket = abs(item.id.hashValue) % buckets
            shardDir = baseURL.appendingPathComponent("bucket_\(bucket)")
        }

        return shardDir.appendingPathComponent("\(item.id.uuidString).json")
    }

    /// 获取分片目录
    private func getShardDirectory(for shardName: String) -> URL {
        // 从文件名推断目录
        if shardName.contains("/") {
            let components = shardName.split(separator: "/")
            if components.count == 2 {
                return baseURL.appendingPathComponent(String(components[0]))
            }
        }

        // 默认在根目录
        return baseURL
    }

    /// 从路径加载项目
    private func loadFromPath(_ path: URL) async throws -> Item? {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let data = try Data(contentsOf: path)
                    let item = try self.decoder.decode(Item.self, from: data)
                    continuation.resume(returning: item)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 查找项目路径
    private func findItemPath(id: UUID) async throws -> URL? {
        let filename = "\(id.uuidString).json"

        let shardDirs = try fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
            return isDirectory == true && !url.lastPathComponent.hasPrefix(".")
        }

        for shardDir in shardDirs {
            let possiblePath = shardDir.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: possiblePath.path) {
                // 更新索引
                let shardName = "\(shardDir.lastPathComponent)/\(filename)"
                shardIndex[id] = shardName
                saveShardIndex()
                return possiblePath
            }
        }

        return nil
    }

    /// 加载分片索引
    private func loadShardIndex() {
        guard fileManager.fileExists(atPath: indexURL.path) else { return }

        do {
            let data = try Data(contentsOf: indexURL)
            let index = try JSONDecoder().decode([String: String].self, from: data)

            // 转换为 UUID 索引
            shardIndex = index.compactMapKeys { UUID(uuidString: $0) }
        } catch {
            print("❌ Failed to load shard index: \(error)")
        }
    }

    /// 保存分片索引
    private func saveShardIndex() {
        do {
            // 转换为字符串索引
            let stringIndex = shardIndex.reduce(into: [String: String]()) { result, pair in
                result[pair.key.uuidString] = pair.value
            }

            let data = try JSONEncoder().encode(stringIndex)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("❌ Failed to save shard index: \(error)")
        }
    }
}

// MARK: - Dictionary Helper Extension

private extension Dictionary {
    /// 压缩映射键
    func compactMapKeys<T>(_ transform: (Key) -> T?) -> [T: Value] {
        var result = [T: Value]()
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}

// MARK: - Complete Storage Implementation

/// 完整的笔记存储实现（结合索引、缓存、分片）
class ModernNoteStorage: StorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex

    private let indexDB: IndexDatabase
    private let cacheManager: CacheManager
    private let shardedStorage: ShardedStorage<Note>
    private let configuration: StorageConfiguration

    init(configuration: StorageConfiguration) throws {
        self.configuration = configuration

        // 初始化索引数据库
        self.indexDB = try IndexDatabase(path: configuration.baseURL)

        // 初始化缓存管理器
        self.cacheManager = CacheManager(l1Size: 10, l2Size: 100, searchSize: 50)

        // 初始化分片存储
        self.shardedStorage = ShardedStorage(
            baseURL: configuration.baseURL.appendingPathComponent("Notes"),
            strategy: .individual // 每个笔记一个文件
        )
    }

    func create(_ item: Note) async throws {
        // 1. 保存到分片存储
        try await shardedStorage.save(item)

        // 2. 更新索引
        let index = NoteIndex(from: item)
        try await indexDB.upsertNoteIndex(index)

        // 3. 更新缓存
        await cacheManager.cacheNote(item)
    }

    func read(id: UUID) async throws -> Note? {
        // 1. 检查缓存
        if let cached = await cacheManager.getNote(id: id) {
            return cached
        }

        // 2. 从分片存储读取
        if let note = try await shardedStorage.load(id: id) {
            // 3. 更新缓存
            await cacheManager.cacheNote(note)
            return note
        }

        return nil
    }

    func readBatch(ids: [UUID]) async throws -> [Note] {
        var results: [Note] = []
        var missingIds: [UUID] = []

        // 1. 从缓存获取
        for id in ids {
            if let cached = await cacheManager.getNote(id: id) {
                results.append(cached)
            } else {
                missingIds.append(id)
            }
        }

        // 2. 批量从存储加载
        if !missingIds.isEmpty {
            let loaded = try await shardedStorage.loadBatch(ids: missingIds)
            results.append(contentsOf: loaded)

            // 3. 更新缓存
            for note in loaded {
                await cacheManager.cacheNote(note)
            }
        }

        return results
    }

    func update(_ item: Note) async throws {
        // 1. 更新分片存储
        try await shardedStorage.save(item)

        // 2. 更新索引
        let index = NoteIndex(from: item)
        try await indexDB.upsertNoteIndex(index)

        // 3. 更新缓存
        await cacheManager.cacheNote(item)

        // 4. 清除搜索缓存
        await cacheManager.clearSearchCache()
    }

    func delete(id: UUID) async throws {
        // 1. 从分片存储删除
        try await shardedStorage.delete(id: id)

        // 2. 从索引删除
        try await indexDB.deleteNoteIndex(id: id)

        // 3. 清除缓存
        await cacheManager.clearAll()
    }

    func deleteBatch(ids: [UUID]) async throws {
        // 并行删除
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    try? await self?.delete(id: id)
                }
            }
        }
    }

    func search(query: String) async throws -> [NoteIndex] {
        // 1. 检查缓存
        if let cached = await cacheManager.getSearchResults(query: query) {
            return cached
        }

        // 2. 执行搜索
        let results = try await indexDB.searchNotes(query: query)

        // 3. 缓存结果
        await cacheManager.cacheSearchResults(query: query, results: results)

        return results
    }

    func list(limit: Int, offset: Int) async throws -> [NoteIndex] {
        // 从索引获取分页数据
        let allIndexes = try await indexDB.getAllNoteIndexes()
        let page = Array(allIndexes.dropFirst(offset).prefix(limit))
        return page
    }

    func getAllIndexes() async throws -> [NoteIndex] {
        let indexes = try await indexDB.getAllNoteIndexes()
        await cacheManager.cacheNoteIndexes(indexes)
        return indexes
    }

    func clear() async throws {
        // 1. 清空分片存储
        try await shardedStorage.clear()

        // 2. 清空索引
        try await indexDB.clearNoteIndexes()

        // 3. 清空缓存
        await cacheManager.clearAll()
    }
}