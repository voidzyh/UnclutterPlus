import SwiftUI
import Combine

/// 现代化 UnclutterPlus 应用入口 - 集成所有新组件
@main
struct ModernUnclutterPlusApp: App {
    @NSApplicationDelegateAdaptor(ModernAppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var designSystem = ModernDesignSystem.shared
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    
    var body: some Scene {
        Settings {
            ModernPreferencesView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .commands {
            // 应用菜单命令
            CommandGroup(after: .appSettings) {
                Button("Show UnclutterPlus") {
                    appState.showApp()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                
                Button("Hide UnclutterPlus") {
                    appState.hideApp()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
            
            // 编辑菜单命令
            CommandGroup(after: .pasteboard) {
                Button("Clear Clipboard History") {
                    appState.clearClipboard()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Button("Clear All Files") {
                    appState.clearFiles()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            
            // 帮助菜单命令
            CommandGroup(after: .help) {
                Button("Performance Monitor") {
                    appState.showPerformanceMonitorWindow()
                }
                
                Button("About Modern UnclutterPlus") {
                    appState.showAbout()
                }
            }
        }
        
        // 窗口场景 - 用于调试和开发
        WindowGroup("Debug Window") {
            if appState.showDebugWindow {
                DebugContentView()
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "debug"))
    }
}

// MARK: - 应用状态管理

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    // 状态管理
    @Published var isAppActive = true
    @Published var showDebugWindow = false
    @Published var showPerformanceMonitor = false
    @Published var currentTheme: AppTheme = .system
    
    // 性能监控
    @Published var performanceMetrics = PerformanceMetrics()
    
    private var cancellables = Set<AnyCancellable>()
    private let windowManager = ModernWindowManager.shared
    private let performanceOptimizer = PerformanceOptimizer.shared
    
    private init() {
        setupBindings()
        setupPerformanceMonitoring()
        setupThemeObserver()
    }
    
    // MARK: - 公共方法
    
    func showApp() {
        windowManager.showWindow()
    }
    
    func hideApp() {
        windowManager.hideWindow()
    }
    
    func toggleApp() {
        windowManager.toggleWindow()
    }
    
    func clearClipboard() {
        // 实现清除剪贴板逻辑
        NotificationCenter.default.post(name: .clearClipboard, object: nil)
    }
    
    func clearFiles() {
        // 实现清除文件逻辑
        NotificationCenter.default.post(name: .clearFiles, object: nil)
    }
    
    func showPerformanceMonitorWindow() {
        showPerformanceMonitor = true
    }
    
    func hidePerformanceMonitor() {
        showPerformanceMonitor = false
    }
    
    func showAbout() {
        // 实现显示关于窗口逻辑
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    func switchTheme(_ theme: AppTheme) {
        currentTheme = theme
        ModernDesignSystem.shared.switchTheme(theme)
    }
    
    func enableDebugMode() {
        showDebugWindow = true
    }
    
    func disableDebugMode() {
        showDebugWindow = false
    }
    
    // MARK: - 私有方法
    
    private func setupBindings() {
        // 监听应用激活状态
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .map { _ in true }
            .assign(to: \.isAppActive, on: self)
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .map { _ in false }
            .assign(to: \.isAppActive, on: self)
            .store(in: &cancellables)
        
        // 监听窗口状态
        windowManager.$isWindowVisible
            .sink { visible in
                // 可以在这里添加窗口状态变化的逻辑
                print("Window visibility changed: \(visible)")
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        // 监听性能指标
        performanceOptimizer.$memoryUsage
            .combineLatest(performanceOptimizer.$cpuUsage, performanceOptimizer.$performanceScore)
            .sink { [weak self] memory, cpu, score in
                self?.performanceMetrics = PerformanceMetrics(
                    memoryUsage: memory,
                    cpuUsage: cpu,
                    performanceScore: score
                )
            }
            .store(in: &cancellables)
        
        // 启动性能监控
        performanceOptimizer.startPerformanceMonitoring()
    }
    
    private func setupThemeObserver() {
        // 监听主题变化
        ModernDesignSystem.shared.$currentTheme
            .assign(to: \.currentTheme, on: self)
            .store(in: &cancellables)
    }
}

// MARK: - 性能指标模型

struct PerformanceMetrics {
    let memoryUsage: Double
    let cpuUsage: Double
    let performanceScore: Int
    let timestamp: Date
    
    init(memoryUsage: Double = 0, cpuUsage: Double = 0, performanceScore: Int = 100) {
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.performanceScore = performanceScore
        self.timestamp = Date()
    }
}

// MARK: - 调试内容视图

struct DebugContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    @StateObject private var designSystem = ModernDesignSystem.shared
    
    @State private var selectedDebugTab = 0
    @State private var showMemoryDetails = false
    @State private var showPerformanceGraph = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 调试工具栏
            debugToolbar
                .padding()
            
            Divider()
            
            // 调试内容
            HSplitView {
                // 左侧导航
                debugNavigation
                    .frame(width: 200)
                
                Divider()
                
                // 右侧内容
                debugContent
                    .frame(minWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 调试工具栏
    
    private var debugToolbar: some View {
        HStack {
            Text("UnclutterPlus Debug Mode")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Spacer()
            
            // 性能指示器
            PerformanceMonitorView()
                .frame(width: 200)
            
            // 主题切换
            Picker("Theme", selection: $designSystem.currentTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    HStack {
                        Image(systemName: theme.icon)
                        Text(theme.rawValue)
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            
            // 关闭按钮
            Button(action: {
                appState.disableDebugMode()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 调试导航
    
    private var debugNavigation: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(DebugTab.allCases, id: \.self) { tab in
                DebugTabButton(
                    tab: tab,
                    isSelected: selectedDebugTab == tab.rawValue
                ) {
                    selectedDebugTab = tab.rawValue
                }
            }
            
            Spacer()
            
            // 快速操作
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundColor(.adaptiveSecondary)
                
                Button("Clear All Caches") {
                    performanceOptimizer.clearAllCaches()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Optimize Memory") {
                    performanceOptimizer.optimizeMemory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Reset Settings") {
                    resetSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - 调试内容
    
    @ViewBuilder
    private var debugContent: some View {
        switch DebugTab(rawValue: selectedDebugTab) {
        case .overview:
            debugOverview
        case .performance:
            debugPerformance
        case .memory:
            debugMemory
        case .animations:
            debugAnimations
        case .features:
            debugFeatures
        case .logs:
            debugLogs
        default:
            EmptyView()
        }
    }
    
    // MARK: - 调试概览
    
    private var debugOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 应用信息
                appInfoSection
                
                // 系统信息
                systemInfoSection
                
                // 功能状态
                featureStatusSection
                
                // 快速统计
                quickStatsSection
            }
            .padding()
        }
    }
    
    // MARK: - 性能调试
    
    private var debugPerformance: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 实时性能指标
                performanceMetricsSection
                
                // 性能图表
                if showPerformanceGraph {
                    performanceGraphSection
                }
                
                // 优化建议
                optimizationSuggestionsSection
                
                // 性能历史
                performanceHistorySection
            }
            .padding()
        }
    }
    
    // MARK: - 内存调试
    
    private var debugMemory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 内存使用情况
                memoryUsageSection
                
                // 缓存状态
                if showMemoryDetails {
                    cacheStatusSection
                }
                
                // 内存优化
                memoryOptimizationSection
                
                // 内存历史
                memoryHistorySection
            }
            .padding()
        }
    }
    
    // MARK: - 动画调试
    
    private var debugAnimations: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 动画预览
                animationPreviewSection
                
                // 动画性能
                animationPerformanceSection
                
                // 动画设置
                animationSettingsSection
            }
            .padding()
        }
    }
    
    // MARK: - 功能调试
    
    private var debugFeatures: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 功能开关
                featureTogglesSection
                
                // 功能测试
                featureTestingSection
                
                // 功能统计
                featureStatisticsSection
            }
            .padding()
        }
    }
    
    // MARK: - 日志调试
    
    private var debugLogs: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 日志过滤器
                logFilterSection
                
                // 日志内容
                logContentSection
                
                // 日志操作
                logActionsSection
            }
            .padding()
        }
    }
    
    // MARK: - 具体调试部分
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application Information")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                    InfoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                    InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                    InfoRow(label: "Window Status", value: ModernWindowManager.shared.isWindowVisible ? "Visible" : "Hidden")
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Theme", value: designSystem.currentTheme.rawValue)
                    InfoRow(label: "Animations", value: "Enabled")
                    InfoRow(label: "Edge Tracking", value: ModernWindowManager.shared.isEdgeTracking ? "Active" : "Inactive")
                    InfoRow(label: "Performance Score", value: "\(performanceOptimizer.performanceScore)/100")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Information")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                    InfoRow(label: "Architecture", value: getArchitecture())
                    InfoRow(label: "CPU Cores", value: "\(ProcessInfo.processInfo.processorCount)")
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Total Memory", value: formatBytes(Double(ProcessInfo.processInfo.physicalMemory)))
                    InfoRow(label: "Active Memory", value: formatBytes(performanceOptimizer.memoryUsage))
                    InfoRow(label: "CPU Usage", value: "\(Int(performanceOptimizer.cpuUsage))%")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var featureStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Status")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            HStack(spacing: 20) {
                FeatureStatusCard(
                    title: "Files",
                    icon: "folder",
                    isEnabled: true,
                    status: "Active"
                )
                
                FeatureStatusCard(
                    title: "Clipboard",
                    icon: "doc.on.clipboard",
                    isEnabled: true,
                    status: "Active"
                )
                
                FeatureStatusCard(
                    title: "Notes",
                    icon: "note.text",
                    isEnabled: true,
                    status: "Active"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Statistics")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Clipboard Items",
                    value: "0",
                    icon: "doc.on.clipboard",
                    color: .blue
                )
                
                StatCard(
                    title: "Notes",
                    value: "0",
                    icon: "note.text",
                    color: .green
                )
                
                StatCard(
                    title: "Files",
                    value: "0",
                    icon: "folder",
                    color: .orange
                )
                
                StatCard(
                    title: "Memory",
                    value: formatBytes(performanceOptimizer.memoryUsage),
                    icon: "memorychip",
                    color: .purple
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance Metrics")
                    .font(.headline)
                    .foregroundColor(.adaptiveForeground)
                
                Spacer()
                
                Button(showPerformanceGraph ? "Hide Graph" : "Show Graph") {
                    showPerformanceGraph.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                // .hoverEffect() // Not available in macOS
            }
            
            PerformanceMonitorView()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var performanceGraphSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Graph")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            // 这里可以添加实际的性能图表
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    Text("Performance Graph Placeholder")
                        .foregroundColor(.adaptiveSecondary)
                )
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var memoryUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memory Usage")
                    .font(.headline)
                    .foregroundColor(.adaptiveForeground)
                
                Spacer()
                
                Button(showMemoryDetails ? "Hide Details" : "Show Details") {
                    showMemoryDetails.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                // .hoverEffect() // Not available in macOS
            }
            
            // 内存使用图表
            MemoryUsageView()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var animationPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation Preview")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            HStack(spacing: 20) {
                PulseAnimationView {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }
                
                BreatheAnimationView {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 40, height: 40)
                }
                
                RotateAnimationView {
                    Image(systemName: "gear")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - 缺失的调试部分
    
    private var optimizationSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Suggestions")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("No optimization suggestions available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var performanceHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance History")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Performance history will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var cacheStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Status")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Cache information will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var memoryOptimizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Optimization")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Memory optimization settings will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var memoryHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory History")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Memory usage history will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var animationPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation Performance")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Animation performance metrics will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var animationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation Settings")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Animation configuration will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var featureTogglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Toggles")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Feature toggle settings will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var featureTestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Testing")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Feature testing tools will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var featureStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Statistics")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Feature usage statistics will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var logFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log Filter")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Log filtering options will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var logContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log Content")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Log content will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var logActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log Actions")
                .font(.headline)
                .foregroundColor(.adaptiveForeground)
            
            Text("Log management actions will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    
    private func getArchitecture() -> String {
        #if arch(x86_64)
        return "Intel (x86_64)"
        #elseif arch(arm64)
        return "Apple Silicon (arm64)"
        #else
        return "Unknown"
        #endif
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This will reset all application settings to their default values."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            ConfigurationManager.shared.resetToDefaults()
        }
    }
}

// MARK: - 调试标签页

enum DebugTab: Int, CaseIterable {
    case overview = 0
    case performance = 1
    case memory = 2
    case animations = 3
    case features = 4
    case logs = 5
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .performance: return "Performance"
        case .memory: return "Memory"
        case .animations: return "Animations"
        case .features: return "Features"
        case .logs: return "Logs"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "info.circle"
        case .performance: return "speedometer"
        case .memory: return "memorychip"
        case .animations: return "sparkles"
        case .features: return "switch.2"
        case .logs: return "doc.text"
        }
    }
}

// MARK: - 调试组件

struct DebugTabButton: View {
    let tab: DebugTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.body)
                
                Text(tab.title)
                    .font(.body)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.accentColor.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.adaptiveForeground)
        }
    }
}

struct FeatureStatusCard: View {
    let title: String
    let icon: String
    let isEnabled: Bool
    let status: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isEnabled ? .green : .gray)
                
                Spacer()
                
                Circle()
                    .fill(isEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.adaptiveForeground)
            
            Text(status)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.adaptiveForeground)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

struct MemoryUsageView: View {
    @StateObject private var optimizer = PerformanceOptimizer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatBytes(optimizer.memoryUsage))
                        .font(.headline)
                        .foregroundColor(.adaptiveForeground)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Performance Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(optimizer.performanceScore)/100")
                        .font(.headline)
                        .foregroundColor(performanceColor)
                }
            }
            
            // 内存使用进度条
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(performanceColor)
                            .frame(width: geometry.size.width * CGFloat(min(optimizer.performanceScore, 100)) / 100, height: 8)
                    , alignment: .leading)
            }
            .frame(height: 8)
        }
    }
    
    private var performanceColor: Color {
        switch optimizer.performanceScore {
        case 80...100:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let clearClipboard = Notification.Name("clearClipboard")
    static let clearFiles = Notification.Name("clearFiles")
}

// MARK: - 预览

#Preview {
    DebugContentView()
        .frame(width: 1200, height: 800)
}