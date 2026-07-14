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
public class ShardedStorage<Item: Codable & Identifiable> where Item.ID == UUID {
    private let baseURL: URL
    private let strategy: ShardingStrategy
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "sharded.storage", attributes: .concurrent)

    // 分片索引（记录每个 ID 对应的分片位置）
    private var shardIndex: [UUID: String] = [:]
    private let indexURL: URL
    
    // 索引保存防抖动
    private var saveIndexWorkItem: DispatchWorkItem?
    private let saveIndexDelay: TimeInterval = 0.5

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

    /// 保存项目（创建或更新）
    public func create(_ item: Item) async throws {
        let shardPath = getShardPath(for: item)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageError.writeFailed(underlying: NSError()))
                    return
                }

                do {
                    let directory = shardPath.deletingLastPathComponent()
                    try self.fileManager.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )

                    let data = try self.encoder.encode(item)
                    try data.write(to: shardPath, options: .atomic)

                    self.queue.async(flags: .barrier) {
                        let relativePath = shardPath.path.replacingOccurrences(of: self.baseURL.path, with: "")
                        self.shardIndex[item.id] = relativePath
                        self.saveShardIndex()
                        continuation.resume()
                    }
                } catch {
                    continuation.resume(throwing: StorageError.writeFailed(underlying: error))
                }
            }
        }
    }

    /// 更新项目（与create相同，因为保存操作会覆盖现有数据）
    public func update(_ item: Item) async throws {
        try await create(item)
    }
    
    /// 批量保存（限制最大并发数为 10，优化内存使用）
    public func saveBatch(_ items: [Item]) async throws {
        let maxConcurrency = 10
        var activeTaskCount = 0

        await withTaskGroup(of: Error?.self) { group in
            for item in items {
                // 限制并发数量
                while activeTaskCount >= maxConcurrency {
                    // 等待至少一个任务完成
                    if let error = await group.next() {
                        if let error = error {
                            logger.error("批量保存单个失败: \(error.localizedDescription)", category: "Storage")
                        }
                        activeTaskCount -= 1
                    }
                }

                group.addTask { [weak self] in
                    do {
                        try await self?.create(item)
                        return nil
                    } catch {
                        return error
                    }
                }
                activeTaskCount += 1
            }

            // 收集剩余任务的错误
            var errors: [Error] = []
            for await error in group {
                if let error = error {
                    errors.append(error)
                }
            }

            if !errors.isEmpty {
                logger.error("批量保存错误: \(errors.count) 个失败", category: "Storage")
            }
        }
    }

    /// 读取项目
    public func read(id: UUID) async throws -> Item? {
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

    /// 批量读取
    public func readBatch(ids: [UUID]) async throws -> [Item] {
        return await withTaskGroup(of: Item?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    try? await self?.read(id: id)
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
    public func delete(id: UUID) async throws {
        guard let shardName = shardIndex[id] else {
            throw StorageError.notFound(id)
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

    /// 批量删除（限制最大并发数为 10，优化内存使用）
    public func deleteBatch(ids: [UUID]) async throws {
        let maxConcurrency = 10
        var activeTaskCount = 0
        var errors: [Error] = []

        await withTaskGroup(of: Result<Void, Error>.self) { group in
            for id in ids {
                // 限制并发数量
                while activeTaskCount >= maxConcurrency {
                    // 等待至少一个任务完成
                    if let result = await group.next() {
                        if case .failure(let error) = result {
                            errors.append(error)
                        }
                    }
                    activeTaskCount -= 1
                }

                group.addTask { [weak self] in
                    do {
                        try await self?.delete(id: id)
                        return .success(())
                    } catch {
                        return .failure(error)
                    }
                }
                activeTaskCount += 1
            }

            // 等待所有剩余任务完成
            for await result in group {
                if case .failure(let error) = result {
                    errors.append(error)
                }
            }
        }

        if let firstError = errors.first {
            throw firstError
        }
    }

    /// 获取所有项目
    public func loadAll() async throws -> [Item] {
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
    
    /// 搜索项目（基础实现 - 加载所有项目并过滤）
    public func search(query: String) async throws -> [Item] {
        let allItems = try await loadAll()
        
        // 简单的文本搜索实现
        return allItems.filter { item in
            // 这里假设Item有某种文本内容可以搜索
            // 实际实现可能需要根据具体的Item类型来调整
            if let note = item as? Note {
                return note.content.localizedCaseInsensitiveContains(query) ||
                       note.title.localizedCaseInsensitiveContains(query)
            }
            return false
        }
    }
    
    /// 获取所有索引（基础实现 - 为每个项目创建索引）
    public func getAllIndexes() async throws -> [NoteIndex] {
        let allItems = try await loadAll()
        return allItems.map { item in
            if let note = item as? Note {
                return NoteIndex(from: note)
            } else {
                // 为其他类型创建基础索引
                return NoteIndex(
                    id: item.id,
                    title: "Item \(item.id)",
                    createdAt: Date(),
                    modifiedAt: Date(),
                    tags: [],
                    wordCount: 0,
                    previewText: "",
                    isFavorited: false
                )
            }
        }
    }

    /// 清空所有数据
    public func clear() async throws {
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

    private func getShardDirectory(for relativePath: String) -> URL {
        let pathComponents = relativePath.split(separator: "/", omittingEmptySubsequences: true)
        if pathComponents.count >= 2 {
            let directoryPath = pathComponents.dropLast().joined(separator: "/")
            return baseURL.appendingPathComponent(directoryPath)
        }
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
            logger.error("加载分片索引失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 保存分片索引（防抖动）
    private func saveShardIndex() {
        // 取消之前的待处理保存
        saveIndexWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performSaveShardIndex()
        }
        
        saveIndexWorkItem = workItem
        // 延迟保存，合并短时间内的多次更新
        queue.asyncAfter(deadline: .now() + saveIndexDelay, execute: workItem)
    }
    
    /// 执行保存分片索引
    private func performSaveShardIndex() {
        do {
            // 转换为字符串索引
            let stringIndex = shardIndex.reduce(into: [String: String]()) { result, pair in
                result[pair.key.uuidString] = pair.value
            }

            let data = try JSONEncoder().encode(stringIndex)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            logger.error("保存分片索引失败: \(error.localizedDescription)", category: "Storage")
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
