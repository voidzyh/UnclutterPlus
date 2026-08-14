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

/// 分片存储实现（actor 并发模型）
///
/// 状态（shardIndex）由 actor 隔离，无需 GCD barrier/锁；
/// 文件 IO 为小 JSON 的短操作，直接在 actor 方法内执行；
/// `loadAll` 的跨分片并行读取通过不捕获 self 的子任务 + 静态解码器保留。
public actor ShardedStorage<Item: Codable & Identifiable> where Item.ID == UUID {
    private let baseURL: URL
    private let strategy: ShardingStrategy
    private let fileManager = FileManager.default

    // 编码器/解码器为静态配置（iso8601），供并行子任务在 actor 外安全使用
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [] // 紧凑格式，节省空间
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // 分片索引（记录每个 ID 对应的分片位置）
    private var shardIndex: [UUID: String] = [:]
    private let indexURL: URL

    // 索引保存防抖动（Task 化，替代 DispatchWorkItem）
    private var saveIndexTask: Task<Void, Never>?
    private let saveIndexDelay: UInt64 = 500_000_000 // 0.5s

    // MARK: - Initialization

    init(baseURL: URL, strategy: ShardingStrategy) {
        self.baseURL = baseURL
        self.strategy = strategy
        self.indexURL = baseURL.appendingPathComponent(".shard_index.json")

        // 创建基础目录
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)

        // 加载分片索引
        loadShardIndex()
    }

    // MARK: - Public Methods

    /// 保存项目（创建或更新）
    public func create(_ item: Item) async throws {
        let shardPath = getShardPath(for: item)

        do {
            let directory = shardPath.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let data = try Self.encoder.encode(item)
            try data.write(to: shardPath, options: .atomic)

            let relativePath = shardPath.path.replacingOccurrences(of: baseURL.path, with: "")
            shardIndex[item.id] = relativePath
            scheduleIndexSave()
        } catch {
            throw StorageError.writeFailed(underlying: error)
        }
    }

    /// 更新项目（与create相同，因为保存操作会覆盖现有数据）
    public func update(_ item: Item) async throws {
        try await create(item)
    }

    /// 批量保存
    public func saveBatch(_ items: [Item]) async throws {
        var errors: [Error] = []

        await withTaskGroup(of: Error?.self) { group in
            for item in items {
                group.addTask { [weak self] in
                    do {
                        try await self?.create(item)
                        return nil
                    } catch {
                        return error
                    }
                }
            }

            for await error in group {
                if let error = error {
                    errors.append(error)
                }
            }
        }

        if !errors.isEmpty {
            logger.error("批量保存错误: \(errors.count) 个失败", category: "Storage")
        }
    }

    /// 读取项目
    public func read(id: UUID) async throws -> Item? {
        if let shardName = shardIndex[id] {
            let shardPath = getShardDirectory(for: shardName).appendingPathComponent("\(id.uuidString).json")
            return try loadFromPath(shardPath)
        }

        // 索引未命中时全目录查找（重建索引）
        if let path = try await findItemPath(id: id) {
            return try loadFromPath(path)
        }
        return nil
    }

    /// 批量读取
    public func readBatch(ids: [UUID]) async throws -> [Item] {
        var items: [Item] = []
        for id in ids {
            if let item = try await read(id: id) {
                items.append(item)
            }
        }
        return items
    }

    /// 删除项目
    public func delete(id: UUID) async throws {
        guard let shardName = shardIndex[id] else {
            throw StorageError.notFound(id)
        }

        let shardPath = getShardDirectory(for: shardName).appendingPathComponent("\(id.uuidString).json")

        do {
            try fileManager.removeItem(at: shardPath)
            shardIndex.removeValue(forKey: id)
            scheduleIndexSave()
        } catch {
            throw StorageError.writeFailed(underlying: error)
        }
    }

    /// 批量删除
    public func deleteBatch(ids: [UUID]) async throws {
        var errors: [Error] = []

        await withTaskGroup(of: Error?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    do {
                        try await self?.delete(id: id)
                        return nil
                    } catch {
                        return error
                    }
                }
            }

            for await error in group {
                if let error = error {
                    errors.append(error)
                }
            }
        }

        if let firstError = errors.first {
            throw firstError
        }
    }

    /// 获取所有项目（跨分片并行 IO，不在 actor 上阻塞）
    public func loadAll() async throws -> [Item] {
        let shardDirs = try fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
            return isDirectory == true && !url.lastPathComponent.hasPrefix(".")
        }

        var items: [Item] = []

        await withTaskGroup(of: [Item].self) { group in
            for shardDir in shardDirs {
                // 子任务不捕获 self：文件列举与解码用本地资源完成，保持并行 IO
                group.addTask {
                    let files = (try? FileManager.default.contentsOfDirectory(
                        at: shardDir,
                        includingPropertiesForKeys: nil
                    ).filter { $0.pathExtension == "json" }) ?? []

                    var shardItems: [Item] = []
                    for file in files {
                        if let data = try? Data(contentsOf: file),
                           let item = try? Self.decoder.decode(Item.self, from: data) {
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
        do {
            // 删除所有分片目录
            let contents = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil
            )

            for item in contents {
                try fileManager.removeItem(at: item)
            }

            // 清空索引
            shardIndex.removeAll()
            saveIndexTask?.cancel()
            performSaveShardIndex()
        } catch {
            throw StorageError.writeFailed(underlying: error)
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

    /// 从路径加载项目（actor 内同步 IO）
    private func loadFromPath(_ path: URL) throws -> Item? {
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        let data = try Data(contentsOf: path)
        return try Self.decoder.decode(Item.self, from: data)
    }

    /// 查找项目路径（索引未命中时）
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
                scheduleIndexSave()
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
            shardIndex = index.compactMapKeys { UUID(uuidString: $0) }
        } catch {
            logger.error("加载分片索引失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 调度分片索引保存（Task 防抖，合并短时间内的多次更新）
    private func scheduleIndexSave() {
        saveIndexTask?.cancel()

        saveIndexTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: saveIndexDelay)
            guard !Task.isCancelled else { return }
            await self?.performSaveShardIndex()
        }
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
