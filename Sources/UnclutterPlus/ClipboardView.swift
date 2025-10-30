import SwiftUI

struct ClipboardView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    @State private var hoveredItem: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack(spacing: DesignSystem.Spacing.md) {
                // 搜索栏
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .font(DesignSystem.Typography.caption)

                    TextField("clipboard.search.placeholder".localized, text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .font(DesignSystem.Typography.caption)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.overlay, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))

                // 过滤和排序控件
                HStack(spacing: DesignSystem.Spacing.md) {
                    // 类型过滤
                    FilterToolbarButton(
                        icon: "doc.text",
                        isActive: viewModel.selectedContentType != "all",
                        isHovered: viewModel.hoveredToolbar == "type",
                        accentColor: .blue,
                        onToggle: {
                            if viewModel.showTypeFilter {
                                viewModel.showTypeFilter = false
                            } else {
                                viewModel.showTypeFilter = true
                                viewModel.showDateFilter = false
                                viewModel.showSourceFilter = false
                                viewModel.showSortFilter = false
                            }
                        },
                        onHover: { isHover in
                            viewModel.hoveredToolbar = isHover ? "type" : (viewModel.hoveredToolbar == "type" ? nil : viewModel.hoveredToolbar)
                        }
                    )

                    // 日期过滤
                    FilterToolbarButton(
                        icon: "calendar",
                        isActive: viewModel.selectedDateRange != "all",
                        isHovered: viewModel.hoveredToolbar == "date",
                        accentColor: .red,
                        onToggle: {
                            if viewModel.showDateFilter {
                                viewModel.showDateFilter = false
                            } else {
                                viewModel.showTypeFilter = false
                                viewModel.showDateFilter = true
                                viewModel.showSourceFilter = false
                                viewModel.showSortFilter = false
                            }
                        },
                        onHover: { isHover in
                            viewModel.hoveredToolbar = isHover ? "date" : (viewModel.hoveredToolbar == "date" ? nil : viewModel.hoveredToolbar)
                        }
                    )

                    // 来源过滤
                    FilterToolbarButton(
                        icon: "app.badge",
                        isActive: viewModel.selectedSourceApp != "all",
                        isHovered: viewModel.hoveredToolbar == "source",
                        accentColor: .purple,
                        onToggle: {
                            if viewModel.showSourceFilter {
                                viewModel.showSourceFilter = false
                            } else {
                                viewModel.showTypeFilter = false
                                viewModel.showDateFilter = false
                                viewModel.showSourceFilter = true
                                viewModel.showSortFilter = false
                            }
                        },
                        onHover: { isHover in
                            viewModel.hoveredToolbar = isHover ? "source" : (viewModel.hoveredToolbar == "source" ? nil : viewModel.hoveredToolbar)
                        }
                    )

                    // 排序
                    FilterToolbarButton(
                        icon: "arrow.up.arrow.down",
                        isActive: viewModel.sortBy != "time",
                        isHovered: viewModel.hoveredToolbar == "sort",
                        accentColor: .indigo,
                        onToggle: {
                            if viewModel.showSortFilter {
                                viewModel.showSortFilter = false
                            } else {
                                viewModel.showTypeFilter = false
                                viewModel.showDateFilter = false
                                viewModel.showSourceFilter = false
                                viewModel.showSortFilter = true
                            }
                        },
                        onHover: { isHover in
                            viewModel.hoveredToolbar = isHover ? "sort" : (viewModel.hoveredToolbar == "sort" ? nil : viewModel.hoveredToolbar)
                        }
                    )
                }
                .padding(DesignSystem.Spacing.sm + 2)
                .background(DesignSystem.Colors.overlay.opacity(0.5), in: RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm + 2))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm + 2)
                        .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
                )

                // 下拉面板(在工具栏下方划出)
                if viewModel.showTypeFilter || viewModel.showDateFilter || viewModel.showSourceFilter || viewModel.showSortFilter {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                        if viewModel.showTypeFilter {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(title: "clipboard.filter.all".localized, icon: "square.grid.2x2", isSelected: viewModel.selectedContentType == "all", color: .blue) { viewModel.selectedContentType = "all" }
                                    FilterChip(title: "clipboard.filter.text".localized, icon: "doc.plaintext", isSelected: viewModel.selectedContentType == "text", color: .blue) { viewModel.selectedContentType = "text" }
                                    FilterChip(title: "clipboard.filter.image".localized, icon: "photo", isSelected: viewModel.selectedContentType == "image", color: .green) { viewModel.selectedContentType = "image" }
                                    FilterChip(title: "clipboard.filter.file".localized, icon: "doc", isSelected: viewModel.selectedContentType == "file", color: .orange) { viewModel.selectedContentType = "file" }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if viewModel.showDateFilter {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(title: "clipboard.filter.all".localized, icon: "calendar", isSelected: viewModel.selectedDateRange == "all", color: .red) { viewModel.selectedDateRange = "all" }
                                    FilterChip(title: "clipboard.filter.today".localized, icon: "sun.max", isSelected: viewModel.selectedDateRange == "today", color: .red) { viewModel.selectedDateRange = "today" }
                                    FilterChip(title: "clipboard.filter.week".localized, icon: "clock", isSelected: viewModel.selectedDateRange == "week", color: .red) { viewModel.selectedDateRange = "week" }
                                    FilterChip(title: "clipboard.filter.month".localized, icon: "calendar", isSelected: viewModel.selectedDateRange == "month", color: .red) { viewModel.selectedDateRange = "month" }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if viewModel.showSourceFilter {
                            HStack(spacing: 8) {
                                FilterChip(title: "clipboard.filter.all".localized, isSelected: viewModel.selectedSourceApp == "all", color: .purple) { viewModel.selectedSourceApp = "all" }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(Set(viewModel.items.compactMap { $0.sourceAppBundleID })).sorted(), id: \.self) { bundleID in
                                            if let item = viewModel.items.first(where: { $0.sourceAppBundleID == bundleID }),
                                               let iconData = item.sourceAppIcon,
                                               let image = NSImage(data: iconData) {
                                                Button(action: { viewModel.selectedSourceApp = bundleID }) {
                                                    Image(nsImage: image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 22, height: 22)
                                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 5)
                                                                .strokeBorder(
                                                                    viewModel.selectedSourceApp == bundleID ? Color.purple.opacity(0.6) : Color.secondary.opacity(0.3),
                                                                    lineWidth: viewModel.selectedSourceApp == bundleID ? 2 : 1
                                                                )
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                                .help(item.sourceAppName ?? bundleID)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                Button("common.cancel".localized) { viewModel.showSourceFilter = false }
                                    .buttonStyle(.borderless)
                            }
                        }

                        if viewModel.showSortFilter {
                            HStack(spacing: 8) {
                                SortButton(title: "clipboard.sort.time".localized, icon: "clock", isSelected: viewModel.sortBy == "time") { viewModel.sortBy = "time" }
                                SortButton(title: "clipboard.sort.use_count".localized, icon: "number.circle", isSelected: viewModel.sortBy == "useCount") { viewModel.sortBy = "useCount" }
                                Spacer()
                            }
                        }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                        )
                        .frame(maxWidth: 420, alignment: .leading)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.18), value: viewModel.showTypeFilter || viewModel.showDateFilter || viewModel.showSourceFilter || viewModel.showSortFilter)
                }

                Spacer()

                // 多选模式切换
                Button(action: {
                    viewModel.toggleMultiSelectMode()
                }) {
                    Image(systemName: viewModel.isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(viewModel.isMultiSelectMode ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(viewModel.isMultiSelectMode ? "clipboard.multi_select.exit".localized : "clipboard.multi_select.enter".localized)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if viewModel.isLoading {
                // 加载动画
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle())

                    Text("正在加载剪贴板历史...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredItems.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: viewModel.searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text(viewModel.searchText.isEmpty ? "clipboard.empty.title".localized : "clipboard.empty.search.title".localized)
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text(viewModel.searchText.isEmpty ? "ui.copy_something_to_see".localized : "ui.try_different_search".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 剪贴板项目列表
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredItems, id: \.id) { item in
                            let index = viewModel.filteredItems.firstIndex(of: item) ?? 0
                            ClipboardItemView(
                                item: item,
                                isSelected: viewModel.selectedItems.contains(item.id),
                                isHovered: hoveredItem == item.id,
                                showSelectionMode: viewModel.isMultiSelectMode,
                                indexNumber: index < 9 ? index + 1 : nil
                            ) {
                                // 复制操作
                                viewModel.copyItem(item)
                                WindowManager.shared.hideWindowAfterAction(.clipboardCopied)
                            } onDelete: {
                                viewModel.removeItem(item)
                            } onTogglePin: {
                                viewModel.togglePin(item)
                            } onToggleSelection: {
                                viewModel.toggleSelection(item)
                            }
                            .onHover { isHovering in
                                hoveredItem = isHovering ? item.id : nil
                            }
                        }
                    }
                    .padding()
                }
            }

            // 底部工具栏
            HStack {
                if viewModel.isMultiSelectMode && !viewModel.selectedItems.isEmpty {
                    Button("clipboard.multi_select.delete_selected".localized + " (\(viewModel.selectedItems.count))") {
                        viewModel.deleteSelected()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                } else {
                    Button("clipboard.multi_select.clear_all".localized) {
                        viewModel.clearAll()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text("\(viewModel.filteredItems.count) \("clipboard.multi_select.items".localized)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isMultiSelectMode {
                    Text("|")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(viewModel.selectedItems.count) \("clipboard.multi_select.selected".localized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onKeyDown { event in
            handleKeyDown(event)
        }
        .task {
            viewModel.onAppear()
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags

        // 数字键快速复制(1-9)
        if keyCode >= 18 && keyCode <= 26 && !modifierFlags.contains(.command) {
            let index = Int(keyCode - 18)
            if index < viewModel.filteredItems.count {
                viewModel.copyItem(viewModel.filteredItems[index])
                WindowManager.shared.hideWindowAfterAction(.clipboardCopied)
                return true
            }
        }

        // Delete 键删除选中项
        if keyCode == 51 { // Delete key
            if !viewModel.selectedItems.isEmpty {
                viewModel.deleteSelected()
                return true
            }
        }

        // Cmd+A 全选
        if keyCode == 0 && modifierFlags.contains(.command) { // Cmd+A
            if viewModel.isMultiSelectMode {
                viewModel.selectAll()
                return true
            }
        }

        return false
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovered: Bool
    let showSelectionMode: Bool
    let indexNumber: Int?
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onToggleSelection: () -> Void

    @State private var showFullText = false

    var body: some View {
        HStack(spacing: 12) {
            // 选择框/使用频次标签
            if showSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            } else {
                // 使用频次标签
                Text("\(item.useCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 20)
                    .background(.tertiary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.secondary.opacity(0.3), lineWidth: 0.5)
                    )
            }

            // 内容预览
            VStack(alignment: .leading, spacing: 6) {
                switch item.content {
                case .text(let text):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(showFullText ? text : item.preview)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(showFullText ? nil : 3)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)

                        if text.count > 100 {
                            Button(showFullText ? "clipboard.item.collapse".localized : "clipboard.item.expand".localized) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showFullText.toggle()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }

                case .image(let image):
                    VStack(alignment: .leading, spacing: 8) {
                        // 图片预览
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                        // 图片信息
                        HStack {
                            Text("clipboard.item.image.content".localized)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            Spacer()

                            // 显示图片尺寸
                            let size = image.size
                            Text("\(Int(size.width))×\(Int(size.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tertiary.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }

                case .file(let url):
                    HStack {
                        Text(url.lastPathComponent)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }

                // 时间戳和详情
                HStack {
                    // 类型图标和置顶状态
                    HStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.caption)
                            .foregroundColor(item.typeColor)
                            .frame(width: 16)

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 来源应用信息
                    if let appName = item.sourceAppName {
                        HStack(spacing: 4) {
                            if let iconData = item.sourceAppIcon,
                               let image = NSImage(data: iconData) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }

                            Text(appName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(item.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if case .text(let text) = item.content {
                        Spacer()
                        Text("\(text.count) \("clipboard.item.characters".localized)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 操作按钮(悬停显示)
            if isHovered || showSelectionMode {
                HStack(spacing: 8) {
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 14))
                            .foregroundColor(item.isPinned ? .orange : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(item.isPinned ? "clipboard.item.unpin".localized : "clipboard.item.pin".localized)

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("clipboard.item.copy".localized)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("clipboard.item.delete".localized)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(backgroundMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 1)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .onTapGesture {
            if showSelectionMode {
                onToggleSelection()
            } else {
                onCopy()
            }
        }
        .contextMenu {
            Button(item.isPinned ? "clipboard.item.unpin".localized : "clipboard.item.pin".localized) {
                onTogglePin()
            }

            Divider()

            Button("clipboard.item.copy".localized) {
                onCopy()
            }

            Button("clipboard.item.delete".localized, role: .destructive) {
                onDelete()
            }
        }
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }

    private var backgroundMaterial: Material {
        if isSelected {
            return .thick
        } else if item.isPinned {
            return .thinMaterial
        } else {
            return .thinMaterial
        }
    }

    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if item.isPinned {
            return .orange.opacity(0.3)
        } else {
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        if isSelected {
            return 2
        } else if item.isPinned {
            return 1
        } else {
            return 0
        }
    }

    private var shadowColor: Color {
        if isSelected {
            return .accentColor.opacity(0.3)
        } else {
            return .black.opacity(0.1)
        }
    }

    private var shadowRadius: CGFloat {
        isSelected ? 4 : 1
    }
}

// MARK: - Key Event Handling Extension
extension View {
    func onKeyDown(perform action: @escaping (NSEvent) -> Bool) -> some View {
        self.background(KeyEventHandlingView(onKeyDown: action))
    }
}

struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlingNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyHandlingNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if let onKeyDown = onKeyDown, onKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Filter Components
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected ? color.opacity(0.15) : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? color.opacity(0.4) : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .foregroundColor(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct SortButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected ? Color.indigo.opacity(0.15) : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.indigo.opacity(0.4) : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .foregroundColor(isSelected ? Color.indigo : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - 过滤按钮组件

/// 过滤工具栏按钮
struct FilterToolbarButton: View {
    let icon: String
    let isActive: Bool
    let isHovered: Bool
    let accentColor: Color
    let onToggle: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundColor(foregroundColor)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small + 2)
                            .fill(backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small + 2)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    .scaleEffect(scaleEffect)
                    .animation(DesignSystem.Animation.spring, value: isHovered)
                    .animation(DesignSystem.Animation.spring, value: isActive)

                // 激活指示器
                if isActive {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
    }

    // MARK: - 计算属性：状态驱动的样式

    private var foregroundColor: Color {
        isActive ? accentColor : (isHovered ? DesignSystem.Colors.primaryText : DesignSystem.Colors.primaryText)
    }

    private var backgroundColor: Color {
        if isActive {
            return accentColor.opacity(0.15)
        } else if isHovered {
            return DesignSystem.Colors.overlay
        } else {
            return DesignSystem.Colors.overlay.opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isActive {
            return accentColor.opacity(0.4)
        } else if isHovered {
            return DesignSystem.Colors.secondaryText.opacity(0.3)
        } else {
            return DesignSystem.Colors.secondaryText.opacity(0.2)
        }
    }

    private var scaleEffect: CGFloat {
        isHovered ? 1.05 : 1.0
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    ClipboardView()
        .frame(width: 800, height: 250)
}
#endif
