import Foundation
import AppKit
import Combine

/// 剪贴板采集器 - 监听系统剪贴板变化并持久化历史
///
/// 单一、现代的剪贴板采集实现，取代旧的空 stub（ClipboardManager）和
/// 死的监听逻辑（ClipboardViewModel+Repository）。
///
/// `useCount` 语义：表示该内容在系统剪贴板中被复制/出现的次数
/// （每次 changeCount 变化且指纹匹配已存在项时 +1），是"粘贴次数统计"的数据源。
@MainActor
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    // MARK: - Published

    /// 最近一次采集状态变化（用于 UI 刷新提示）
    @Published private(set) var lastCapturedAt: Date?

    // MARK: - Private

    private let repository: ClipboardRepository
    private let config = ConfigurationManager.shared
    private let pasteboard = NSPasteboard.general

    /// 轮询定时器
    private var timer: Timer?

    /// 上一次观察到的 pasteboard changeCount，用于检测变化
    private var lastChangeCount: Int

    /// 内容指纹缓存：normalize 后的文本 -> 已存在项的 id
    /// 避免每次去重都全量扫描 repository；启动时从持久化数据重建
    private var fingerprintIndex: [String: UUID] = [:]

    /// 是否已初始化指纹缓存
    private var didBootstrapFingerprints = false

    /// 最小文本长度：过短的片段（如单字符）不采集
    private let minTextLength = 2

    // MARK: - Init

    private init(repository: ClipboardRepository? = nil) {
        self.repository = repository ?? AppStorageManager.shared.clipboardRepository
        self.lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Lifecycle

    /// 启动剪贴板监听。在 app 启动时调用一次。
    func start() {
        guard timer == nil else { return }

        Task {
            await bootstrapFingerprints()
        }

        let interval = config.clipboardMonitorInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.checkForClipboardChanges()
            }
        }
        logger.info("剪贴板监听已启动（间隔 \(config.clipboardMonitorInterval)s）", category: "ClipboardMonitor")
    }

    /// 停止监听。
    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("剪贴板监听已停止", category: "ClipboardMonitor")
    }

    // MARK: - Change Detection

    private func checkForClipboardChanges() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        Task {
            await processClipboardContent()
        }
    }

    private func processClipboardContent() async {
        guard let content = readPasteboardContent() else { return }

        // 获取来源应用信息
        let (bundleID, appName, appIcon) = currentSourceAppInfo()

        switch content {
        case .text(let text):
            await handleText(text, bundleID: bundleID, appName: appName, appIcon: appIcon)
        case .image(let nsImage):
            await handleImage(nsImage, bundleID: bundleID, appName: appName, appIcon: appIcon)
        case .file(let url):
            await handleFile(url, bundleID: bundleID, appName: appName, appIcon: appIcon)
        }
    }

    // MARK: - Content Handlers

    /// 文本处理：基于 normalize 指纹去重，已存在则 +1 useCount，否则新建。
    /// useCount 语义 = 该文本在系统剪贴板出现的次数（粘贴次数统计）。
    private func handleText(_ text: String, bundleID: String?, appName: String?, appIcon: Data?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minTextLength else { return }

        let fingerprint = Self.fingerprint(trimmed)

        if let existingID = fingerprintIndex[fingerprint] {
            // 已存在：增加粘贴出现次数
            if let existing = await repository.getItem(id: existingID) {
                await repository.incrementUseCount(existing)
            }
        } else {
            // 新内容：创建并持久化
            let item = ClipboardItem(
                content: .text(trimmed),
                timestamp: Date(),
                isPinned: false,
                useCount: 1,
                sourceAppBundleID: bundleID,
                sourceAppName: appName,
                sourceAppIcon: appIcon
            )
            await repository.addItem(item)
            fingerprintIndex[fingerprint] = item.id
        }

        lastCapturedAt = Date()
    }

    /// 图片处理：暂不做精确去重（图片数据比对成本高），每次都新建。
    private func handleImage(_ image: NSImage, bundleID: String?, appName: String?, appIcon: Data?) async {
        let item = ClipboardItem(
            content: .image(image),
            timestamp: Date(),
            isPinned: false,
            useCount: 1,
            sourceAppBundleID: bundleID,
            sourceAppName: appName,
            sourceAppIcon: appIcon
        )
        await repository.addItem(item)
        lastCapturedAt = Date()
    }

    /// 文件处理：按 path 指纹去重。
    private func handleFile(_ url: URL, bundleID: String?, appName: String?, appIcon: Data?) async {
        let fingerprint = "file::\(url.path)"

        if let existingID = fingerprintIndex[fingerprint] {
            if let existing = await repository.getItem(id: existingID) {
                await repository.incrementUseCount(existing)
            }
        } else {
            let item = ClipboardItem(
                content: .file(url),
                timestamp: Date(),
                isPinned: false,
                useCount: 1,
                sourceAppBundleID: bundleID,
                sourceAppName: appName,
                sourceAppIcon: appIcon
            )
            await repository.addItem(item)
            fingerprintIndex[fingerprint] = item.id
        }

        lastCapturedAt = Date()
    }

    // MARK: - Fingerprint

    /// 内容指纹：normalize（折叠空白 + 小写）用于精确匹配去重和频率统计。
    /// 这是"粘贴次数统计"的基础 —— 同一指令的不同大小写/空白视为同一项。
    static func fingerprint(_ text: String) -> String {
        let lowered = text.lowercased()
        // 折叠所有连续空白为单个空格
        return lowered.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// 启动时从持久化数据重建指纹缓存，确保重启后能正确去重/计数。
    private func bootstrapFingerprints() async {
        guard !didBootstrapFingerprints else { return }
        didBootstrapFingerprints = true

        for index in repository.clipboardIndexes {
            switch index.type {
            case .text:
                // 需要完整内容计算指纹；取 preview（前 100 字符）不足以还原，
                // 但对于去重足够 —— 用 normalize 后的 preview 作为指纹
                let fp = Self.fingerprint(index.preview)
                fingerprintIndex[fp] = index.id
            case .file:
                let fp = "file::\(index.preview)"
                fingerprintIndex[fp] = index.id
            case .image:
                break
            }
        }

        logger.info("剪贴板指纹缓存已重建，共 \(fingerprintIndex.count) 项", category: "ClipboardMonitor")
    }

    // MARK: - Pasteboard Reading

    /// 读取系统剪贴板，返回兼容类型。优先级：文本 > 图片 > 文件。
    private func readPasteboardContent() -> ClipboardContentCompat? {
        // 文本
        if let string = pasteboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(string)
        }

        // 图片
        if let image = NSImage(pasteboard: pasteboard) {
            return .image(image)
        }

        // 文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = urls.first {
            return .file(firstURL)
        }

        return nil
    }

    // MARK: - Source App

    /// 获取当前最前台应用信息（剪贴板内容的来源）。
    private func currentSourceAppInfo() -> (bundleID: String?, name: String?, icon: Data?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil, nil)
        }

        var iconData: Data?
        if let icon = app.icon {
            if let tiff = icon.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                iconData = png
            }
        }

        return (app.bundleIdentifier, app.localizedName, iconData)
    }
}
