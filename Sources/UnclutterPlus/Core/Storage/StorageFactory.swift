import Foundation

/// 存储工厂 - 创建和配置存储实例
class StorageFactory {

    /// 创建现代化的笔记存储（使用索引+缓存+分片）
    static func createModernNoteStorage() -> any StorageProtocol {
        let config = StorageConfiguration.default

        do {
            // 创建完整的存储实现
            let storage = try ModernNoteStorage(configuration: config)

            // 包装缓存层（可选，因为 ModernNoteStorage 已内置缓存）
            // let cachedStorage = CachedStorage(storage: storage, cacheManager: CacheManager())

            print("✅ Modern storage initialized successfully")
            print("📁 Storage path: \(config.baseURL.path)")

            return storage
        } catch {
            print("❌ Failed to create modern storage: \(error)")
            print("⚠️ Falling back to temporary storage")

            // 降级到临时存储
            return TemporaryStorage(configuration: config)
        }
    }

    /// 创建剪贴板存储
    static func createClipboardStorage() -> any StorageProtocol {
        let config = StorageConfiguration.default
        let baseURL = config.baseURL.appendingPathComponent("Clipboard")

        // 使用按月分片策略（适合时间序列数据）
        let shardedStorage = ShardedStorage<ClipboardItem>(
            baseURL: baseURL,
            strategy: .byMonth
        )

        // 这里需要适配器包装，因为 ShardedStorage 不直接实现 StorageProtocol
        return ClipboardStorageAdapter(shardedStorage: shardedStorage)
    }

    /// 创建截图存储
    static func createScreenshotStorage() -> any StorageProtocol {
        let config = StorageConfiguration.default
        let baseURL = config.baseURL.appendingPathComponent("Screenshots")

        // 使用按月分片策略
        return ScreenshotStorageAdapter(baseURL: baseURL)
    }
}

// MARK: - Storage Adapters

/// 临时存储实现（用于降级）
class TemporaryStorage: StorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex

    private var notes: [UUID: Note] = [:]

    init(configuration: StorageConfiguration) {
        print("⚠️ Using temporary in-memory storage")
    }

    func create(_ item: Note) async throws {
        notes[item.id] = item
    }

    func read(id: UUID) async throws -> Note? {
        return notes[id]
    }

    func readBatch(ids: [UUID]) async throws -> [Note] {
        return ids.compactMap { notes[$0] }
    }

    func update(_ item: Note) async throws {
        notes[item.id] = item
    }

    func delete(id: UUID) async throws {
        notes.removeValue(forKey: id)
    }

    func deleteBatch(ids: [UUID]) async throws {
        ids.forEach { notes.removeValue(forKey: $0) }
    }

    func search(query: String) async throws -> [NoteIndex] {
        let filtered = notes.values.filter { note in
            note.title.localizedCaseInsensitiveContains(query) ||
            note.content.localizedCaseInsensitiveContains(query)
        }
        return filtered.map { NoteIndex(from: $0) }
    }

    func list(limit: Int, offset: Int) async throws -> [NoteIndex] {
        let allNotes = Array(notes.values)
            .sorted { $0.modifiedAt > $1.modifiedAt }
        let page = Array(allNotes.dropFirst(offset).prefix(limit))
        return page.map { NoteIndex(from: $0) }
    }

    func getAllIndexes() async throws -> [NoteIndex] {
        return notes.values.map { NoteIndex(from: $0) }
    }

    func clear() async throws {
        notes.removeAll()
    }
}

/// 剪贴板存储适配器
class ClipboardStorageAdapter: StorageProtocol {
    typealias Item = ClipboardItem
    typealias Index = ClipboardIndex

    private let shardedStorage: ShardedStorage<ClipboardItem>

    init(shardedStorage: ShardedStorage<ClipboardItem>) {
        self.shardedStorage = shardedStorage
    }

    func create(_ item: ClipboardItem) async throws {
        try await shardedStorage.save(item)
    }

    func read(id: UUID) async throws -> ClipboardItem? {
        return try await shardedStorage.load(id: id)
    }

    func readBatch(ids: [UUID]) async throws -> [ClipboardItem] {
        return try await shardedStorage.loadBatch(ids: ids)
    }

    func update(_ item: ClipboardItem) async throws {
        try await shardedStorage.save(item)
    }

    func delete(id: UUID) async throws {
        try await shardedStorage.delete(id: id)
    }

    func deleteBatch(ids: [UUID]) async throws {
        for id in ids {
            try await shardedStorage.delete(id: id)
        }
    }

    func search(query: String) async throws -> [ClipboardIndex] {
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
        return filtered.map { ClipboardIndex(from: $0) }
    }

    func list(limit: Int, offset: Int) async throws -> [ClipboardIndex] {
        let all = try await shardedStorage.loadAll()
        let sorted = all.sorted { $0.timestamp > $1.timestamp }
        let page = Array(sorted.dropFirst(offset).prefix(limit))
        return page.map { ClipboardIndex(from: $0) }
    }

    func getAllIndexes() async throws -> [ClipboardIndex] {
        let all = try await shardedStorage.loadAll()
        return all.map { ClipboardIndex(from: $0) }
    }

    func clear() async throws {
        try await shardedStorage.clear()
    }
}

/// 截图存储适配器
class ScreenshotStorageAdapter: StorageProtocol {
    typealias Item = ScreenshotItem
    typealias Index = ScreenshotIndex

    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    // 简单的占位实现
    func create(_ item: ScreenshotItem) async throws {}
    func read(id: UUID) async throws -> ScreenshotItem? { nil }
    func readBatch(ids: [UUID]) async throws -> [ScreenshotItem] { [] }
    func update(_ item: ScreenshotItem) async throws {}
    func delete(id: UUID) async throws {}
    func deleteBatch(ids: [UUID]) async throws {}
    func search(query: String) async throws -> [ScreenshotIndex] { [] }
    func list(limit: Int, offset: Int) async throws -> [ScreenshotIndex] { [] }
    func getAllIndexes() async throws -> [ScreenshotIndex] { [] }
    func clear() async throws {}
}

// MARK: - Application Integration

/// 应用级存储管理器（单例）
@MainActor
class AppStorageManager {
    static let shared = AppStorageManager()

    let noteRepository: NoteRepository
    let noteStorage: any StorageProtocol
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
        print("🔧 Starting maintenance tasks...")

        // 1. 压缩数据库
        if let modernStorage = noteStorage as? ModernNoteStorage,
           let indexDB = Mirror(reflecting: modernStorage).descendant("indexDB") as? IndexDatabase {
            await indexDB.vacuum()
        }

        // 2. 清理过期数据
        // TODO: 实现数据过期策略

        // 3. 优化缓存
        // TODO: 根据使用情况调整缓存大小

        print("✅ Maintenance tasks completed")
    }

    /// 获取存储统计信息
    func getStorageStatistics() async -> StorageStatistics {
        var stats = StorageStatistics()

        // 获取笔记数量
        if let modernStorage = noteStorage as? ModernNoteStorage,
           let indexDB = Mirror(reflecting: modernStorage).descendant("indexDB") as? IndexDatabase {
            stats.noteCount = await indexDB.getNoteCount()
        }

        // 计算存储大小
        let storageURL = StorageConfiguration.default.baseURL
        stats.totalSize = calculateDirectorySize(at: storageURL)

        return stats
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
}

/// 存储统计信息
struct StorageStatistics {
    var noteCount: Int = 0
    var clipboardCount: Int = 0
    var screenshotCount: Int = 0
    var totalSize: Int64 = 0

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: totalSize)
    }

    var description: String {
        """
        Storage Statistics:
        - Notes: \(noteCount)
        - Clipboard Items: \(clipboardCount)
        - Screenshots: \(screenshotCount)
        - Total Size: \(formattedSize)
        """
    }
}