import Foundation

/// 暂存文件项目 —— Files 面板 drop zone 中的临时文件引用。
///
/// 暂存采用「引用」而非复制：文件保留在原位置，拖出时按原路径提供；
/// 项目是短生命周期的，若原文件消失（被移动/删除），UI 显示缺失状态并允许移除。
struct TempFileItem: Codable, Identifiable, Equatable {
    let id: UUID
    let url: URL
    let stagedAt: Date
    var accessCount: Int

    init(id: UUID = UUID(), url: URL, stagedAt: Date = Date(), accessCount: Int = 0) {
        self.id = id
        self.url = url
        self.stagedAt = stagedAt
        self.accessCount = accessCount
    }

    /// 文件名（含扩展名）
    var name: String { url.lastPathComponent }

    /// 原文件是否仍然存在
    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// 记录一次访问（打开/拖出/预览）
    mutating func recordAccess() {
        accessCount += 1
    }
}
