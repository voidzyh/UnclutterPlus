import SwiftUI
import AppKit

struct AppKitTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    var onTextChange: ((String) -> Void)?
    var scrollToRange: NSRange? = nil  // 新增：滚动到指定范围

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // 设置文本视图属性
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // 中文输入法支持
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesFindBar = true
        textView.usesInspectorBar = false
        
        // 字体和颜色设置
        textView.font = font
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.textColor
        
        // 设置文本容器属性
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        
        // 设置滚动视图
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        // 设置代理
        textView.delegate = context.coordinator
        
        // 初始文本
        textView.string = text
        
        // 不自动获取焦点，让用户点击时才获取
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 检查是否正在输入法组合输入过程中
        let hasMarkedText = textView.hasMarkedText()

        // 获取当前文本和新文本
        let currentText = textView.string
        let newText = text

        // 检查是否是第一响应者
        let isFirstResponder = textView.window?.firstResponder == textView

        // 只在必要时更新文本，避免光标跳转
        let shouldUpdate = currentText != newText &&
                          !hasMarkedText &&
                          !context.coordinator.isUpdating &&
                          !isFirstResponder // 如果正在编辑则不更新

        if shouldUpdate {
            // 保存当前光标位置和选择范围
            let selectedRange = textView.selectedRange()
            let wasFirstResponder = isFirstResponder

            // 更新文本
            textView.string = newText

            // 恢复光标位置和焦点状态
            if wasFirstResponder {
                // 确保光标位置在有效范围内
                let safeLocation = min(selectedRange.location, newText.count)
                let safeLength = min(selectedRange.length, newText.count - safeLocation)
                let safeRange = NSRange(location: safeLocation, length: max(0, safeLength))

                textView.setSelectedRange(safeRange)

                // 恢复第一响应者状态
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }
        }

        // 处理滚动到指定范围
        if let range = scrollToRange, range.location < textView.string.count {
            scrollToRangeInTextView(textView: textView, range: range, scrollView: scrollView)
        }
    }

    /// 滚动到指定文本范围（使用现代且无弃用的 API）
    private func scrollToRangeInTextView(textView: NSTextView, range: NSRange, scrollView: NSScrollView) {
        // 计算目标位置的矩形
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let clipView = scrollView.contentView

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // 计算目标滚动点（向上偏移 50px，使目标不在最顶部）
        let targetY = max(0, rect.minY - 50)
        let targetPoint = NSPoint(x: 0, y: targetY)

        // 直接使用 NSClipView 的 boundsOrigin 属性（这是现代推荐的方式）
        // 让系统自动处理约束
        let currentOrigin = clipView.bounds.origin
        let documentView = scrollView.documentView
        let documentBounds = documentView?.bounds ?? .zero

        // 确保不超出文档范围
        let maxY = max(0, documentBounds.height - clipView.bounds.height)
        let constrainedY = min(max(targetPoint.y, 0), maxY)

        // 平滑滚动到目标位置
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            clipView.animator().setBoundsOrigin(NSPoint(x: currentOrigin.x, y: constrainedY))
        }

        // 高亮显示该范围
        textView.setSelectedRange(range)

        // 短暂延迟后清除选择
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            textView.setSelectedRange(NSRange(location: range.location + range.length, length: 0))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: AppKitTextEditor
        fileprivate var isUpdating = false
        
        init(_ parent: AppKitTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 避免循环更新
            guard !isUpdating else { return }
            
            // 如果正在输入法组合输入，暂时不更新
            guard !textView.hasMarkedText() else { return }
            
            // 使用更短的延迟来减少光标跳转
            isUpdating = true
            
            DispatchQueue.main.async {
                // 再次检查以确保安全
                guard !textView.hasMarkedText() else {
                    self.isUpdating = false
                    return
                }
                
                let newText = textView.string
                if self.parent.text != newText {
                    self.parent.text = newText
                    self.parent.onTextChange?(newText)
                }
                
                self.isUpdating = false
            }
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            return true
        }
        
        // 处理输入法相关事件
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // 让系统处理输入法相关命令
            return false
        }
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    struct PreviewWrapper: View {
        @State private var text = "Hello, World!\n\nThis is a test of the AppKit text editor."
        
        var body: some View {
            AppKitTextEditor(text: $text) { newText in
                logger.debug("Text changed: \(newText)", category: "AppKitTextEditor")
            }
            .frame(width: 400, height: 300)
        }
    }
    
    return PreviewWrapper()
}
#endif