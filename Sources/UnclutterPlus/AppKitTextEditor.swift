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
        
        // NSTextView 默认就接收键盘事件，无需设置
        
        // 在初始化后立即尝试获取焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = textView.window {
                window.makeFirstResponder(textView)
                print("TextEditor: Attempting to become first responder")
            }
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        // 每次更新时都尝试获取焦点
        if let window = textView.window, window.isKeyWindow {
            DispatchQueue.main.async {
                window.makeFirstResponder(textView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: AppKitTextEditor
        
        init(_ parent: AppKitTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            DispatchQueue.main.async {
                self.parent.text = textView.string
                self.parent.onTextChange?(textView.string)
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