import SwiftUI

// MARK: - Liquid Glass TabView
// SwiftUI 2025: 玻璃化标签页组件

/// 标签页配置
struct LiquidTabItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let content: AnyView

    init<T: View>(
        id: String = UUID().uuidString,
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> T
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.content = AnyView(content())
    }
}

/// Liquid Glass 标签页组件
struct LiquidGlassTabView: View {
    let tabs: [LiquidTabItem]
    @Binding var selectedTab: String
    @Namespace private var namespace

    // 动画配置
    private let animationDuration: Double = 0.3
    private let dampingFraction: Double = 0.8

    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器 - Liquid Glass 风格
            tabBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()
                .background(Color.clear.opacity(0.3))

            // 内容区域
            contentView
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .liquidGlass(cornerRadius: 16, opacity: 0.1)
        )
        .padding(8)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.id) { tab in
                LiquidTabButton(
                    title: tab.title,
                    systemImage: tab.systemImage,
                    isSelected: selectedTab == tab.id
                ) {
                    withAnimation(.spring(response: animationDuration, dampingFraction: dampingFraction)) {
                        selectedTab = tab.id
                    }
                }
                .glassEffectID(tab.id, in: namespace)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Content View

    private var contentView: some View {
        ZStack {
            ForEach(tabs, id: \.id) { tab in
                if selectedTab == tab.id {
                    tab.content
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                        .glassEffectID(tab.id, in: namespace)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Button

struct LiquidTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ?
                                Color.white.opacity(0.3) :
                                Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 8 : 3,
                x: 0,
                y: isSelected ? 3 : 1
            )
        }
        .buttonStyle(.liquidGlass)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Enhanced TabView for MainContentView

struct EnhancedTabView: View {
    let tabs: [(id: String, title: String, systemImage: String, content: AnyView)]
    @Binding var selectedTab: Int
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            // 标签页按钮
            HStack(spacing: 8) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = index
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 14, weight: .medium))
                            Text(tab.title)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == index ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == index ? Color.accentColor : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedTab == index ?
                                            Color.white.opacity(0.3) :
                                            Color.white.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.liquidGlass)
                    .glassEffectID(tab.id, in: namespace)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )

            Divider()
                .background(Color.clear.opacity(0.3))

            // 内容区域
            ZStack {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    if selectedTab == index {
                        tab.content
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                )
                            )
                            .glassEffectID(tab.id, in: namespace)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidGlassTabViewPreview: View {
    @State private var selectedTab = "files"

    private let sampleTabs: [TabItem] = [
        TabItem(
            id: "files",
            title: "Files",
            systemImage: "folder"
        ) {
            VStack(spacing: 16) {
                Image(systemName: "folder")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Files View")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Manage your temporary files here")
                    .foregroundStyle(.secondary)
            }
        },
        TabItem(
            id: "clipboard",
            title: "Clipboard",
            systemImage: "doc.on.clipboard"
        ) {
            VStack(spacing: 16) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Clipboard View")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Access your clipboard history")
                    .foregroundStyle(.secondary)
            }
        },
        TabItem(
            id: "notes",
            title: "Notes",
            systemImage: "note.text"
        ) {
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Notes View")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create and edit markdown notes")
                    .foregroundStyle(.secondary)
            }
        }
    ]

    var body: some View {
        LiquidGlassTabView(
            tabs: sampleTabs,
            selectedTab: $selectedTab
        )
        .frame(width: 600, height: 400)
    }
}

#Preview("Liquid Glass TabView") {
    LiquidGlassTabViewPreview()
}

#Preview("Enhanced TabView") {
    struct EnhancedPreview: View {
        @State private var selectedTab = 0

        private let tabs: [(id: String, title: String, systemImage: String, content: AnyView)] = [
            (
                id: "files",
                title: "Files",
                systemImage: "folder",
                content: AnyView(
                    VStack {
                        Text("Files Content")
                            .font(.title)
                        Spacer()
                    }
                )
            ),
            (
                id: "clipboard",
                title: "Clipboard",
                systemImage: "doc.on.clipboard",
                content: AnyView(
                    VStack {
                        Text("Clipboard Content")
                            .font(.title)
                        Spacer()
                    }
                )
            ),
            (
                id: "notes",
                title: "Notes",
                systemImage: "note.text",
                content: AnyView(
                    VStack {
                        Text("Notes Content")
                            .font(.title)
                        Spacer()
                    }
                )
            )
        ]

        var body: some View {
            EnhancedTabView(
                tabs: tabs,
                selectedTab: $selectedTab
            )
            .frame(width: 500, height: 300)
        }
    }

    return EnhancedPreview()
}
#endif
