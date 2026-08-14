import SwiftUI

/// 主界面功能标签页 - 集中定义标识、本地化标题、图标与主题色，消除散落的 magic string
enum AppTab: String, CaseIterable, Identifiable {
    case files
    case clipboard
    case notes
    case screenshots

    var id: String { rawValue }

    /// 本地化标题（对应 Localizable.strings 的 tab.* key）
    var title: String { "tab.\(rawValue)".localized }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .files: return "folder"
        case .clipboard: return "doc.on.clipboard"
        case .notes: return "note.text"
        case .screenshots: return "camera.viewfinder"
        }
    }

    /// 主题色（与偏好设置 TabOrderEditor 保持一致）
    var color: Color {
        switch self {
        case .files: return .blue
        case .clipboard: return .green
        case .notes: return .orange
        case .screenshots: return .purple
        }
    }
}
