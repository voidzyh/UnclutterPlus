import Foundation
import SwiftUI
import Combine

// MARK: - Optimized Temp File Manager
// 优化版本：异步操作 + 智能缓存 + 后台处理 + 批量操作

/// 文件操作协议
protocol FileOperationProtocol {
    func addFile(from url: URL) async throws -> TempFile
    func removeFile(_ file: TempFile) async throws
    func renameFile(_ file: TempFile, to newName: String) async throws -> TempFile
    func openFile(_ file: TempFile) async throws
}

/// 文件缓存协议
protocol FileCacheProtocol {
    func get(_ id: UUID) -> TempFile?
    func set(_ file: TempFile)
    func remove(_ id: UUID)
    func clear()
    func getAll() -> [TempFile]
}

/// 文件元数据管理器
protocol FileMetadataManagerProtocol {
    func save(_ metadata: FileMetadata, for file: TempFile) async throws
    func load(for file: TempFile) async throws -> FileMetadata?
    func delete(for file: TempFile) async throws
}

/// 优化的临时文件管理器
@MainActor
class OptimizedTempFileManager: ObservableObject {
    // MARK: - Published Properties

    @Published var files: [TempFile] = []
    @Published var selectedFiles: Set<UUID> = []
    @Published var isLoading: Bool = false
    @Published var sortOption: SortOption = .dateAdded
    @Published var isAscending: Bool = false

    // MARK: - Properties

    private let config = ConfigurationManager.shared
    private let fileCache: FileCacheProtocol
    private let metadataManager: FileMetadataManagerProtocol
    private let batchProcessor: BatchFileProcessor
    private var fileOperations: [UUID: FileOperation] = [:]

    // 性能优化
    private var fileObservers: [AnyCancellable] = []
    private let debounceInterval: TimeInterval = 0.5
    private var updateTimer: Timer?

    // MARK: - Initialization

    init(
        fileCache: FileCacheProtocol = FileCache(),
        metadataManager: FileMetadataManagerProtocol = FileMetadataManager()
    ) {
        self.fileCache = fileCache
        self.metadataManager = metadataManager
        self.batchProcessor = BatchFileProcessor()

        setupFileWatching()
        loadFilesAsync()
    }

    deinit {
        fileObservers.forEach { $0.cancel() }
        updateTimer?.invalidate()
    }

    // MARK: - Public Methods

    func addFile(from sourceURL: URL) async throws {
        isLoading = true
        defer { isLoading = false }

        let operation = FileOperation.add(sourceURL: sourceURL)
        fileOperations[operation.id] = operation

        do {
            let tempFile = try await executeOperation(operation)
            files.insert(tempFile, at: 0)
            fileCache.set(tempFile)
            batchProcessor.scheduleSave()
            notifyFileChanged(.added(tempFile))

        } catch {
            print("Error adding file: \(error)")
            throw error
        }
    }

    func removeFile(_ file: TempFile) async throws {
        let operation = FileOperation.remove(file: file)
        fileOperations[operation.id] = operation

        do {
            try await executeOperation(operation)
            files.removeAll { $0.id == file.id }
            selectedFiles.remove(file.id)
            fileCache.remove(file.id)
            batchProcessor.scheduleSave()
            notifyFileChanged(.removed(file))

        } catch {
            print("Error removing file: \(error)")
            throw error
        }
    }

    func removeFiles(_ filesToRemove: [TempFile]) async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            for file in filesToRemove {
                group.addTask {
                    try await self.removeFile(file)
                }
            }
        }
    }

    func renameFile(_ file: TempFile, to newName: String) async throws -> TempFile {
        let operation = FileOperation.rename(file: file, newName: newName)
        fileOperations[operation.id] = operation

        let updatedFile = try await executeOperation(operation)

        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = updatedFile
            fileCache.set(updatedFile)
            batchProcessor.scheduleSave()
            notifyFileChanged(.updated(updatedFile))
        }

        return updatedFile
    }

    func toggleFavorite(_ file: TempFile) async throws {
        var updatedFile = file
        updatedFile.isFavorite.toggle()

        let metadata = FileMetadata(
            id: updatedFile.id,
            tags: updatedFile.tags,
            isFavorite: updatedFile.isFavorite,
            lastAccessed: Date()
        )

        try await metadataManager.save(metadata, for: updatedFile)

        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = updatedFile
            fileCache.set(updatedFile)
            sortFiles()
            batchProcessor.scheduleSave()
        }
    }

    func openFile(_ file: TempFile) async throws {
        let operation = FileOperation.open(file: file)
        fileOperations[operation.id] = operation

        try await executeOperation(operation)

        // 更新访问时间
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].lastAccessed = Date()
            fileCache.set(files[index])
            batchProcessor.scheduleSave()
        }

        // 触发自动隐藏
        WindowManager.shared.hideWindowAfterAction(.fileOpened)
    }

    func addTag(_ tag: String, to file: TempFile) async throws {
        var updatedFile = file
        updatedFile.tags.insert(tag)

        let metadata = FileMetadata(
            id: updatedFile.id,
            tags: updatedFile.tags,
            isFavorite: updatedFile.isFavorite,
            lastAccessed: updatedFile.lastAccessed
        )

        try await metadataManager.save(metadata, for: updatedFile)

        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = updatedFile
            fileCache.set(updatedFile)
            batchProcessor.scheduleSave()
        }
    }

    func removeTag(_ tag: String, from file: TempFile) async throws {
        var updatedFile = file
        updatedFile.tags.remove(tag)

        let metadata = FileMetadata(
            id: updatedFile.id,
            tags: updatedFile.tags,
            isFavorite: updatedFile.isFavorite,
            lastAccessed: updatedFile.lastAccessed
        )

        try await metadataManager.save(metadata, for: updatedFile)

        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = updatedFile
            fileCache.set(updatedFile)
            batchProcessor.scheduleSave()
        }
    }

    func toggleSelection(_ file: TempFile) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
        } else {
            selectedFiles.insert(file.id)
        }
    }

    func selectAll() {
        selectedFiles = Set(sortedFiles.map { $0.id })
    }

    func deselectAll() {
        selectedFiles.removeAll()
    }

    var sortedFiles: [TempFile] {
        let sorted = files.sorted { first, second in
            // 收藏的文件总是在前面
            if first.isFavorite && !second.isFavorite {
                return true
            } else if !first.isFavorite && second.isFavorite {
                return false
            }

            let result: Bool
            switch sortOption {
            case .name:
                result = first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            case .dateAdded:
                result = first.dateAdded < second.dateAdded
            case .size:
                result = first.size < second.size
            case .type:
                result = first.fileType.rawValue.localizedCaseInsensitiveCompare(second.fileType.rawValue) == .orderedAscending
            case .lastAccessed:
                result = first.lastAccessed < second.lastAccessed
            }

            return isAscending ? result : !result
        }

        return sorted
    }

    var filesByType: [FileType: [TempFile]] {
        Dictionary(grouping: sortedFiles) { $0.fileType }
    }

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    func clearAllFiles() async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            for file in files {
                group.addTask {
                    try await self.removeFile(file)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func setupFileWatching() {
        // 监听配置变化
        config.$filesStoragePath
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadFilesAsync()
                }
            }
            .store(in: &fileObservers)
    }

    private func loadFilesAsync() {
        Task {
            let loadedFiles = await FileLoader.loadFiles(from: config.filesStoragePath)
            await MainActor.run {
                self.files = loadedFiles

                // 预热缓存
                for file in loadedFiles {
                    self.fileCache.set(file)
                }

                self.sortFiles()
            }
        }
    }

    private func executeOperation<T>(_ operation: FileOperation) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let responseTime = (endTime - startTime) * 1000
            PerformanceMonitor.shared.recordOperation(responseTime: responseTime)
        }

        return try await operation.execute()
    }

    private func sortFiles() {
        files = sortedFiles
    }

    private func notifyFileChanged(_ change: FileChange) {
        // 发送文件变化通知
        NotificationCenter.default.post(name: .fileManagerDidChange, object: change)
    }
}

// MARK: - Supporting Types

enum FileOperation {
    case add(sourceURL: URL)
    case remove(file: TempFile)
    case rename(file: TempFile, newName: String)
    case open(file: TempFile)

    var id: UUID {
        switch self {
        case .add(let url):
            return UUID()
        case .remove(let file):
            return file.id
        case .rename(let file, _):
            return file.id
        case .open(let file):
            return file.id
        }
    }

    func execute() async throws -> TempFile {
        switch self {
        case .add(let sourceURL):
            return try await FileOperationExecutor.addFile(from: sourceURL)
        case .remove(let file):
            try await FileOperationExecutor.removeFile(file)
            return file
        case .rename(let file, let newName):
            return try await FileOperationExecutor.renameFile(file, to: newName)
        case .open(let file):
            try await FileOperationExecutor.openFile(file)
            return file
        }
    }
}

enum FileChange {
    case added(TempFile)
    case removed(TempFile)
    case updated(TempFile)
}

// MARK: - File Cache

class FileCache: FileCacheProtocol {
    private let cache = NSCache<NSUUID, TempFile>()
    private let accessTimes = NSCache<NSUUID, NSDate>()

    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func get(_ id: UUID) -> TempFile? {
        accessTimes.setObject(NSDate(), forKey: id as NSUUID)
        return cache.object(forKey: id as NSUUID)
    }

    func set(_ file: TempFile) {
        cache.setObject(file, forKey: file.id as NSUUID)
        accessTimes.setObject(NSDate(), forKey: file.id as NSUUID)
    }

    func remove(_ id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
        accessTimes.removeObject(forKey: id as NSUUID)
    }

    func clear() {
        cache.removeAllObjects()
        accessTimes.removeAllObjects()
    }

    func getAll() -> [TempFile] {
        return cache.allObjects
    }

    func evictOld() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-300) // 5分钟

        for key in accessTimes.allKeys {
            if let accessTime = accessTimes.object(forKey: key) as Date?,
               accessTime < cutoff {
                accessTimes.removeObject(forKey: key)
                cache.removeObject(forKey: key as NSUUID)
            }
        }
    }
}

// MARK: - Batch Processor

class BatchFileProcessor {
    private var pendingSave = false
    private let saveInterval: TimeInterval = 3.0

    func scheduleSave() {
        pendingSave = true

        DispatchQueue.main.asyncAfter(deadline: .now() + saveInterval) { [weak self] in
            self?.flush()
        }
    }

    private func flush() {
        guard pendingSave else { return }
        pendingSave = false

        Task {
            await PersistenceManager.saveFileMetadata()
        }
    }
}

// MARK: - File Loader

enum FileLoader {
    static func loadFiles(from directory: URL) async -> [TempFile] {
        await withCheckedContinuation { continuation in
            Task.detached {
                let files = self.loadFilesSync(from: directory)
                continuation.resume(returning: files)
            }
        }
    }

    private static func loadFilesSync(from directory: URL) -> [TempFile] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )

            var tempFiles: [TempFile] = []

            for url in fileURLs {
                let tempFile = await createTempFile(from: url)
                tempFiles.append(tempFile)
            }

            return tempFiles

        } catch {
            print("Error loading files: \(error)")
            return []
        }
    }

    private static func createTempFile(from url: URL) async -> TempFile {
        await withCheckedContinuation { continuation in
            Task.detached {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let size = attributes[.size] as? Int64 ?? 0
                    let dateAdded = attributes[.creationDate] as? Date ?? Date()

                    let tempFile = TempFile(
                        url: url,
                        name: url.lastPathComponent,
                        size: size,
                        dateAdded: dateAdded,
                        lastAccessed: dateAdded
                    )

                    continuation.resume(returning: tempFile)

                } catch {
                    print("Error creating temp file: \(error)")
                    continuation.resume(returning: TempFile(
                        url: url,
                        name: url.lastPathComponent,
                        size: 0,
                        dateAdded: Date(),
                        lastAccessed: Date()
                    ))
                }
            }
        }
    }
}

// MARK: - File Operation Executor

enum FileOperationExecutor {
    static func addFile(from sourceURL: URL) async throws -> TempFile {
        let tempDirectory = ConfigurationManager.shared.filesStoragePath
        let fileName = sourceURL.lastPathComponent
        let destinationURL = tempDirectory.appendingPathComponent(fileName)

        // 生成唯一URL
        let finalURL = await generateUniqueURL(for: destinationURL)

        // 复制文件
        try await copyFileAsync(from: sourceURL, to: finalURL)

        // 创建TempFile对象
        let attributes = try FileManager.default.attributesOfItem(atPath: finalURL.path)
        let size = attributes[.size] as? Int64 ?? 0
        let now = Date()

        return TempFile(
            url: finalURL,
            name: finalURL.lastPathComponent,
            size: size,
            dateAdded: now,
            lastAccessed: now
        )
    }

    static func removeFile(_ file: TempFile) async throws {
        try await removeFileAsync(at: file.url)

        // 删除元数据
        let metadataURL = ConfigurationManager.shared.filesStoragePath
            .appendingPathComponent("Metadata")
            .appendingPathComponent("\(file.id.uuidString).json")

        try await removeFileAsync(at: metadataURL)
    }

    static func renameFile(_ file: TempFile, to newName: String) async throws -> TempFile {
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(newName)

        try await moveFileAsync(from: file.url, to: newURL)

        return TempFile(
            id: file.id,
            url: newURL,
            name: newName,
            size: file.size,
            dateAdded: file.dateAdded,
            lastAccessed: file.lastAccessed,
            tags: file.tags,
            isFavorite: file.isFavorite
        )
    }

    static func openFile(_ file: TempFile) async throws {
        try await openFileAsync(at: file.url)
    }

    // MARK: - Async File Operations

    private static func copyFileAsync(from sourceURL: URL, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func removeFileAsync(at url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    try FileManager.default.removeItem(at: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func moveFileAsync(from sourceURL: URL, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func openFileAsync(at url: URL) async throws {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
                continuation.resume()
            }
        }
    }

    private static func generateUniqueURL(for url: URL) async -> URL {
        await withCheckedContinuation { continuation in
            Task.detached {
                var counter = 1
                var uniqueURL = url

                while FileManager.default.fileExists(atPath: uniqueURL.path) {
                    let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
                    let pathExtension = url.pathExtension
                    let directory = url.deletingLastPathComponent()

                    let newName = pathExtension.isEmpty
                        ? "\(nameWithoutExtension) \(counter)"
                        : "\(nameWithoutExtension) \(counter).\(pathExtension)"

                    uniqueURL = directory.appendingPathComponent(newName)
                    counter += 1
                }

                continuation.resume(returning: uniqueURL)
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let fileManagerDidChange = Notification.Name("FileManagerDidChange")
}

// MARK: - Publisher Extensions

extension Publishers {
    struct Debounce<Upstream: Publisher>: Publisher where Upstream.Failure == Never {
        typealias Output = Upstream.Output
        typealias Failure = Never

        private let upstream: Upstream
        private let dueTime: TimeInterval
        private let scheduler: Scheduler

        init(upstream: Upstream, dueTime: TimeInterval, scheduler: Scheduler) {
            self.upstream = upstream
            self.dueTime = dueTime
            self.scheduler = scheduler
        }

        func receive<S>(subscriber: S) where S: Subscriber, S.Input == Output, S.Failure == Failure {
            upstream
                .debounce(for: .seconds(dueTime), scheduler: scheduler)
                .receive(subscriber: subscriber)
        }
    }
}
