import XCTest
@testable import UnclutterPlus

/// 截图功能流程级测试：扫描 → 重命名 → 删除 → 清空，及异常路径容错
/// 通过 directoryOverride 注入临时目录，截图捕获管线不在覆盖范围内（已删除）
final class ScreenshotsFlowTests: XCTestCase {

    var tempDir: URL!

    /// 1x1 像素 PNG（合法图片数据）
    private let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Given - 隔离的临时截图目录
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnclutterPlusScreenshotsFlowTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// 在临时目录中预置一张截图（图片文件 + 元数据 JSON），模拟磁盘上已有的截图
    @discardableResult
    private func seedScreenshot(
        title: String,
        createdAt: Date = Date(),
        writeImage: Bool = true
    ) throws -> ScreenshotItem {
        let id = UUID()
        let imageURL = try XCTUnwrap(tempDir).appendingPathComponent("screenshot_\(id.uuidString).png")
        if writeImage {
            try onePixelPNG.write(to: imageURL)
        }

        let metadata = ScreenshotMetadata(
            id: id,
            imageURL: imageURL,
            title: title,
            createdAt: createdAt,
            ocrText: nil,
            ocrStatus: .pending,
            isFavorite: false,
            tags: [],
            source: .region,
            appName: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)

        let metadataDir = try XCTUnwrap(tempDir).appendingPathComponent("Metadata")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try data.write(to: metadataDir.appendingPathComponent("\(id.uuidString).json"))

        return ScreenshotItem(id: id, imageURL: imageURL, title: title, createdAt: createdAt, source: .region)
    }

    /// 元数据 JSON 是否仍存在于磁盘
    private func metadataFileExists(for id: UUID) -> Bool {
        let url = tempDir.appendingPathComponent("Metadata").appendingPathComponent("\(id.uuidString).json")
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Flow Tests

    /// 扫描流程：初始化时加载已有截图（按创建时间倒序）；图片缺失的孤儿元数据被剔除并清理
    func testScanExistingScreenshotsFlow() throws {
        // Given - 预置两张截图 + 一条图片文件已丢失的孤儿元数据
        let older = try seedScreenshot(title: "较早截图", createdAt: Date(timeIntervalSince1970: 1000))
        let newer = try seedScreenshot(title: "较新截图", createdAt: Date(timeIntervalSince1970: 2000))
        let orphan = try seedScreenshot(title: "孤儿截图", createdAt: Date(timeIntervalSince1970: 3000), writeImage: false)

        // When - 初始化管理器（触发目录扫描）
        let manager = ScreenshotManager(directoryOverride: tempDir)

        // Then - 已有截图按创建时间倒序出现
        XCTAssertEqual(manager.screenshots.map(\.id), [newer.id, older.id], "扫描结果应按创建时间倒序")
        // Then - 孤儿条目被剔除，其元数据文件被清理
        XCTAssertFalse(manager.screenshots.contains { $0.id == orphan.id }, "图片缺失的条目不应被加载")
        XCTAssertFalse(metadataFileExists(for: orphan.id), "图片缺失的孤儿元数据应被删除")
    }

    /// 重命名流程：内存状态更新 + 元数据持久化，新实例可见相同结果
    func testRenameScreenshotFlow() throws {
        // Given
        let seeded = try seedScreenshot(title: "原始标题")
        let manager = ScreenshotManager(directoryOverride: tempDir)
        let item = try XCTUnwrap(manager.screenshots.first)
        XCTAssertEqual(item.id, seeded.id)

        // When - 重命名
        manager.renameScreenshot(item, to: "新标题")

        // Then - 内存状态更新
        XCTAssertEqual(manager.screenshots.first?.title, "新标题")

        // Then - 元数据已持久化（新实例读取到相同标题）
        let reloaded = ScreenshotManager(directoryOverride: tempDir)
        XCTAssertEqual(reloaded.screenshots.first?.title, "新标题", "重命名结果应持久化到元数据")
    }

    /// 删除与清空流程：列表、磁盘文件、元数据、选中状态同步清理
    func testDeleteAndClearAllFlow() throws {
        // Given - 预置三张截图
        let first = try seedScreenshot(title: "截图一")
        let second = try seedScreenshot(title: "截图二")
        let third = try seedScreenshot(title: "截图三")
        let manager = ScreenshotManager(directoryOverride: tempDir)
        XCTAssertEqual(manager.screenshots.count, 3)

        // When - 选中后删除其中一张
        manager.toggleSelection(try XCTUnwrap(manager.screenshots.first { $0.id == first.id }))
        manager.deleteScreenshot(try XCTUnwrap(manager.screenshots.first { $0.id == first.id }))

        // Then - 列表 / 磁盘 / 选中状态同步移除
        XCTAssertEqual(manager.screenshots.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.imageURL.path), "图片文件应被删除")
        XCTAssertFalse(metadataFileExists(for: first.id), "元数据应被删除")
        XCTAssertTrue(manager.selectedScreenshots.isEmpty, "删除后其选中状态应被清理")

        // When - 全选后清空全部
        manager.selectAll()
        manager.clearAllScreenshots()

        // Then - 列表、选中集合、磁盘文件、元数据全部清空
        XCTAssertTrue(manager.screenshots.isEmpty)
        XCTAssertTrue(manager.selectedScreenshots.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.imageURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: third.imageURL.path))
        XCTAssertFalse(metadataFileExists(for: second.id))
        XCTAssertFalse(metadataFileExists(for: third.id))
    }

    /// 容错流程：存储路径不存在时自动创建；非法图片保存失败且不产生残留；空状态操作不崩溃
    func testMissingPathAndSaveFailureToleranceFlow() throws {
        // Given - 指向尚不存在的深层路径
        let missingDir = try XCTUnwrap(tempDir).appendingPathComponent("not/exist/yet")

        // When - 初始化管理器
        let manager = ScreenshotManager(directoryOverride: missingDir)

        // Then - 目录被自动创建且列表为空
        XCTAssertTrue(manager.screenshots.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: missingDir.path), "缺失的存储目录应被自动创建")

        // When - 保存一张无图像数据的非法图片
        let result = manager.saveScreenshot(image: NSImage(), source: .region)

        // Then - 返回失败且不产生任何条目或文件残留
        guard case .failure = result else {
            return XCTFail("非法图片应保存失败")
        }
        XCTAssertTrue(manager.screenshots.isEmpty, "保存失败不应产生截图条目")
        let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: missingDir.path)
        XCTAssertEqual(remainingFiles, ["Metadata"], "保存失败不应残留图片文件")

        // When/Then - 空状态下清空不崩溃
        manager.clearAllScreenshots()
        XCTAssertTrue(manager.screenshots.isEmpty)
    }
}
