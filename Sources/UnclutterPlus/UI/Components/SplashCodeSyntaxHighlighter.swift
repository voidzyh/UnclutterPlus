import SwiftUI
import MarkdownUI
import Splash

struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    let theme: Splash.Theme

    func highlightCode(_ code: String, language: String?) -> Text {
        // Use Splash to produce an NSAttributedString; convert to SwiftUI AttributedString
        let format = AttributedStringOutputFormat(theme: theme)
        let highlighter = SyntaxHighlighter(format: format)
        let nsAttr = highlighter.highlight(code)
        let swiftAttr = AttributedString(nsAttr)
        return Text(swiftAttr)
    }
}

extension CodeSyntaxHighlighter where Self == SplashCodeSyntaxHighlighter {
    static func splash(theme: Splash.Theme) -> Self {
        SplashCodeSyntaxHighlighter(theme: theme)
    }
}
