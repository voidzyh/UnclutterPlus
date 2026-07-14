import Foundation
import AppKit

/// Obsidian 导出器 —— 将笔记/文档草稿导出为 .md 文件写入 Obsidian vault。
///
/// 项目首个 .md 文件导出与 Obsidian 集成。能力：
/// - 写 `<title>.md` 到配置的 vault 路径（标签转 YAML frontmatter）
/// - 可选用 `obsidian://open` URI 在 Obsidian 中打开
/// - 可选在 Finder 中定位
///
/// vault 路径解析复用 ConfigurationManager 的目录校验模式。
enum ObsidianExporter {

    /// 导出结果
    struct ExportResult {
        let fileURL: URL
        let vaultName: String?
        /// 可用于打开的 obsidian:// URI（vault 名称未配置时为 nil）
        let openURI: URL?
    }

    enum ObsidianError: LocalizedError {
        case vaultNotConfigured
        case invalidTitle(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .vaultNotConfigured: return "Obsidian 仓库路径未配置"
            case .invalidTitle(let t): return "标题无效，无法生成文件名：\(t)"
            case .writeFailed(let m): return "写入文件失败：\(m)"
            }
        }
    }

    // MARK: - 公共导出入口

    /// 导出文档草稿（来自剪贴板洞察引擎）。
    static func export(draft: DocumentDraft, openInObsidian: Bool = false) throws -> ExportResult {
        try writeMarkdown(
            title: draft.title,
            content: draft.content,
            tags: draft.tags,
            openInObsidian: openInObsidian
        )
    }

    /// 导出笔记（来自笔记模块）。
    static func exportNote(title: String, content: String, tags: [String], openInObsidian: Bool = false) throws -> ExportResult {
        try writeMarkdown(
            title: title,
            content: content,
            tags: tags,
            openInObsidian: openInObsidian
        )
    }

    // MARK: - 核心写盘逻辑

    /// 将标题/正文/标签组装为带 frontmatter 的 Markdown，写入 vault 目录。
    private static func writeMarkdown(title: String, content: String, tags: [String], openInObsidian: Bool) throws -> ExportResult {
        let config = ConfigurationManager.shared
        guard !config.obsidianVaultPath.isEmpty else {
            throw ObsidianError.vaultNotConfigured
        }

        let vaultURL = URL(fileURLWithPath: config.obsidianVaultPath)
        try ensureDirectory(at: vaultURL)

        let fileName = sanitizeFileName(from: title)
        guard !fileName.isEmpty else {
            throw ObsidianError.invalidTitle(title)
        }

        // 标题冲突时追加数字后缀
        let fileURL = uniqueFileURL(baseName: fileName, in: vaultURL)

        // 组装 Markdown：YAML frontmatter（标签）+ 正文
        let markdown = assembleMarkdown(title: title, content: content, tags: tags)

        do {
            try markdown.data(using: .utf8)?.write(to: fileURL, options: .atomic)
        } catch {
            throw ObsidianError.writeFailed(error.localizedDescription)
        }

        // 构造 obsidian:// URI（需 vault 名称）
        let openURI: URL?
        if openInObsidian {
            openURI = makeObsidianURI(vaultName: config.obsidianVaultName, file: fileName)
        } else {
            openURI = nil
        }

        return ExportResult(fileURL: fileURL, vaultName: config.obsidianVaultName.isEmpty ? nil : config.obsidianVaultName, openURI: openURI)
    }

    // MARK: - Markdown 组装

    /// 组装含 YAML frontmatter 的 Markdown 文档。
    /// Obsidian 约定：frontmatter 中的 tags 字段会被识别为笔记标签。
    static func assembleMarkdown(title: String, content: String, tags: [String]) -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("title: \"\(escapeYAML(title))\"")
        if !tags.isEmpty {
            // YAML 数组格式：tags: [a, b, c]
            let tagList = tags.map { escapeYAML($0) }.joined(separator: ", ")
            lines.append("tags: [\(tagList)]")
        }
        lines.append("exported_at: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("---")
        lines.append("")
        lines.append("# \(title)")
        lines.append("")
        lines.append(content)
        return lines.joined(separator: "\n")
    }

    // MARK: - 文件名处理

    /// 从标题生成合法文件名（去除文件系统非法字符）。
    static func sanitizeFileName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // 文件系统非法字符替换
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed
            .components(separatedBy: illegal)
            .joined(separator: "-")
    }

    /// 若文件已存在，追加 " 2"、" 3" 后缀避免覆盖。
    private static func uniqueFileURL(baseName: String, in directory: URL) -> URL {
        let url = directory.appendingPathComponent("\(baseName).md")
        guard !FileManager.default.fileExists(atPath: url.path) else {
            // 递归找可用名
            var n = 2
            while true {
                let candidate = directory.appendingPathComponent("\(baseName) \(n).md")
                if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
                n += 1
            }
        }
        return url
    }

    // MARK: - Obsidian URI

    /// 构造 `obsidian://open?vault=<name>&file=<file>` URI。
    /// vault 名称为空则返回 nil（无法定位仓库）。
    static func makeObsidianURI(vaultName: String?, file: String) -> URL? {
        guard let vaultName, !vaultName.isEmpty else { return nil }
        // obsidian:// URI 的参数需 URL 编码；file 用不含扩展名的文件名
        let fileBase = (file as NSString).deletingPathExtension
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName),
            URLQueryItem(name: "file", value: fileBase)
        ]
        return components.url
    }

    // MARK: - 外部打开

    /// 在 Obsidian 中打开（通过 URI），失败则回退到用默认应用打开 .md 文件。
    @MainActor
    static func open(result: ExportResult) {
        if let uri = result.openURI {
            NSWorkspace.shared.open(uri)
        } else {
            NSWorkspace.shared.open(result.fileURL)
        }
    }

    /// 在 Finder 中定位导出的文件。
    @MainActor
    static func revealInFinder(_ result: ExportResult) {
        NSWorkspace.shared.activateFileViewerSelecting([result.fileURL])
    }

    // MARK: - 辅助

    private static func ensureDirectory(at url: URL) throws {
        var isDir: ObjCBool = false
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw ObsidianError.writeFailed("仓库路径已存在且不是目录：\(url.path)")
            }
        } else {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// 转义 YAML 字符串值中的双引号与反斜杠。
    private static func escapeYAML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
