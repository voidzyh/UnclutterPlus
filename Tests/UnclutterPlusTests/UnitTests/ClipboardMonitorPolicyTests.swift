import XCTest
@testable import UnclutterPlus

/// 剪贴板采集策略单元测试：指纹、敏感/瞬态忽略、应用排除、向后兼容解码。
/// 只测纯函数与模型层，不依赖 NSPasteboard。
@MainActor
final class ClipboardMonitorPolicyTests: XCTestCase {

    // MARK: - 指纹

    func testFingerprintNormalizesCaseAndWhitespace() {
        XCTAssertEqual(
            ClipboardMonitor.fingerprint("  Git   Commit  -m 'Hi'  "),
            "git commit -m 'hi'"
        )
        XCTAssertEqual(
            ClipboardMonitor.fingerprint("HELLO\t\n WORLD"),
            "hello world"
        )
    }

    func testFingerprintForItemTextUsesFullContentNotPreview() {
        // 回归测试：此前用 preview（前 100 字符）重建指纹，长文本重启后重复入库
        let longText = String(repeating: "a", count: 150) + " tail"
        let item = ClipboardItem(content: .text(longText))
        XCTAssertEqual(
            ClipboardMonitor.fingerprint(for: item),
            ClipboardMonitor.fingerprint(longText)
        )
    }

    func testFingerprintForItemFileUsesFullPath() {
        let url = URL(fileURLWithPath: "/Users/test/Documents/report.pdf")
        let item = ClipboardItem(content: .file(url))
        XCTAssertEqual(ClipboardMonitor.fingerprint(for: item), "file::/Users/test/Documents/report.pdf")
    }

    func testFingerprintForItemImageIsNil() {
        let item = ClipboardItem(content: .image(Data([0x01])))
        XCTAssertNil(ClipboardMonitor.fingerprint(for: item))
    }

    // MARK: - 敏感/瞬态忽略

    func testShouldIgnoreConcealedType() {
        XCTAssertTrue(ClipboardMonitor.shouldIgnore(
            types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            ignoreConcealed: true,
            ignoreTransient: true
        ))
        // 开关关闭时不忽略
        XCTAssertFalse(ClipboardMonitor.shouldIgnore(
            types: ["org.nspasteboard.ConcealedType"],
            ignoreConcealed: false,
            ignoreTransient: true
        ))
    }

    func testShouldIgnoreOnePasswordLegacyType() {
        XCTAssertTrue(ClipboardMonitor.shouldIgnore(
            types: ["com.agilebits.onepassword"],
            ignoreConcealed: true,
            ignoreTransient: true
        ))
    }

    func testShouldIgnoreTransientTypeWhenEnabled() {
        XCTAssertTrue(ClipboardMonitor.shouldIgnore(
            types: ["org.nspasteboard.TransientType"],
            ignoreConcealed: true,
            ignoreTransient: true
        ))
        XCTAssertFalse(ClipboardMonitor.shouldIgnore(
            types: ["org.nspasteboard.TransientType"],
            ignoreConcealed: true,
            ignoreTransient: false
        ))
    }

    func testShouldNotIgnorePlainText() {
        XCTAssertFalse(ClipboardMonitor.shouldIgnore(
            types: ["public.utf8-plain-text"],
            ignoreConcealed: true,
            ignoreTransient: true
        ))
    }

    // MARK: - 应用排除

    func testExcludedSourceAppMatchesCaseInsensitively() {
        let excluded: Set<String> = ["com.1password.1password", "com.apple.keychainaccess"]
        XCTAssertTrue(ClipboardMonitor.isExcludedSourceApp(
            bundleID: "com.1Password.1Password",
            excludedBundleIDs: excluded
        ))
        XCTAssertFalse(ClipboardMonitor.isExcludedSourceApp(
            bundleID: "com.apple.Safari",
            excludedBundleIDs: excluded
        ))
    }

    func testExcludedSourceAppHandlesNilAndEmpty() {
        XCTAssertFalse(ClipboardMonitor.isExcludedSourceApp(bundleID: nil, excludedBundleIDs: ["com.x.y"]))
        XCTAssertFalse(ClipboardMonitor.isExcludedSourceApp(bundleID: "", excludedBundleIDs: ["com.x.y"]))
        XCTAssertFalse(ClipboardMonitor.isExcludedSourceApp(bundleID: "com.x.y", excludedBundleIDs: []))
    }

    // MARK: - 指纹持久化与向后兼容

    func testFingerprintRoundTripsThroughCodable() throws {
        let item = ClipboardItem(content: .text("git status"), fingerprint: "git status")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded.fingerprint, "git status")
    }

    func testLegacyJSONWithoutFingerprintKeyDecodesToNil() throws {
        // 模拟 v2.0.0 之前持久化的 item JSON（无 fingerprint 字段）
        let legacy = ClipboardItem(content: .text("legacy text"))
        let data = try JSONEncoder().encode(legacy)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object.removeValue(forKey: "fingerprint")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: legacyData)
        XCTAssertNil(decoded.fingerprint)
        XCTAssertEqual(decoded.content, .text("legacy text"))
    }

    func testClipboardIndexCarriesFingerprintFromItem() {
        let item = ClipboardItem(content: .text("hello world"), fingerprint: "hello world")
        let index = ClipboardIndex(from: item)
        XCTAssertEqual(index.fingerprint, "hello world")
    }

    func testClipboardIndexFingerprintNilForLegacyItem() {
        let item = ClipboardItem(content: .text("legacy"))
        XCTAssertNil(ClipboardIndex(from: item).fingerprint)
    }
}
