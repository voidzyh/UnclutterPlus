import SwiftUI
import Cocoa

/// 菜单栏迷你速记窗口管理器（Tot 式快速入口）。
/// 从菜单栏一键唤起小窗速记，⌘↩︎ 保存为笔记、Esc 关闭。
final class QuickNoteWindowManager {
    static let shared = QuickNoteWindowManager()

    private var windowController: NSWindowController?

    private init() {}

    func show() {
        // 已存在则激活复用
        if let windowController = windowController, let window = windowController.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: QuickNoteView(onClose: { [weak self] in
            self?.hide()
        }))
        let window = NSPanel(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .nonactivatingPanel, .fullSizeContentView]
        window.title = "quicknote.title".localized
        window.level = .floating
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 440, height: 200))
        window.center()

        windowController = NSWindowController(window: window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        windowController?.window?.orderOut(nil)
    }
}

/// 迷你速记视图
struct QuickNoteView: View {
    let onClose: () -> Void

    @State private var content: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            TextEditor(text: $content)
                .font(.body)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .onKeyPress(.escape) {
                    onClose()
                    return .handled
                }

            HStack {
                Text("quicknote.hint".localized)
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
                Spacer()
                Button("quicknote.cancel".localized) { onClose() }
                    .keyboardShortcut(.cancelAction)
                Button("quicknote.save".localized) { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(ModernDesignSystem.shared.color(.bgCanvas))
        .onAppear { isFocused = true }
    }

    private func save() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onClose()
            return
        }

        let title = Self.title(for: trimmed)
        Task {
            _ = await AppStorageManager.shared.notesService.createNote(title: title, content: trimmed)
        }
        onClose()
    }

    /// 从内容生成标题：首行截断 30 字符，空内容回退默认标题（纯函数，便于测试）
    static func title(for content: String) -> String {
        let firstLine = content
            .split(separator: "\n", maxSplits: 1)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        guard !firstLine.isEmpty else { return "quicknote.default_title".localized }
        return String(firstLine.prefix(30))
    }
}
