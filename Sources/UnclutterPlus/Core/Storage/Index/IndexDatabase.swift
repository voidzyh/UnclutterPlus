import Foundation
import SQLite3

// Define SQLite constants
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite 索引数据库管理器
class IndexDatabase {
    private var db: OpaquePointer?
    private let dbPath: URL
    private let queue = DispatchQueue(label: "indexdb.queue", attributes: .concurrent)

    enum Table {
        static let noteIndex = "note_index"
        static let noteFTS = "note_fts"
        static let clipboardIndex = "clipboard_index"
        static let screenshotIndex = "screenshot_index"
    }

    // MARK: - Initialization

    init(path: URL) throws {
        self.dbPath = path.appendingPathComponent("index.db")

        // 创建目录
        try FileManager.default.createDirectory(
            at: path,
            withIntermediateDirectories: true
        )

        // 打开数据库
        let result = sqlite3_open_v2(
            dbPath.path,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK else {
            throw StorageError.corrupted
        }

        // 创建表
        try createTables()

        // 启用 WAL 模式（提高并发性能）
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Table Creation

    private func createTables() throws {
        // 创建笔记索引表
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
                content_hash TEXT
            );
            """

        // 创建笔记全文搜索表
        let createNoteFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS \(Table.noteFTS)
            USING fts5(
                title,
                preview,
                content,
                content='\(Table.noteIndex)',
                content_rowid='rowid'
            );
            """

        // 创建索引
        let createIndexes = """
            CREATE INDEX IF NOT EXISTS idx_notes_modified
                ON \(Table.noteIndex)(modified_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notes_favorite
                ON \(Table.noteIndex)(is_favorite DESC, modified_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notes_created
                ON \(Table.noteIndex)(created_at DESC);
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
            """

        // 执行创建语句
        try execute(createNoteIndex)
        try execute(createNoteFTS)
        try execute(createIndexes)
        try execute(createClipboardIndex)

        // 创建触发器，自动更新 FTS
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

    // MARK: - Note Index Operations

    /// 插入或更新笔记索引
    func upsertNoteIndex(_ index: NoteIndex) async throws {
        let sql = """
            INSERT OR REPLACE INTO \(Table.noteIndex)
            (id, title, created_at, modified_at, tags, is_favorite, word_count, preview)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """

        let tagsJSON = try? JSONEncoder().encode(Array(index.tags))
        let tagsString = tagsJSON.flatMap { String(data: $0, encoding: .utf8) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageError.corrupted)
                    return
                }

                do {
                    try self.executeUpdate(sql, parameters: [
                        index.id.uuidString,
                        index.title,
                        Int(index.createdAt.timeIntervalSince1970),
                        Int(index.modifiedAt.timeIntervalSince1970),
                        tagsString ?? "[]",
                        index.isFavorite ? 1 : 0,
                        index.wordCount,
                        index.preview
                    ])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 获取所有笔记索引
    func getAllNoteIndexes() async throws -> [NoteIndex] {
        let sql = """
            SELECT id, title, created_at, modified_at, tags, is_favorite, word_count, preview
            FROM \(Table.noteIndex)
            ORDER BY modified_at DESC
            """

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                do {
                    let indexes = try self.executeQuery(sql) { stmt in
                        self.parseNoteIndex(from: stmt)
                    }
                    continuation.resume(returning: indexes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 搜索笔记
    func searchNotes(query: String) async throws -> [NoteIndex] {
        let sql = """
            SELECT n.id, n.title, n.created_at, n.modified_at, n.tags,
                   n.is_favorite, n.word_count, n.preview
            FROM \(Table.noteIndex) n
            JOIN \(Table.noteFTS) f ON n.rowid = f.rowid
            WHERE \(Table.noteFTS) MATCH ?
            ORDER BY rank
            """

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                do {
                    let indexes = try self.executeQuery(sql, parameters: [query]) { stmt in
                        self.parseNoteIndex(from: stmt)
                    }
                    continuation.resume(returning: indexes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 删除笔记索引
    func deleteNoteIndex(id: UUID) async throws {
        let sql = "DELETE FROM \(Table.noteIndex) WHERE id = ?"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageError.corrupted)
                    return
                }

                do {
                    try self.executeUpdate(sql, parameters: [id.uuidString])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 清空所有笔记索引
    func clearNoteIndexes() async throws {
        let sql = "DELETE FROM \(Table.noteIndex)"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: StorageError.corrupted)
                    return
                }

                do {
                    try self.execute(sql)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helper Methods

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

        // 创建临时 Note 对象来生成索引
        let note = Note(title: title, content: "", tags: tags, isFavorite: isFavorite)

        // Create a NoteIndex with the necessary data
        var index = NoteIndex(from: note)
        // Override fields that were loaded from database
        index = NoteIndex(
            id: uuid,
            title: title,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            tags: tags,
            isFavorite: isFavorite,
            wordCount: wordCount,
            preview: preview
        )

        return index
    }

    // MARK: - SQL Execution Helpers

    private func execute(_ sql: String) throws {
        var errorMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMsg)

        if result != SQLITE_OK {
            let error = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw StorageError.unknown(NSError(domain: "SQLite", code: Int(result), userInfo: [NSLocalizedDescriptionKey: error]))
        }
    }

    private func executeUpdate(_ sql: String, parameters: [Any] = []) throws {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StorageError.corrupted
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
                data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(stmt, position, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
                }
            default:
                sqlite3_bind_null(stmt, position)
            }
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.corrupted
        }
    }

    private func executeQuery<T>(_ sql: String, parameters: [Any] = [], mapper: (OpaquePointer?) -> T?) throws -> [T] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StorageError.corrupted
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

    // MARK: - Statistics

    /// 获取笔记数量
    func getNoteCount() async -> Int {
        let sql = "SELECT COUNT(*) FROM \(Table.noteIndex)"

        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }

                do {
                    let results = try self.executeQuery(sql) { stmt in
                        Int(sqlite3_column_int(stmt, 0))
                    }
                    continuation.resume(returning: results.first ?? 0)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    /// 压缩数据库
    func vacuum() async {
        _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                do {
                    try self?.execute("VACUUM")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}