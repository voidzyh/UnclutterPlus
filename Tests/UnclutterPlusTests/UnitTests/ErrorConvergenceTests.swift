import XCTest
@testable import UnclutterPlus

/// 错误系统收敛测试：所有域错误统一遵循 UnclutterError，
/// asUnclutterError 的包装/透传行为，以及 GlobalErrorHandler 的结构化输出。
final class ErrorConvergenceTests: XCTestCase {

    // MARK: - 统一协议遵循

    func testAllDomainErrorsConformToUnclutterError() {
        XCTAssertNotNil(NotesError.createFailed("x") as? UnclutterError)
        XCTAssertNotNil(AIServiceError.timedOut as? UnclutterError)
        XCTAssertNotNil(OCRError.binaryNotFound as? UnclutterError)
        XCTAssertNotNil(ObsidianExporter.ObsidianError.vaultNotConfigured as? UnclutterError)
        XCTAssertNotNil(StorageError.notFound(UUID()) as? UnclutterError)
        XCTAssertNotNil(ServiceError.timeout("op") as? UnclutterError)
        XCTAssertNotNil(ScreenshotError.captureFailed(underlying: NSError(domain: "t", code: 1)) as? UnclutterError)
        XCTAssertNotNil(PermissionError.clipboardAccessDenied as? UnclutterError)
        XCTAssertNotNil(ValidationError.emptyTitle as? UnclutterError)
    }

    func testDomainErrorsExposeCategoryAndCode() {
        XCTAssertEqual(NotesError.saveFailed("disk").category, .storage)
        XCTAssertEqual(NotesError.saveFailed("disk").errorCode, "NOTES_002")
        XCTAssertEqual(AIServiceError.timedOut.category, .network)
        XCTAssertEqual(AIServiceError.timedOut.errorCode, "AI_007")
        XCTAssertEqual(OCRError.binaryNotFound.category, .system)
        XCTAssertEqual(OCRError.binaryNotFound.errorCode, "OCR_002")
        XCTAssertEqual(ObsidianExporter.ObsidianError.vaultNotConfigured.category, .storage)
        XCTAssertEqual(ObsidianExporter.ObsidianError.vaultNotConfigured.errorCode, "OBSIDIAN_001")
    }

    func testErrorDescriptionUsesStructuredFormat() {
        XCTAssertEqual(
            NotesError.createFailed("boom").errorDescription,
            "[NOTES_005] Failed to create note: boom"
        )
    }

    // MARK: - asUnclutterError 行为

    func testAsUnclutterErrorPassesThroughConformingErrors() {
        let error = NotesError.loadFailed("io")
        let converted = error.asUnclutterError()
        XCTAssertTrue(converted is NotesError)
        XCTAssertEqual(converted.errorCode, "NOTES_001")
    }

    func testUnknownErrorWrapsWithUnderlyingPreserved() {
        let underlying = NSError(domain: "CustomDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "自定义故障"])
        let converted = underlying.asUnclutterError()

        guard case .unknown(let wrapped) = converted as? ServiceError else {
            return XCTFail("未知错误应包装为 ServiceError.unknown")
        }
        XCTAssertEqual((wrapped as NSError).domain, "CustomDomain")
        XCTAssertEqual((wrapped as NSError).code, 42)
        XCTAssertEqual(converted.errorCode, "SERVICE_007")
    }

    func testFileSystemErrorMapsToStorageError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        let converted = error.asUnclutterError()

        guard case .notFound = converted as? StorageError else {
            return XCTFail("文件不存在错误应映射为 StorageError.notFound")
        }
    }

    func testUserFriendlyMessageWorksForAnyError() {
        XCTAssertEqual(
            AIServiceError.timedOut.userFriendlyMessage(),
            "AI 请求超时"
        )
    }

    // MARK: - GlobalErrorHandler 结构化输出

    @MainActor
    func testGlobalErrorHandlerProducesStructuredState() {
        let handler = GlobalErrorHandler.shared
        handler.clearHistory()

        // showAlert: false → 立即进入历史（不经过 0.5s 防抖）
        handler.handle(NotesError.createFailed("disk full"), context: "创建笔记", showAlert: false)

        guard let entry = handler.errorHistory.last else {
            return XCTFail("错误应进入历史记录")
        }
        XCTAssertEqual(entry.category, .storage)
        XCTAssertEqual(entry.errorCode, "NOTES_005")
        XCTAssertFalse(entry.message.isEmpty)
    }
}
