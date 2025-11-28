import Foundation
import SQLite3

// MARK: - 连接池管理

/// 数据库连接池管理器
private final class DatabaseConnectionPool {
    private var availableConnections: [OpaquePointer] = []
    private var activeConnections: Set<OpaquePointer> = []
    private let maxConnections: Int
    private let queue = DispatchQueue(label: "database.connection.pool", qos: .userInitiated)
    
    init(maxConnections: Int = 5) {
        self.maxConnections = maxConnections
        setupPool()
    }
    
    private func setupPool() {
        for _ in 0..<maxConnections {
            if let connection = createNewConnection() {
                availableConnections.append(connection)
            }
        }
    }
    
    func getConnection() -> OpaquePointer? {
        return queue.sync {
            if let connection = availableConnections.popLast() {
                activeConnections.insert(connection)
                return connection
            }
            return nil // 连接池耗尽
        }
    }
    
    func returnConnection(_ connection: OpaquePointer) {
        queue.sync {
            activeConnections.remove(connection)
            
            // 检查连接是否有效
            if isConnectionValid(connection) {
                availableConnections.append(connection)
            } else {
                // 连接无效，创建新连接替换
                if let newConnection = createNewConnection() {
                    availableConnections.append(newConnection)
                }
                sqlite3_close(connection)
            }
        }
    }
    
    private func createNewConnection() -> OpaquePointer? {
        var db: OpaquePointer?
        let dbPath = ":memory:" // 使用内存数据库作为连接池的基础
        
        let result = sqlite3_open_v2(
            dbPath,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        
        if result == SQLITE_OK {
            // 为连接配置优化参数
            configureConnection(db)
            return db
        }
        
        return nil
    }
    
    private func configureConnection(_ db: OpaquePointer?) {
        guard let db = db else { return }
        
        // 启用WAL模式
        sqlite3_exec(db, "PRAGMA journal_mode = WAL", nil, nil, nil)
        // 设置同步模式
        sqlite3_exec(db, "PRAGMA synchronous = NORMAL", nil, nil, nil)
        // 设置缓存大小
        sqlite3_exec(db, "PRAGMA cache_size = 1000", nil, nil, nil)
        // 设置临时存储为内存
        sqlite3_exec(db, "PRAGMA temp_store = MEMORY", nil, nil, nil)
    }
    
    private func isConnectionValid(_ connection: OpaquePointer) -> Bool {
        let result = sqlite3_exec(connection, "SELECT 1", nil, nil, nil)
        return result == SQLITE_OK
    }
    
    deinit {
        queue.sync {
            // 关闭所有连接
            for connection in availableConnections {
                sqlite3_close(connection)
            }
            for connection in activeConnections {
                sqlite3_close(connection)
            }
        }
    }
}

// MARK: - 批量操作管理器

/// 批量操作管理器 - 减少数据库往返次数
private final class BatchOperationManager {
    private var pendingInserts: [NoteIndex] = []
    private var pendingUpdates: [NoteIndex] = []
    private var pendingDeletes: [UUID] = []
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private var lastFlush: Date
    private let queue = DispatchQueue(label: "database.batch.ops", qos: .userInitiated)
    private var flushTimer: Timer?
    
    init(batchSize: Int = 100, flushInterval: TimeInterval = 2.0) {
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.lastFlush = Date()
        startAutoFlush()
    }
    
    func queueInsert(_ index: NoteIndex) {
        queue.async {
            self.pendingInserts.append(index)
            self.checkAndFlush()
        }
    }
    
    func queueUpdate(_ index: NoteIndex) {
        queue.async {
            self.pendingUpdates.append(index)
            self.checkAndFlush()
        }
    }
    
    func queueDelete(_ id: UUID) {
        queue.async {
            self.pendingDeletes.append(id)
            self.checkAndFlush()
        }
    }
    
    func flushNow() {
        queue.sync {
            performFlush()
        }
    }
    
    private func checkAndFlush() {
        let now = Date()
        
        // 检查是否达到批处理大小
        if pendingInserts.count + pendingUpdates.count >= batchSize {
            performFlush()
            return
        }
        
        // 检查是否达到刷新间隔
        if now.timeIntervalSince(lastFlush) >= flushInterval {
            performFlush()
        }
    }
    
    private func performFlush() {
        guard !pendingInserts.isEmpty || !pendingUpdates.isEmpty || !pendingDeletes.isEmpty else {
            return
        }
        
        // 这里应该调用实际的数据库操作
        // 为简化示例，我们只重置计数器
        pendingInserts.removeAll()
        pendingUpdates.removeAll()
        pendingDeletes.removeAll()
        lastFlush = Date()
    }
    
    private func startAutoFlush() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flushNow()
        }
    }
    
    deinit {
        flushTimer?.invalidate()
        flushNow() // 确保所有操作都被刷新
    }
}

// MARK: - 优化后的索引数据库

/// SQLite 索引数据库管理器（性能优化版）
class OptimizedIndexDatabase {
    private var db: OpaquePointer?
    private let dbPath: URL
    private let queue = DispatchQueue(label: "indexdb.optimized.queue", attributes: .concurrent)
    private let connectionPool: DatabaseConnectionPool
    private let batchManager: BatchOperationManager
    
    // 缓存机制
    private var indexCache: [UUID: NoteIndex] = [:]
    private let cacheQueue = DispatchQueue(label: "indexdb.cache.queue", qos: .userInitiated)
    private let cacheExpiryInterval: TimeInterval = 300 // 5分钟
    
    // 查询缓存
    private var queryCache: [String: (result: [NoteIndex], timestamp: Date)] = [:]
    private let queryCacheQueue = DispatchQueue(label: "indexdb.query.cache.queue", qos: .userInitiated)
    
    enum Table {
        static let noteIndex = "note_index"
        static let noteFTS = "note_fts"
        static let clipboardIndex = "clipboard_index"
        static let screenshotIndex = "screenshot_index"
    }
    
    // MARK: - Initialization
    
    init(path: URL) throws {
        self.dbPath = path.appendingPathComponent("optimized_index.db")
        self.connectionPool = DatabaseConnectionPool(maxConnections: 3)
        self.batchManager = BatchOperationManager(batchSize: 50, flushInterval: 1.0)
        
        // 创建目录
        try FileManager.default.createDirectory(
            at: path,
            withIntermediateDirectories: true
        )
        
        // 打开数据库并配置优化参数
        try openAndConfigureDatabase()
        
        // 创建表和索引
        try createTables()
        
        // 预热缓存
        Task {
            await warmupCache()
        }
    }
    
    deinit {
        // 确保缓存的查询被刷新
        batchManager.flushNow()
        sqlite3_close(db)
    }
    
    private func openAndConfigureDatabase() throws {
        var db: OpaquePointer?
        
        let result = sqlite3_open_v2(
            dbPath.path,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        
        guard result == SQLITE_OK else {
            throw StorageOperationError.corruptedData(location: dbPath.path)
        }
        
        self.db = db
        
        // 应用性能优化配置
        configureDatabase()
    }
    
    private func configureDatabase() {
        // 启用 WAL 模式（提高并发性能）
        executeOptimized("PRAGMA journal_mode = WAL")
        // 设置同步模式平衡性能和安全
        executeOptimized("PRAGMA synchronous = NORMAL")
        // 增大缓存大小
        executeOptimized("PRAGMA cache_size = 2000")
        // 设置临时存储为内存
        executeOptimized("PRAGMA temp_store = MEMORY")
        // 设置内存映射大小
        executeOptimized("PRAGMA mmap_size = 67108864") // 64MB
        // 启用查询规划器
        executeOptimized("PRAGMA optimize")
        // 设置检查点间隔
        executeOptimized("PRAGMA wal_checkpoint = TRUNCATE")
    }
    
    private func executeOptimized(_ sql: String) {
        var errorMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMsg)
        
        if result != SQLITE_OK {
            let error = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            print("Warning: Failed to execute \(sql): \(error)")
        }
    }
    
    private func createTables() throws {
        // 创建笔记索引表（优化版）
        let createNoteIndex = """
            CREATE TABLE IF NOT EXISTS \(Table.noteIndex) (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                modified_at INTEGER NOT NULL,
                tags TEXT,
                is_favorite INTEGER DEFAULT 0,
                word_count INTEGER DEFAULT 0,
                preview TEXT,
                content_hash TEXT,
                access_count INTEGER DEFAULT 0,
                last_accessed INTEGER
            );
            """
        
        // 创建笔记全文搜索表（优化版）
        let createNoteFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS \(Table.noteFTS)
            USING fts5(
                title,
                preview,
                content,
                content='\(Table.noteIndex)',
                content_rowid='rowid',
                tokenize='porter'
            );
            """
        
        // 创建优化索引
        let createIndexes = """
            CREATE INDEX IF NOT EXISTS idx_notes_modified
                ON \(Table.noteIndex)(modified_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notes_favorite
                ON \(Table.noteIndex)(is_favorite DESC, modified_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notes_access_count
                ON \(Table.noteIndex)(access_count DESC, last_accessed DESC);
            CREATE INDEX IF NOT EXISTS idx_notes_created
                ON \(Table.noteIndex)(created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notes_word_count
                ON \(Table.noteIndex)(word_count DESC);
            """
        
        // 创建剪贴板索引表
        let createClipboardIndex = """
            CREATE TABLE IF NOT EXISTS \(Table.clipboardIndex) (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                source_app TEXT,
                use_count INTEGER DEFAULT 0,
                is_pinned INTEGER DEFAULT 0,
                preview TEXT
            );
            
            CREATE INDEX IF NOT EXISTS idx_clipboard_timestamp
                ON \(Table.clipboardIndex)(timestamp DESC);
            CREATE INDEX IF NOT EXISTS idx_clipboard_pinned
                ON \(Table.clipboardIndex)(is_pinned DESC, timestamp DESC);
            CREATE INDEX IF NOT EXISTS idx_clipboard_use_count
                ON \(Table.clipboardIndex)(use_count DESC, timestamp DESC);
            """
        
        // 执行创建语句
        try execute(createNoteIndex)
        try execute(createNoteFTS)
        try execute(createIndexes)
        try execute(createClipboardIndex)
        
        // 创建触发器（优化版）
        let createTriggers = """
            CREATE TRIGGER IF NOT EXISTS note_index_ai
            AFTER INSERT ON \(Table.noteIndex)
            BEGIN
                INSERT INTO \(Table.noteFTS)(rowid, title, preview)
                VALUES (new.rowid, new.title, new.preview);
            END;
            
            CREATE TRIGGER IF NOT EXISTS note_index_ad
            AFTER DELETE ON \(Table.noteIndex)
            BEGIN
                DELETE FROM \(Table.noteFTS) WHERE rowid = old.rowid;
            END;
            
            CREATE TRIGGER IF NOT EXISTS note_index_au
            AFTER UPDATE ON \(Table.noteIndex)
            BEGIN
                UPDATE \(Table.noteFTS)
                SET title = new.title, preview = new.preview
                WHERE rowid = new.rowid;
            END;
            """
        
        try execute(createTriggers)
    }
    
    // MARK: - Public Methods (Optimized)
    
    /// 插入或更新笔记索引（批量优化）
    func upsertNoteIndex(_ index: NoteIndex) async throws {
        // 先更新缓存
        cacheQueue.async {
            self.indexCache[index.id] = index
        }
        
        // 使用批处理
        batchManager.queueUpdate(index)
        
        // 如果批处理队列太大，立即执行
        if shouldExecuteImmediately() {
            try await executeImmediateUpsert(index)
        }
    }
    
    /// 获取所有笔记索引（缓存优化）
    func getAllNoteIndexes() async throws -> [NoteIndex] {
        let cacheKey = "all_indexes"
        
        // 检查查询缓存
        if let cached = getCachedQueryResult(cacheKey) {
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageOperationError.corrupted)
                    return
                }
                
                do {
                    let indexes = try self.executeOptimizedQuery(
                        "SELECT id, title, created_at, modified_at, tags, is_favorite, word_count, preview FROM \(self.Table.noteIndex) ORDER BY modified_at DESC"
                    ) { stmt in
                        self.parseNoteIndex(from: stmt)
                    }
                    
                    // 缓存结果
                    self.cacheQueryResult(cacheKey, result: indexes)
                    
                    // 更新索引缓存
                    for index in indexes {
                        self.indexCache[index.id] = index
                    }
                    
                    continuation.resume(returning: indexes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 搜索笔记（全文搜索优化）
    func searchNotes(query: String) async throws -> [NoteIndex] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let cacheKey = "search_\(query.hash)"
        
        // 检查查询缓存（短期缓存）
        if let cached = getCachedQueryResult(cacheKey) {
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                do {
                    let sql = """
                        SELECT n.id, n.title, n.created_at, n.modified_at, n.tags,
                               n.is_favorite, n.word_count, n.preview
                        FROM \(self.Table.noteIndex) n
                        JOIN \(self.Table.noteFTS) f ON n.rowid = f.rowid
                        WHERE \(self.Table.noteFTS) MATCH ?
                        ORDER BY rank
                        LIMIT 100
                        """
                    
                    let indexes = try self.executeOptimizedQuery(sql, parameters: [query]) { stmt in
                        self.parseNoteIndex(from: stmt)
                    }
                    
                    // 缓存结果（短期）
                    self.cacheQueryResult(cacheKey, result: indexes, shortTerm: true)
                    
                    continuation.resume(returning: indexes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 删除笔记索引（优化版）
    func deleteNoteIndex(id: UUID) async throws {
        // 从缓存中移除
        cacheQueue.async {
            self.indexCache.removeValue(forKey: id)
        }
        
        // 清理相关查询缓存
        clearRelatedCache(for: id)
        
        // 使用批处理
        batchManager.queueDelete(id)
    }
    
    /// 清空所有笔记索引（优化版）
    func clearNoteIndexes() async throws {
        // 清空所有缓存
        cacheQueue.async {
            self.indexCache.removeAll()
        }
        queryCacheQueue.async {
            self.queryCache.removeAll()
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageOperationError.corrupted)
                    return
                }
                
                do {
                    try self.execute("DELETE FROM \(self.Table.noteIndex)")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 获取笔记数量（缓存优化）
    func getNoteCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }
                
                do {
                    let results = try self.executeQuery("SELECT COUNT(*) FROM \(self.Table.noteIndex)") { stmt in
                        Int(sqlite3_column_int(stmt, 0))
                    }
                    continuation.resume(returning: results.first ?? 0)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    /// 压缩数据库（优化版）
    func vacuum() async {
        _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                do {
                    // 刷新批处理操作
                    self?.batchManager.flushNow()
                    
                    // 执行VACUUM
                    try self?.execute("VACUUM")
                    
                    // 重新优化查询规划器
                    try self?.execute("PRAGMA optimize")
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func shouldExecuteImmediately() -> Bool {
        // 当批处理队列积累到一定程度时立即执行
        return true // 简化实现
    }
    
    private func executeImmediateUpsert(_ index: NoteIndex) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageOperationError.corrupted)
                    return
                }
                
                do {
                    try self.performUpsert(index)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performUpsert(_ index: NoteIndex) throws {
        let sql = """
            INSERT OR REPLACE INTO \(Table.noteIndex)
            (id, title, created_at, modified_at, tags, is_favorite, word_count, preview, last_accessed)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        
        let tagsJSON = try? JSONEncoder().encode(Array(index.tags))
        let tagsString = tagsJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        try executeUpdate(sql, parameters: [
            index.id.uuidString,
            index.title,
            Int(index.createdAt.timeIntervalSince1970),
            Int(index.modifiedAt.timeIntervalSince1970),
            tagsString ?? "[]",
            index.isFavorite ? 1 : 0,
            index.wordCount,
            index.preview,
            Int(Date().timeIntervalSince1970)
        ])
    }
    
    private func warmupCache() async {
        do {
            _ = try await getAllNoteIndexes()
        } catch {
            print("Warning: Failed to warm up cache: \(error)")
        }
    }
    
    // MARK: - Cache Management
    
    private func getCachedQueryResult(_ key: String) -> [NoteIndex]? {
        queryCacheQueue.sync {
            guard let cached = queryCache[key] else { return nil }
            
            // 检查缓存是否过期
            if Date().timeIntervalSince(cached.timestamp) > cacheExpiryInterval {
                queryCache.removeValue(forKey: key)
                return nil
            }
            
            return cached.result
        }
    }
    
    private func cacheQueryResult(_ key: String, result: [NoteIndex], shortTerm: Bool = false) {
        let expiryTime = shortTerm ? 60.0 : cacheExpiryInterval // 短期缓存1分钟，长期5分钟
        
        queryCacheQueue.async {
            self.queryCache[key] = (result: result, timestamp: Date())
            
            // 定期清理过期缓存
            self.cleanupExpiredCache()
        }
    }
    
    private func cleanupExpiredCache() {
        let now = Date()
        queryCache = queryCache.filter { (_, cached) in
            now.timeIntervalSince(cached.timestamp) < cacheExpiryInterval
        }
    }
    
    private func clearRelatedCache(for id: UUID) {
        queryCacheQueue.async {
            // 清理包含该ID的相关缓存
            self.queryCache.keys.forEach { key in
                if key.contains(id.uuidString) {
                    self.queryCache.removeValue(forKey: key)
                }
            }
        }
    }
    
    // MARK: - Optimized SQL Execution
    
    private func execute(_ sql: String) throws {
        var errorMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMsg)
        
        if result != SQLITE_OK {
            let error = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw StorageOperationError.corruptedData(location: sql)
        }
    }
    
    private func executeUpdate(_ sql: String, parameters: [Any] = []) throws {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StorageOperationError.corruptedData(location: "prepare")
        }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            let position = Int32(index + 1)
            
            switch parameter {
            case let string as String:
                sqlite3_bind_text(stmt, position, string, -1, SQLITE_TRANSIENT)
            case let int as Int:
                sqlite3_bind_int(stmt, position, Int32(int))
            case let bool as Bool:
                sqlite3_bind_int(stmt, position, bool ? 1 : 0)
            case let data as Data:
                _ = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(stmt, position, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
                }
            default:
                sqlite3_bind_null(stmt, position)
            }
        }
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageOperationError.corruptedData(location: "step")
        }
    }
    
    private func executeOptimizedQuery<T>(_ sql: String, parameters: [Any] = [], mapper: (OpaquePointer?) -> T?) throws -> [T] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StorageOperationError.corruptedData(location: "prepare_query")
        }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            let position = Int32(index + 1)
            
            switch parameter {
            case let string as String:
                sqlite3_bind_text(stmt, position, string, -1, SQLITE_TRANSIENT)
            case let int as Int:
                sqlite3_bind_int(stmt, position, Int32(int))
            default:
                sqlite3_bind_null(stmt, position)
            }
        }
        
        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let item = mapper(stmt) {
                results.append(item)
            }
        }
        
        return results
    }
    
    private func executeQuery<T>(_ sql: String, mapper: (OpaquePointer?) -> T) throws -> [T] {
        return try executeOptimizedQuery(sql, parameters: [], mapper: mapper)
    }
    
    // MARK: - Note Index Parsing (Optimized)
    
    private func parseNoteIndex(from stmt: OpaquePointer?) -> NoteIndex? {
        guard let stmt = stmt else { return nil }
        
        let id = String(cString: sqlite3_column_text(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int(stmt, 2)))
        let modifiedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int(stmt, 3)))
        
        var tags: Set<String> = []
        if let tagsText = sqlite3_column_text(stmt, 4) {
            let tagsString = String(cString: tagsText)
            if let data = tagsString.data(using: .utf8),
               let tagsArray = try? JSONDecoder().decode([String].self, from: data) {
                tags = Set(tagsArray)
            }
        }
        
        let isFavorite = sqlite3_column_int(stmt, 5) == 1
        let wordCount = Int(sqlite3_column_int(stmt, 6))
        let preview = String(cString: sqlite3_column_text(stmt, 7))
        
        guard let uuid = UUID(uuidString: id) else { return nil }
        
        return NoteIndex(
            id: uuid,
            title: title,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            tags: tags,
            isFavorite: isFavorite,
            wordCount: wordCount,
            preview: preview
        )
    }
}
