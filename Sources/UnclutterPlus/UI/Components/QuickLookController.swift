import AppKit
import Quartz

/// Quick Look 预览控制器 —— 供 Files 面板暂存文件快速预览。
///
/// QLPreviewPanel 是 AppKit 全局单例；本控制器持有当前预览 URL，
/// 面板的数据源/代理委托给它。再次调用时切换预览目标或收起面板。
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    private var currentURL: URL?

    private override init() {}

    /// 预览指定文件：面板未显示则弹出，已显示同一文件则收起。
    func togglePreview(for url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible && currentURL == url {
            panel.orderOut(nil)
            currentURL = nil
            return
        }

        currentURL = url
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        currentURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard let url = currentURL else { return nil }
        return NSURL(fileURLWithPath: url.path)
    }

    // MARK: - QLPreviewPanelDelegate

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        NSRect(x: 0, y: 0, width: 0, height: 0)
    }
}
