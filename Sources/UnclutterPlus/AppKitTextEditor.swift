import SwiftUI
import AppKit

struct AppKitTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    var onTextChange: ((String) -> Void)?
    
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
        
        // 只在文本真正不同时才更新，避免重置光标
        if textView.string != text {
            // 保存当前光标位置
            let selectedRange = textView.selectedRange()
            
            textView.string = text
            
            // 恢复光标位置（如果在有效范围内）
            if selectedRange.location <= text.count {
                let newRange = NSRange(
                    location: min(selectedRange.location, text.count),
                    length: 0
                )
                textView.setSelectedRange(newRange)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: AppKitTextEditor
        private var isUpdating = false
        
        init(_ parent: AppKitTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 避免循环更新
            guard !isUpdating else { return }
            
            DispatchQueue.main.async {
                self.isUpdating = true
                self.parent.text = textView.string
                self.parent.onTextChange?(textView.string)
                self.isUpdating = false
            }
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            return true
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = "Hello, World!\n\nThis is a test of the AppKit text editor."
        
        var body: some View {
            AppKitTextEditor(text: $text) { newText in
                print("Text changed: \(newText)")
            }
            .frame(width: 400, height: 300)
        }
    }
    
    return PreviewWrapper()
}