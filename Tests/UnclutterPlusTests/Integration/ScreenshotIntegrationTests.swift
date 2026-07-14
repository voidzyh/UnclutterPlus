import XCTest
import AppKit
@testable import UnclutterPlus

/// 截图功能集成测试 - 验证真实文件系统操作
@MainActor
final class ScreenshotIntegrationTests: XCTestCase {
    
    var tempDirectory: URL!
    var originalUseCustomPath: Bool!
    var originalCustomPath: String!
    
    override func setUp() async throws {
        // 创建临时测试目录
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 保存原始配置
        originalUseCustomPath = ConfigurationManager.shared.useCustomScreenshotsPath
        originalCustomPath = ConfigurationManager.shared.screenshotsCustomPathDisplay // Use the raw storage key if possible, but setter/getter works
        
        // 重定向配置到临时目录
        // ConfigurationManager 不直接暴露 raw path setter，而是通过 setScreenshotsCustomPath
        // 这里的路径逻辑是：如果启用 custom，则路径是 customPath/UnclutterPlus_Screenshots
        // 所以我们设置 customPath 为临时目录
        ConfigurationManager.shared.useCustomScreenshotsPath = true
        ConfigurationManager.shared.setScreenshotsCustomPath(tempDirectory.path)
        
        // 清理 ScreenshotManager 的内存状态（因为它是单例）
        ScreenshotManager.shared.clearAllScreenshots() 
    }
    
    override func tearDown() async throws {
        // 恢复配置
        ConfigurationManager.shared.useCustomScreenshotsPath = originalUseCustomPath
        ConfigurationManager.shared.setScreenshotsCustomPath(originalCustomPath)
        
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDirectory)
        
        // 清理 ScreenshotManager 状态
        ScreenshotManager.shared.clearAllScreenshots()
    }
    
    func testRealFilePersistence() throws {
        // Given
        let image = createTestImage()
        let manager = ScreenshotManager.shared
        
        // When
        let result = manager.saveScreenshot(image: image, source: .region)
        
        // Then
        switch result {
        case .success(let item):
            // 验证内存状态
            XCTAssertTrue(manager.screenshots.contains(where: { $0.id == item.id }))
            
            // 验证物理文件是否存在
            let fileExists = FileManager.default.fileExists(atPath: item.imageURL.path)
            XCTAssertTrue(fileExists, "截图文件应该真实存在于磁盘上")
            
            // 验证文件路径是否在我们的临时目录中
            // ConfigurationManager 会在 customPath 下创建 UnclutterPlus_Screenshots 子目录
            XCTAssertTrue(item.imageURL.path.contains(tempDirectory.path), "文件路径应该包含临时目录")
            
            // 验证元数据文件
            let metadataPath = item.imageURL.deletingLastPathComponent()
                .appendingPathComponent("Metadata")
                .appendingPathComponent("\(item.id.uuidString).json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: metadataPath.path), "元数据文件应该真实存在")
            
        case .failure(let error):
            XCTFail("保存截图失败: \(error.localizedDescription)")
        }
    }
    
    // 辅助方法：创建测试图片
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
