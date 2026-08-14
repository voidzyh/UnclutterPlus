import XCTest
import AppKit
@testable import UnclutterPlus

/// Vision 本地 OCR 引擎测试：语言映射纯函数 + 真实图像识别。
final class VisionOCREngineTests: XCTestCase {

    // MARK: - 语言映射

    func testLanguagesMapping() {
        XCTAssertEqual(VisionOCREngine.languages(from: "zh,en"), ["zh-Hans", "en-US"])
        XCTAssertEqual(VisionOCREngine.languages(from: "zh-hant,ja"), ["zh-hant", "ja-JP"])
        XCTAssertEqual(VisionOCREngine.languages(from: "zh-Hans, EN "), ["zh-hans", "en-US"], "应大小写不敏感并去空白")
        XCTAssertEqual(VisionOCREngine.languages(from: ""), [])
        XCTAssertEqual(VisionOCREngine.languages(from: "xx,fr"), ["fr-FR"], "不支持的代码应跳过")
    }

    // MARK: - 真实识别

    func testRecognizeTextFromRenderedImage() async throws {
        // Given - 渲染包含清晰文字的图片（Vision 无需屏幕录制权限）
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vision-ocr-test-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let size = NSSize(width: 1000, height: 240)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 56, weight: .semibold),
            .foregroundColor: NSColor.black,
        ]
        ("UnclutterPlus OCR 12345").draw(at: NSPoint(x: 60, y: 90), withAttributes: attributes)
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return XCTFail("无法生成测试图片")
        }
        try png.write(to: url)

        // When
        let engine = VisionOCREngine()
        let result = await engine.recognize(imageURL: url)

        // Then - 拉丁字符与数字应可识别（中文取决于系统语言包，做宽松断言）
        guard case .success(let text) = result else {
            return XCTFail("Vision OCR 应成功识别渲染文字")
        }
        XCTAssertTrue(text.localizedCaseInsensitiveContains("unclutterplus"), "识别结果应包含 'UnclutterPlus'，实际：\(text)")
        XCTAssertTrue(text.contains("12345"), "识别结果应包含数字 '12345'，实际：\(text)")
    }
}
