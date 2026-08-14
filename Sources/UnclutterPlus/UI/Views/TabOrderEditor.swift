import SwiftUI
import Combine

// MARK: - Tab Order Editor Component
struct TabOrderEditor: View {
    @Binding var order: String
     @Binding var defaultTab: String
     @Binding var isFilesEnabled: Bool
     @Binding var isClipboardEnabled: Bool
     @Binding var isNotesEnabled: Bool
     @State private var tabItems: [TabItem] = []
     @ObservedObject var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("preferences.tabs.order.help".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            
            ForEach(tabItems.indices, id: \.self) { index in
                HStack(spacing: 10) {
                        // 序号徽章
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .accessibilityLabel("\("preferences.tabs.order.index".localized) \(index + 1)")
                    
                    // 图标 + 标题
                    HStack(spacing: 6) {
                        Image(systemName: tabItems[index].systemImage)
                            .foregroundColor(tabItems[index].color)
                            .font(.system(size: 12))
                        Text(tabItems[index].title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer(minLength: 8)
                    
                    // 功能启用开关
                    enableToggle(for: tabItems[index].id)
                    
                    // 设为默认星标（仅当启用时可用）
                    Button(action: { defaultTab = tabItems[index].id }) {
                        Image(systemName: defaultTab == tabItems[index].id ? "star.fill" : "star")
                            .foregroundColor(defaultTab == tabItems[index].id ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isEnabled(for: tabItems[index].id))
                    .help("preferences.tabs.default.make_default".localized)
                    
                    // 上/下移动（仅当启用时参与排序）
                    HStack(spacing: 4) {
                        Button(action: { moveTabUp(from: index) }) {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .foregroundColor(index > 0 ? .primary : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        
                        Button(action: { moveTabDown(from: index) }) {
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(index < tabItems.count - 1 ? .primary : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == tabItems.count - 1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                 .overlay(
                     RoundedRectangle(cornerRadius: 8)
                         .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                 )
             }
             .onAppear {
                 loadTabItems()
             }
             .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                 loadTabItems()
             }

             HStack(spacing: 8) {
                 Button("preferences.tabs.order.reset".localized) { resetToDefaultOrder() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
                Spacer()
                // 预览徽章（仅显示启用的）
                HStack(spacing: 6) {
                    ForEach(tabItems.filter { isEnabled(for: $0.id) }, id: \.id) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.systemImage)
                                .foregroundColor(item.color)
                            Text(item.title)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.06), in: Capsule())
                    }
                }
            }
        }
        .onAppear { loadTabItems() }
        .onChange(of: order) { _, _ in loadTabItems() }
        .onChange(of: isFilesEnabled) { _, _ in clampDefaultAndOrder() }
        .onChange(of: isClipboardEnabled) { _, _ in clampDefaultAndOrder() }
        .onChange(of: isNotesEnabled) { _, _ in clampDefaultAndOrder() }
    }
    
    @ViewBuilder
    private func enableToggle(for id: String) -> some View {
        switch id {
        case "files": Toggle("", isOn: $isFilesEnabled).labelsHidden().help("preferences.features.enable_files".localized)
        case "clipboard": Toggle("", isOn: $isClipboardEnabled).labelsHidden().help("preferences.features.enable_clipboard".localized)
        case "notes": Toggle("", isOn: $isNotesEnabled).labelsHidden().help("preferences.features.enable_notes".localized)
        default: EmptyView()
        }
    }
    
    private func isEnabled(for id: String) -> Bool {
        switch id {
        case "files": return isFilesEnabled
        case "clipboard": return isClipboardEnabled
        case "notes": return isNotesEnabled
        default: return false
        }
    }
    
    private func loadTabItems() {
        let orderArray = order.components(separatedBy: ",")
        tabItems = orderArray.compactMap { tabId in
            switch tabId { case "files": return TabItem(id: "files", title: "tab.files".localized, systemImage: "folder", color: .blue)
            case "clipboard": return TabItem(id: "clipboard", title: "tab.clipboard".localized, systemImage: "doc.on.clipboard", color: .green)
            case "notes": return TabItem(id: "notes", title: "tab.notes".localized, systemImage: "note.text", color: .orange)
            default: return nil }
        }
    }
    
    private func moveTabUp(from index: Int) {
        guard index > 0 else { return }
        tabItems.swapAt(index, index - 1)
        updateOrder()
    }
    
    private func moveTabDown(from index: Int) {
        guard index < tabItems.count - 1 else { return }
        tabItems.swapAt(index, index + 1)
        updateOrder()
    }
    
    private func resetToDefaultOrder() {
        tabItems = [
            TabItem(id: "files", title: "tab.files".localized, systemImage: "folder", color: .blue),
            TabItem(id: "clipboard", title: "tab.clipboard".localized, systemImage: "doc.on.clipboard", color: .green),
            TabItem(id: "notes", title: "tab.notes".localized, systemImage: "note.text", color: .orange)
        ]
        if !isEnabled(for: defaultTab) { defaultTab = tabItems.first(where: { isEnabled(for: $0.id) })?.id ?? "files" }
        updateOrder()
    }
    
    private func updateOrder() {
        let newOrder = tabItems.map { $0.id }.joined(separator: ",")
        order = newOrder
        // 如果默认标签对应功能被关闭，降级为第一个启用项
        if !isEnabled(for: defaultTab) {
            defaultTab = tabItems.first(where: { isEnabled(for: $0.id) })?.id ?? "files"
        }
    }
    
    private func clampDefaultAndOrder() {
        // 关闭的功能仍保留在顺序中，但默认与预览仅依据启用项
        if !isEnabled(for: defaultTab) {
            defaultTab = tabItems.first(where: { isEnabled(for: $0.id) })?.id ?? "files"
        }
    }
}

struct TabItem {
    let id: String
    let title: String
    let systemImage: String
    let color: Color
}