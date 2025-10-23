import SwiftUI
import Cocoa

struct MainContentView: View {
    @StateObject private var viewModel = MainContentViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器区域
            ZStack {
                // 居中的标签页按钮
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.enabledTabs.enumerated()), id: \.element) { index, tabId in
                        TabButton(
                            title: getTabTitle(for: tabId),
                            systemImage: getTabIcon(for: tabId),
                            isSelected: viewModel.selectedTab == index
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedTab = index
                            }
                        }
                    }
                }
                
                // 右侧的设置按钮
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.showPreferences()
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("button.preferences".localized)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // 内容区域
            Group {
                if !viewModel.hasEnabledTabs {
                    // 没有启用任何功能时显示提示
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("features.no_enabled.title".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("features.no_enabled.description".localized)
                            .foregroundColor(.secondary)

                        Button("features.open_settings".localized) {
                            viewModel.showPreferences()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 根据启用的功能显示对应内容
                    if let tabId = viewModel.tabIdentifier(at: viewModel.selectedTab) {
                        switch tabId {
                        case "files":
                            FilesView()
                                .transition(.opacity)
                        case "clipboard":
                            ClipboardView()
                                .transition(.opacity)
                        case "notes":
                            NotesView()
                                .transition(.opacity)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTab)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(radius: 20)
        )
        .padding(8)
        .id(viewModel.refreshToken) // 强制刷新视图
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            viewModel.forceRefreshForLocalizationChange()
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 应用激活时检查配置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.handleAppDidBecomeActive()
            }
        }
    }
    
    // 获取标签页标题
    private func getTabTitle(for tabId: String) -> String {
        switch tabId {
        case "files":
            return "tab.files".localized
        case "clipboard":
            return "tab.clipboard".localized
        case "notes":
            return "tab.notes".localized
        default:
            return ""
        }
    }
    
    // 获取标签页图标
    private func getTabIcon(for tabId: String) -> String {
        switch tabId {
        case "files":
            return "folder"
        case "clipboard":
            return "doc.on.clipboard"
        case "notes":
            return "note.text"
        default:
            return ""
        }
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.1) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered && !isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: isHovered ? Color.black.opacity(0.1) : Color.clear, radius: 2, x: 0, y: 1)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

// 扩展Button以支持按下事件
extension View {
    func pressEvents(onPress: @escaping () -> Void = {}, onRelease: @escaping () -> Void = {}) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    MainContentView()
        .frame(width: 800, height: 300)
}
#endif
