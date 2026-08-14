import Foundation
import Combine
import AppKit

/// 文件暂存管理器 —— Files 面板 drop zone 的数据层。
///
/// 职责：暂存文件引用的增删查、访问统计、JSON 持久化。
/// 面板自动隐藏等 UI 行为经 `autoHideHandler` 回调由 App 层注入（Core 不依赖 WindowManager）。
class TempFileManager: ObservableObject {
    static let shared = TempFileManager()

    // MARK: - Published Properties

    @Published private(set) var files: [TempFileItem] = []

    // MARK: - Private Properties

    private let fileManager = FileManager.default

    /// 动作后自动隐藏面板的回调（由 App 层注入，避免 Core 层直接依赖 WindowManager 单例）
    var autoHideHandler: ((AutoHideAction) -> Void)?

    /// 元数据存储目录覆盖（仅用于测试注入；nil 时使用默认 Application Support 路径）
    private let metadataDirectoryOverride: URL?

    /// 元数据存储目录
    private var metadataDirectory: URL {
        let metadataDirectory: URL
        if let override = metadataDirectoryOverride {
            metadataDirectory = override
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDirectory = appSupport.appendingPathComponent("UnclutterPlus")
            metadataDirectory = appDirectory.appendingPathComponent("Files").appendingPathComponent("StagedFilesMetadata")
        }

        if !fileManager.fileExists(atPath: metadataDirectory.path) {
            try? fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        }

        return metadataDirectory
    }

    // MARK: - Initialization

    /// - Parameter metadataDirectoryOverride: 元数据目录覆盖（默认 nil，使用真实用户目录；测试可注入临时目录）
    init(metadataDirectoryOverride: URL? = nil) {
        self.metadataDirectoryOverride = metadataDirectoryOverride
        loadFiles()
    }

    // MARK: - Persistence

    /// 加载暂存文件列表（启动时过滤已不存在的文件引用）
    private func loadFiles() {
        let filePath = metadataDirectory.appendingPathComponent("stagedFiles.json")

        guard fileManager.fileExists(atPath: filePath.path) else {
            files = []
            return
        }

        do {
            let data = try Data(contentsOf: filePath)
            let loaded = try JSONDecoder().decode([TempFileItem].self, from: data)
            files = loaded.filter { $0.exists }
        } catch {
            logger.debug("Failed to load staged files: \(error)", category: "TempFileManager")
            files = []
        }
    }

    private func saveFiles() {
        let filePath = metadataDirectory.appendingPathComponent("stagedFiles.json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(files)
            try data.write(to: filePath)
        } catch {
            logger.debug("Failed to save staged files: \(error)", category: "TempFileManager")
        }
    }

    // MARK: - Public Methods

    /// 暂存一个文件（引用，不复制）。已暂存同一路径时记一次访问并置顶。
    /// - Returns: 是否成功（文件必须存在且不是目录）
    @discardableResult
    func stageFile(url: URL) -> Bool {
        // 校验：必须是存在的普通文件（目录交给收藏文件夹流程）
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return false
        }

        // 去重：同一路径已暂存 → 记访问 + 置顶
        if let index = files.firstIndex(where: { $0.url == url }) {
            files[index].recordAccess()
            let item = files.remove(at: index)
            files.insert(item, at: 0)
            saveFiles()
            return true
        }

        let newItem = TempFileItem(url: url)
        files.insert(newItem, at: 0)
        saveFiles()
        return true
    }

    /// 移除暂存文件
    func removeFile(_ item: TempFileItem) {
        files.removeAll { $0.id == item.id }
        saveFiles()
    }

    /// 清空所有暂存文件
    func clearAllFiles() {
        files.removeAll()
        saveFiles()
    }

    /// 打开暂存文件（用默认应用），记录访问并触发面板自动隐藏
    func openFile(_ item: TempFileItem) {
        guard item.exists else { return }

        recordAccess(for: item)

        NSWorkspace.shared.open(item.url)
        autoHideHandler?(.fileOpened)
    }

    /// 在 Finder 中揭示暂存文件，触发面板自动隐藏
    func revealInFinder(_ item: TempFileItem) {
        guard item.exists else { return }

        NSWorkspace.shared.activateFileViewerSelecting([item.url])
        autoHideHandler?(.fileShowInFinder)
    }

    /// 记录访问（供拖出/预览等 UI 层路径复用）
    func recordAccess(for item: TempFileItem) {
        guard let index = files.firstIndex(where: { $0.id == item.id }) else { return }
        files[index].recordAccess()
        saveFiles()
    }
}
