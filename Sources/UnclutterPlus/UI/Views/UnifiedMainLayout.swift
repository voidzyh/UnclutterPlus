import SwiftUI
import Combine

/// 统一的主布局视图 (v2.0 Redesign)
/// 采用 macOS 标准 NavigationSplitView 实现三栏/双栏布局
struct UnifiedMainLayout: View {
    @StateObject private var navigationModel = UnifiedNavigationModel()
    @StateObject private var designSystem = ModernDesignSystem.shared
    
    // 侧边栏可见性
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar
            UnifiedSidebar(selection: $navigationModel.selectedTab)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                .toolbar {
                    // 侧边栏底部的设置按钮可以通过 ToolbarItem(placement: .bottomBar) 实现，
                    // 或者直接放在 Sidebar List 的底部
                }
        } detail: {
            // MARK: - Detail / Content
            ZStack {
                // 背景层
                designSystem.color(.bgCanvas)
                    .ignoresSafeArea()
                
                // 内容切换
                switch navigationModel.selectedTab {
                case .files:
                    ModernFilesView() // 后续需要适配为 Toolbar 模式
                case .clipboard:
                    ModernClipboardView()
                case .notes:
                    ModernNotesView()
                case .screenshots:
                    ScreenshotsView()
                }
            }
            .toolbar {
                // 全局通用的 Toolbar Items (如搜索) 可以在这里注入，
                // 但最好由各个子视图自己定义 .toolbar
            }
        }
        .navigationTitle(navigationModel.selectedTab.title)
        // 移除硬编码的 frame，允许窗口自由缩放
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - Navigation Model

enum AppTab: String, CaseIterable, Identifiable {
    case files
    case clipboard
    case notes
    case screenshots
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .files: return "Files"
        case .clipboard: return "Clipboard"
        case .notes: return "Notes"
        case .screenshots: return "Screenshots"
        }
    }
    
    var icon: String {
        switch self {
        case .files: return "folder"
        case .clipboard: return "doc.on.clipboard"
        case .notes: return "note.text"
        case .screenshots: return "camera.viewfinder"
        }
    }
}

class UnifiedNavigationModel: ObservableObject {
    @Published var selectedTab: AppTab = .files
}

// MARK: - Unified Sidebar

struct UnifiedSidebar: View {
    @Binding var selection: AppTab
    
    var body: some View {
        List(selection: $selection) {
            Section(header: Text("Library")) {
                ForEach(AppTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(tab.title)
                        } icon: {
                            Image(systemName: tab.icon)
                                .foregroundStyle(selection == tab ? Color.accentColor : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.sidebar)
        // 底部设置入口
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                NotificationCenter.default.post(name: .showPreferences, object: nil)
            }) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial)
        }
    }
}
