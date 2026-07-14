import Foundation

/// 存储工厂 - 创建和配置存储实例
class StorageFactory {

    /// 创建现代化的笔记存储（使用索引+缓存+分片）
    static func createModernNoteStorage() -> any UnifiedStorageProtocol<Note, NoteIndex> {
        let config = StorageConfiguration.default

        // 创建完整的存储实现
        let storage = UnifiedNoteStorage(configuration: config)

        logger.info("现代化存储初始化成功", category: "Storage")
        logger.debug("存储路径: \(config.baseURL.path)", category: "Storage")

        return storage
    }

    /// 创建剪贴板存储
    static func createClipboardStorage() -> any UnifiedStorageProtocol<ClipboardItem, ClipboardIndex> {
        let config = StorageConfiguration.default
        let baseURL = config.baseURL.appendingPathComponent("Clipboard")

        // 使用按月分片策略（适合时间序列数据）
        let shardedStorage = ShardedStorage<ClipboardItem>(
            baseURL: baseURL,
            strategy: .byMonth
        )

        // 这里需要适配器包装，因为 ShardedStorage 不直接实现 UnifiedStorageProtocol
        return ClipboardStorageAdapter(shardedStorage: shardedStorage)
    }

    /// 创建截图存储
    static func createScreenshotStorage() -> any UnifiedStorageProtocol<ScreenshotItem, ScreenshotIndex> {
        let config = StorageConfiguration.default
        let baseURL = config.baseURL.appendingPathComponent("Screenshots")

        // 使用按月分片策略
        return ScreenshotStorageAdapter(baseURL: baseURL)
    }
}

// MARK: - Storage Adapters

/// 临时存储实现（用于降级）
class TemporaryStorage: UnifiedStorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex

    private var notes: [UUID: Note] = [:]

    init(configuration: StorageConfiguration) {
        logger.warning("使用临时内存存储", category: "Storage")
    }

    func create(_ items: [Note]) async throws {
        for item in items {
            notes[item.id] = item
        }
    }

    func read(id: UUID) async throws -> Note? {
        return notes[id]
    }

    func readBatch(ids: [UUID]) async throws -> [Note] {
        return ids.compactMap { notes[$0] }
    }

    func update(_ items: [Note]) async throws {
        for item in items {
            notes[item.id] = item
        }
    }

    func delete(ids: [UUID]) async throws {
        ids.forEach { notes.removeValue(forKey: $0) }
    }

    func search(query: String, limit: Int?) async throws -> [NoteIndex] {
        let filtered = notes.values.filter { note in
            note.title.localizedCaseInsensitiveContains(query) ||
            note.content.localizedCaseInsensitiveContains(query)
        }
        let indexes = filtered.map { NoteIndex(from: $0) }
        
        if let limit = limit {
            return Array(indexes.prefix(limit))
        }
        return indexes
    }

    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [NoteIndex] {
        var allNotes = Array(notes.values)
            .sorted { (note1: Note, note2: Note) -> Bool in
                note1.updatedAt > note2.updatedAt
            }
        
        if let offset = offset {
            allNotes = Array(allNotes.dropFirst(offset))
        }
        if let limit = limit {
            allNotes = Array(allNotes.prefix(limit))
        }
        
        return allNotes.map { NoteIndex(from: $0) }
    }
    
    func filter(by predicate: @escaping (NoteIndex) -> Bool, limit: Int?) async throws -> [NoteIndex] {
        var indexes = try await getAllIndexes(limit: nil, offset: nil)
        indexes = indexes.filter(predicate)
        
        if let limit = limit {
            return Array(indexes.prefix(limit))
        }
        return indexes
    }
    
    func count() async throws -> Int {
        return notes.count
    }

    func clear() async throws {
        notes.removeAll()
    }
    
    func getStatistics() async throws -> StorageStatistics {
        return StorageStatistics(
            totalItems: notes.count,
            totalSize: 0,
            cacheSize: notes.count,
            lastModified: Date(),
            storageType: .simple
        )
    }
}

/// 剪贴板存储适配器
class ClipboardStorageAdapter: UnifiedStorageProtocol {
    typealias Item = ClipboardItem
    typealias Index = ClipboardIndex

    private let shardedStorage: ShardedStorage<ClipboardItem>
    private var isInitialized = false

    init(shardedStorage: ShardedStorage<ClipboardItem>) {
        self.shardedStorage = shardedStorage
        
        // 异步初始化，确保数据可用
        Task {
            await initializeStorage()
        }
    }
    
    /// 初始化存储，确保数据可用
    private func initializeStorage() async {
        do {
            // 尝试加载所有数据，触发存储初始化
            _ = try await shardedStorage.loadAll()
            isInitialized = true
            logger.info("剪贴板存储初始化完成", category: "Storage")
        } catch {
            logger.error("剪贴板存储初始化失败: \(error.localizedDescription)", category: "Storage")
        }
    }
    
    private func waitForInit() async {
        while !isInitialized {
            try? await Task.sleep(nanoseconds: 100_000_000) // 等待100ms
        }
    }

    func create(_ items: [ClipboardItem]) async throws {
        await waitForInit()
        for item in items {
            try await shardedStorage.create(item)
        }
    }

    func read(id: UUID) async throws -> ClipboardItem? {
        await waitForInit()
        return try await shardedStorage.read(id: id)
    }

    func readBatch(ids: [UUID]) async throws -> [ClipboardItem] {
        await waitForInit()
        return try await shardedStorage.readBatch(ids: ids)
    }

    func update(_ items: [ClipboardItem]) async throws {
        await waitForInit()
        for item in items {
            try await shardedStorage.create(item)
        }
    }

    func delete(ids: [UUID]) async throws {
        await waitForInit()
        try await shardedStorage.deleteBatch(ids: ids)
    }

    func search(query: String, limit: Int?) async throws -> [ClipboardIndex] {
        await waitForInit()
        
        // 简单实现：加载所有并过滤
        let all = try await shardedStorage.loadAll()
        let filtered = all.filter { item in
            switch item.content {
            case .text(let text):
                return text.localizedCaseInsensitiveContains(query)
            case .file(let url):
                return url.lastPathComponent.localizedCaseInsensitiveContains(query)
            case .image:
                return false
            }
        }
        let indexes = filtered.map { ClipboardIndex(from: $0) }
        
        if let limit = limit {
            return Array(indexes.prefix(limit))
        }
        return indexes
    }

    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [ClipboardIndex] {
        await waitForInit()
        
        let all = try await shardedStorage.loadAll()
        var sorted = all.sorted { $0.timestamp > $1.timestamp }
        
        if let offset = offset {
            sorted = Array(sorted.dropFirst(offset))
        }
        if let limit = limit {
            sorted = Array(sorted.prefix(limit))
        }
        
        return sorted.map { ClipboardIndex(from: $0) }
    }
    
    func filter(by predicate: @escaping (ClipboardIndex) -> Bool, limit: Int?) async throws -> [ClipboardIndex] {
        var indexes = try await getAllIndexes(limit: nil, offset: nil)
        indexes = indexes.filter(predicate)
        
        if let limit = limit {
            return Array(indexes.prefix(limit))
        }
        return indexes
    }
    
    func count() async throws -> Int {
        await waitForInit()
        let all = try await shardedStorage.loadAll()
        return all.count
    }

    func clear() async throws {
        await waitForInit()
        try await shardedStorage.clear()
    }
    
    func getStatistics() async throws -> StorageStatistics {
        let count = try await self.count()
        return StorageStatistics(
            totalItems: count,
            totalSize: 0,
            cacheSize: 0,
            lastModified: Date(),
            storageType: .sharded
        )
    }
}

/// 截图存储适配器
class ScreenshotStorageAdapter: UnifiedStorageProtocol {
    typealias Item = ScreenshotItem
    typealias Index = ScreenshotIndex

    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    // 简单的占位实现
    func create(_ items: [ScreenshotItem]) async throws {}
    func read(id: UUID) async throws -> ScreenshotItem? { nil }
    func readBatch(ids: [UUID]) async throws -> [ScreenshotItem] { [] }
    func update(_ items: [ScreenshotItem]) async throws {}
    func delete(ids: [UUID]) async throws {}
    func search(query: String, limit: Int?) async throws -> [ScreenshotIndex] { [] }
    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [ScreenshotIndex] { [] }
    func filter(by predicate: @escaping (ScreenshotIndex) -> Bool, limit: Int?) async throws -> [ScreenshotIndex] { [] }
    func count() async throws -> Int { 0 }
    func clear() async throws {}
    func getStatistics() async throws -> StorageStatistics {
        return StorageStatistics(
            totalItems: 0,
            totalSize: 0,
            cacheSize: 0,
            lastModified: Date(),
            storageType: .simple
        )
    }
}

// MARK: - Application Integration

/// 应用级存储管理器（单例）
@MainActor
class AppStorageManager {
    static let shared = AppStorageManager()

    let noteRepository: NoteRepository
    let noteStorage: any UnifiedStorageProtocol<Note, NoteIndex>
    let clipboardRepository: ClipboardRepository

    private init() {
        // 创建存储
        self.noteStorage = StorageFactory.createModernNoteStorage()

        // 创建 Repository（已包含存储逻辑）
        self.noteRepository = NoteRepository()
        self.clipboardRepository = ClipboardRepository()

        // 启动维护任务
        Task {
            await startMaintenanceTasks()
        }
    }

    /// 启动定期维护任务
    private func startMaintenanceTasks() async {
        // 每小时执行一次维护
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.performMaintenance()
            }
        }
    }

    /// 执行维护任务
    private func performMaintenance() async {
        logger.info("开始维护任务", category: "Storage")

        // 1. 压缩数据库
        if let modernStorage = noteStorage as? UnifiedNoteStorage,
           let indexDB = Mirror(reflecting: modernStorage).descendant("indexDB") as? IndexDatabase {
            await indexDB.vacuum()
        }

        // 2. 清理过期数据
        await cleanupExpiredData()

        // 3. 优化缓存
        await optimizeCache()

        logger.info("维护任务完成", category: "Storage")
    }

    /// 获取存储统计信息
    func getStorageStatistics() async -> StorageStatistics {
        // 简化版本，直接返回默认统计
        return StorageStatistics(
            totalItems: 0,
            totalSize: 0,
            cacheSize: 0,
            lastModified: Date(),
            storageType: .modern
        )
    }

    private func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }

        return size
    }

    /// 清理过期数据
    private func cleanupExpiredData() async {
        logger.info("开始清理过期数据", category: "Storage")

        // 清理超过 30 天的临时文件和缓存
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        // 获取临时目录
        let tempURL = FileManager.default.temporaryDirectory

        if let enumerator = FileManager.default.enumerator(at: tempURL, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]) {
            var totalSizeCleaned: Int64 = 0
            var filesDeleted: Int = 0

            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                      let creationDate = resourceValues.creationDate,
                      creationDate < cutoffDate else {
                    continue
                }

                // 删除过期文件
                try? FileManager.default.removeItem(at: fileURL)

                if let fileSize = resourceValues.fileSize {
                    totalSizeCleaned += Int64(fileSize)
                }
                filesDeleted += 1
            }

            if filesDeleted > 0 {
                logger.info(
                    "清理过期文件完成: \(filesDeleted) 个文件，释放空间 \(ByteCountFormatter.string(fromByteCount: totalSizeCleaned, countStyle: .file))",
                    category: "Storage"
                )
            } else {
                logger.debug("没有找到需要清理的过期文件", category: "Storage")
            }
        }

        // 清理应用的缓存目录
        if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let appCacheURL = cachesURL.appendingPathComponent("UnclutterPlus")

            if FileManager.default.fileExists(atPath: appCacheURL.path) {
                let cacheContents = try? FileManager.default.contentsOfDirectory(
                    at: appCacheURL,
                    includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
                )

                if let cacheContents = cacheContents {
                    let expiredCacheFiles = cacheContents.filter { url -> Bool in
                        guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey]),
                              let creationDate = resourceValues.creationDate else {
                            return false
                        }
                        return creationDate < cutoffDate
                    }

                    for fileURL in expiredCacheFiles {
                        try? FileManager.default.removeItem(at: fileURL)
                    }

                    if !expiredCacheFiles.isEmpty {
                        logger.info("清理了 \(expiredCacheFiles.count) 个过期缓存文件", category: "Storage")
                    }
                }
            }
        }

        logger.info("过期数据清理完成", category: "Storage")
    }

    /// 优化缓存
    private func optimizeCache() async {
        logger.info("开始优化缓存", category: "Storage")

        // 获取缓存统计信息
        let stats = GlobalCacheManager.shared.getCacheStatistics()

        // 根据命中率动态调整缓存大小
        GlobalCacheManager.shared.optimizeBasedOnHitRate()

        // 记录优化结果
        logger.info(
            "缓存优化完成 - 命中率: \(String(format: "%.1f%%", stats.hitRate * 100))，条目数: \(stats.entryCount)",
            category: "Storage"
        )
    }
}