import SwiftUI
import Combine

/// 现代化剪贴板视图 - 流畅动画和智能交互
struct ModernClipboardView: View {
    @StateObject private var viewModel = ModernClipboardViewModel()
    @Namespace private var clipboardNamespace
    
    // 状态管理
    @State private var selectedItem: UUID?
    @State private var searchText: String = ""
    @State private var showFilters = false
    @State private var showInsights = false
    
    // 动画状态
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 智能洞察面板（覆盖在顶部）
            if showInsights {
                InsightsView()
                    .background(ModernDesignSystem.shared.color(.bgSurface))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            // 过滤器面板
            if showFilters {
                filterPanel
                    .background(ModernDesignSystem.shared.color(.bgSurface))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(9)
            }

            // 内容区域
            contentArea
                .zIndex(1)
        }
        .background(ModernDesignSystem.shared.color(.bgCanvas))
        .onAppear {
            Task { await viewModel.loadInitialData() }
        }
        // 使用原生 Searchable
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search history...")
        .onChange(of: searchText) { _, newValue in
             viewModel.searchText = newValue
        }
        // 使用原生 Toolbar
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    withAnimation(ModernDesignSystem.Motion.snap) {
                        viewModel.toggleMultiSelectMode()
                    }
                }) {
                    Label(
                        "clipboard.multiselect".localized,
                        systemImage: viewModel.isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                .help("clipboard.multiselect_help".localized)

                Button(action: { Task { await viewModel.mergeSelectedToPasteboard() } }) {
                    Label("clipboard.merge".localized, systemImage: "arrow.triangle.merge")
                }
                .disabled(!viewModel.canMerge)
                .help("clipboard.merge_help".localized)

                Button(action: {
                    withAnimation(ModernDesignSystem.Motion.snap) {
                        showInsights.toggle()
                    }
                }) {
                    Label("Insights", systemImage: "sparkles" + (showInsights ? ".fill" : ""))
                }
                .help("clipboard.insights.title".localized)

                Button(action: {
                    withAnimation(ModernDesignSystem.Motion.snap) {
                        showFilters.toggle()
                    }
                }) {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle" + (showFilters ? ".fill" : ""))
                }
                .help("Show/Hide Filters")

                Button(action: { Task { await viewModel.clearUnpinned() } }) {
                    Label("clipboard.clear_unpinned".localized, systemImage: "pin.slash")
                }
                .disabled(viewModel.clipboardItems.isEmpty)
                .help("clipboard.clear_unpinned_help".localized)

                Button(action: { Task { await viewModel.clearAll() } }) {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(viewModel.clipboardItems.isEmpty)
                .help("Clear All History")
            }
        }
    }
    
    // MARK: - 过滤器面板
    
    private var filterPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClipboardContentType.allCases, id: \.self) { type in
                    ModernStatChip(
                        icon: type.icon,
                        label: type.title,
                        value: "", // No count needed here
                        color: viewModel.selectedContentType == type ? type.color : .secondary
                    )
                    .onTapGesture {
                        withAnimation(ModernDesignSystem.Motion.snap) {
                            viewModel.selectedContentType = type
                        }
                    }
                    .opacity(viewModel.selectedContentType == type ? 1 : 0.6)
                }
                
                Divider().frame(height: 20)
                
                ForEach(DateRange.allCases, id: \.self) { range in
                    Text(range.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedDateRange == range ? Color.orange.opacity(0.2) : Color.clear)
                        )
                        .foregroundColor(viewModel.selectedDateRange == range ? .orange : .secondary)
                        .onTapGesture {
                            withAnimation(ModernDesignSystem.Motion.snap) {
                                viewModel.selectedDateRange = range
                            }
                        }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
        }
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - 内容区域
    
    private var contentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    if !viewModel.statistics.isEmpty {
                        statisticsView
                    }
                    
                    if viewModel.filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        clipboardItemsList
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .onChange(of: viewModel.clipboardItems.count) { _, newValue in
                 // Scroll to top on new item logic if needed
            }
        }
    }
    
    private var statisticsView: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.statistics) { stat in
                ModernStatChip(icon: stat.icon, label: stat.title, value: stat.value, color: stat.color)
            }
        }
    }
    
    private var clipboardItemsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.filteredItems) { item in
                ClipboardItemRow(
                    item: item,
                    isSelected: selectedItem == item.id,
                    isMultiSelectMode: viewModel.isMultiSelectMode,
                    isMultiSelected: viewModel.selectedItemIds.contains(item.id),
                    onSelect: {
                        if viewModel.isMultiSelectMode {
                            viewModel.toggleSelection(item)
                        } else {
                            selectedItem = item.id
                        }
                    },
                    onCopy: { Task { await viewModel.copyToClipboard(item) } },
                    onPin: { Task { await viewModel.pinItem(item) } },
                    onDelete: { Task { await viewModel.deleteItem(item) } }
                )
            }
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
            
            Text("No clipboard history")
                .font(.title3)
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
            
            Text("Copy items to see them here")
                .font(.body)
                .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - 子组件

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let isMultiSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 多选指示（多选模式下替换图标）
            if isMultiSelectMode {
                Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isMultiSelected ? .accentColor : ModernDesignSystem.shared.color(.textTertiary))
                    .frame(width: 36, height: 36)
            } else {
                contentIcon
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                contentPreview
                
                HStack {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
                    
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Actions（pin 项目常驻显示 pin 按钮，便于随时取消；多选模式下隐藏单行操作）
            if !isMultiSelectMode && (isHovered || isSelected || item.isPinned) {
                HStack(spacing: 4) {
                    IconButton(
                        icon: item.isPinned ? "pin.fill" : "pin",
                        color: item.isPinned ? .orange : .secondary,
                        action: onPin
                    )
                    IconButton(icon: "doc.on.doc", action: onCopy)
                    IconButton(icon: "trash", color: .red, action: onDelete)
                }
                .transition(.opacity)
            }
        }
        .padding(12)
        .cardStyle(hover: isHovered)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
    }
    
    @MainActor
    private var contentIcon: some View {
        switch item.content {
        case .text:
            return AnyView(Image(systemName: "text.alignleft").foregroundColor(.blue))
        case .image:
            return AnyView(Image(systemName: "photo").foregroundColor(.orange))
        case .file:
            return AnyView(Image(systemName: "doc").foregroundColor(.green))
        }
    }
    
    @MainActor
    private var contentPreview: some View {
        Group {
            switch item.content {
            case .text(let text):
                Text(text.replacingOccurrences(of: "\n", with: " "))
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
                    .lineLimit(1)
            case .image:
                Text("Image")
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
                    .italic()
            case .file(let url):
                Text(url.lastPathComponent)
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
            }
        }
    }
    
    private var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.timestamp, relativeTo: Date())
    }
}

struct IconButton: View {
    let icon: String
    var color: Color = .secondary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .hoverScaleEffect()
    }
}
