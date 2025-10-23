import SwiftUI

struct ClipboardView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    @State private var hoveredItem: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("clipboard.search.placeholder".localized, text: $viewModel.searchText)
                        .textFieldStyle(.plain)

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                // 过滤和排序控件(仅图标按钮,点击后弹出选项)
                HStack(spacing: 12) {
                    // 类型
                    Button(action: {
                        if viewModel.showTypeFilter { viewModel.showTypeFilter = false } else {
                            viewModel.showTypeFilter = true
                            viewModel.showDateFilter = false
                            viewModel.showSourceFilter = false
                            viewModel.showSortFilter = false
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((viewModel.selectedContentType != "all") ? .blue : (viewModel.hoveredToolbar == "type" ? .primary : .primary))
                                .background(
                                    (viewModel.selectedContentType != "all"
                                        ? Color.blue.opacity(0.15)
                                        : (viewModel.hoveredToolbar == "type" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (viewModel.selectedContentType != "all") ? Color.blue.opacity(0.4) : (viewModel.hoveredToolbar == "type" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(viewModel.hoveredToolbar == "type" ? 1.03 : 1.0)
                            if viewModel.selectedContentType != "all" {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        viewModel.hoveredToolbar = isHover ? "type" : (viewModel.hoveredToolbar == "type" ? nil : viewModel.hoveredToolbar)
                    }

                    // 日期
                    Button(action: {
                        if viewModel.showDateFilter { viewModel.showDateFilter = false } else {
                            viewModel.showTypeFilter = false
                            viewModel.showDateFilter = true
                            viewModel.showSourceFilter = false
                            viewModel.showSortFilter = false
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((viewModel.selectedDateRange != "all") ? .red : (viewModel.hoveredToolbar == "date" ? .primary : .primary))
                                .background(
                                    (viewModel.selectedDateRange != "all"
                                        ? Color.red.opacity(0.15)
                                        : (viewModel.hoveredToolbar == "date" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (viewModel.selectedDateRange != "all") ? Color.red.opacity(0.4) : (viewModel.hoveredToolbar == "date" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(viewModel.hoveredToolbar == "date" ? 1.03 : 1.0)
                            if viewModel.selectedDateRange != "all" {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        viewModel.hoveredToolbar = isHover ? "date" : (viewModel.hoveredToolbar == "date" ? nil : viewModel.hoveredToolbar)
                    }

                    // 来源
                    Button(action: {
                        if viewModel.showSourceFilter { viewModel.showSourceFilter = false } else {
                            viewModel.showTypeFilter = false
                            viewModel.showDateFilter = false
                            viewModel.showSourceFilter = true
                            viewModel.showSortFilter = false
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((viewModel.selectedSourceApp != "all") ? .purple : (viewModel.hoveredToolbar == "source" ? .primary : .primary))
                                .background(
                                    (viewModel.selectedSourceApp != "all"
                                        ? Color.purple.opacity(0.15)
                                        : (viewModel.hoveredToolbar == "source" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (viewModel.selectedSourceApp != "all") ? Color.purple.opacity(0.4) : (viewModel.hoveredToolbar == "source" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(viewModel.hoveredToolbar == "source" ? 1.03 : 1.0)
                            if viewModel.selectedSourceApp != "all" {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        viewModel.hoveredToolbar = isHover ? "source" : (viewModel.hoveredToolbar == "source" ? nil : viewModel.hoveredToolbar)
                    }

                    // 排序
                    Button(action: {
                        if viewModel.showSortFilter { viewModel.showSortFilter = false } else {
                            viewModel.showTypeFilter = false
                            viewModel.showDateFilter = false
                            viewModel.showSourceFilter = false
                            viewModel.showSortFilter = true
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((viewModel.sortBy != "time") ? .indigo : (viewModel.hoveredToolbar == "sort" ? .primary : .primary))
                                .background(
                                    (viewModel.sortBy != "time"
                                        ? Color.indigo.opacity(0.15)
                                        : (viewModel.hoveredToolbar == "sort" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (viewModel.sortBy != "time") ? Color.indigo.opacity(0.4) : (viewModel.hoveredToolbar == "sort" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(viewModel.hoveredToolbar == "sort" ? 1.03 : 1.0)
                            if viewModel.sortBy != "time" {
                                Circle()
                                    .fill(Color.indigo)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        viewModel.hoveredToolbar = isHover ? "sort" : (viewModel.hoveredToolbar == "sort" ? nil : viewModel.hoveredToolbar)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
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

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    ClipboardView()
        .frame(width: 800, height: 250)
}
#endif
