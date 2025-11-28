import SwiftUI

/// Markdown 主题 - 简化版本以修复构建错误
struct Theme {
    let text: TextStyle
    let code: CodeStyle
    let strong: TextStyle
    let emphasis: TextStyle
    let heading1: TextStyle
    let heading2: TextStyle
    let heading3: TextStyle
    let heading4: TextStyle
    let heading5: TextStyle
    let heading6: TextStyle
    let blockquote: BlockquoteStyle
    let codeBlock: CodeBlockStyle
    let listItem: TextStyle
    let link: LinkStyle
    
    struct TextStyle {
        let font: Font
    }
    
    struct CodeStyle {
        let font: Font
        let backgroundColor: Color
    }
    
    struct BlockquoteStyle {
        let font: Font
        let backgroundColor: Color
    }
    
    struct CodeBlockStyle {
        let font: Font
        let backgroundColor: Color
    }
    
    struct LinkStyle {
        let font: Font
        let color: Color
    }
}