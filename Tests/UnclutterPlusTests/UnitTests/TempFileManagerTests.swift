import XCTest
@testable import UnclutterPlus

/// 文件暂存管理器单元测试：暂存去重、访问计数、持久化、缺失文件容忍。
final class TempFileManagerTests: XCTestCase {

    private var metadataDir: URL!
    private var workDir: URL!

    override func setUp() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        metadataDir = root.appendingPathComponent("Metadata")
        workDir = root.appendingPathComponent("Work")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: metadataDir.deletingLastPathComponent())
    }

    private func makeFile(named name: String) throws -> URL {
        let url = workDir.appendingPathComponent(name)
        try Data("content-\(name)".utf8).write(to: url)
        return url
    }

    // MARK: - 暂存

    func testStageFileAddsToFront() throws {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let a = try makeFile(named: "a.txt")
        let b = try makeFile(named: "b.txt")

        XCTAssertTrue(manager.stageFile(url: a))
        XCTAssertTrue(manager.stageFile(url: b))

        // 最新的在前
        XCTAssertEqual(manager.files.map(\.name), ["b.txt", "a.txt"])
    }

    func testStageDuplicateIncrementsAccessAndMovesToFront() throws {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let a = try makeFile(named: "a.txt")
        let b = try makeFile(named: "b.txt")

        manager.stageFile(url: a)
        manager.stageFile(url: b)
        XCTAssertTrue(manager.stageFile(url: a)) // 重复暂存

        XCTAssertEqual(manager.files.count, 2)
        XCTAssertEqual(manager.files.first?.name, "a.txt")
        XCTAssertEqual(manager.files.first?.accessCount, 1)
    }

    func testStageRejectsDirectory() throws {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let dir = workDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        XCTAssertFalse(manager.stageFile(url: dir))
        XCTAssertTrue(manager.files.isEmpty)
    }

    func testStageRejectsMissingFile() {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let missing = workDir.appendingPathComponent("nope.txt")

        XCTAssertFalse(manager.stageFile(url: missing))
        XCTAssertTrue(manager.files.isEmpty)
    }

    // MARK: - 移除

    func testRemoveAndClearAll() throws {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let a = try makeFile(named: "a.txt")
        let b = try makeFile(named: "b.txt")
        manager.stageFile(url: a)
        manager.stageFile(url: b)

        manager.removeFile(manager.files[0])
        XCTAssertEqual(manager.files.map(\.name), ["a.txt"])

        manager.clearAllFiles()
        XCTAssertTrue(manager.files.isEmpty)
    }

    // MARK: - 持久化

    func testFilesPersistAcrossInstances() throws {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let a = try makeFile(named: "a.txt")
        manager.stageFile(url: a)
        manager.recordAccess(for: manager.files[0])

        // 新实例 + 同一元数据目录：应恢复暂存列表与访问计数
        let reloaded = TempFileManager(metadataDirectoryOverride: metadataDir)
        XCTAssertEqual(reloaded.files.count, 1)
        XCTAssertEqual(reloaded.files[0].name, "a.txt")
        XCTAssertEqual(reloaded.files[0].accessCount, 1)
    }

    func testLoadFiltersMissingFiles() throws {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let a = try makeFile(named: "a.txt")
        manager.stageFile(url: a)

        // 原文件被删除后重启：缺失引用被过滤
        try FileManager.default.removeItem(at: a)
        let reloaded = TempFileManager(metadataDirectoryOverride: metadataDir)
        XCTAssertTrue(reloaded.files.isEmpty)
    }

    func testExistsReflectsFileState() throws {
        let manager = TempFileManager(metadataDirectoryOverride: metadataDir)
        let a = try makeFile(named: "a.txt")
        manager.stageFile(url: a)

        XCTAssertTrue(manager.files[0].exists)
        try FileManager.default.removeItem(at: a)
        XCTAssertFalse(manager.files[0].exists)
    }
}
