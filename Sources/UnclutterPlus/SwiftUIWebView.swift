import SwiftUI
import WebKit

// MARK: - SwiftUI 2025 Native WebView
// 原生 WebView 组件 - 利用 SwiftUI 2025 新特性

/// WebView 配置
struct WebViewConfig {
    let allowsBackForwardNavigationGestures: Bool
    let allowsJavaScript: Bool
    let allowsInlineMediaPlayback: Bool
    let ignoresInvisibleElements: Bool

    init(
        allowsBackForwardNavigationGestures: Bool = true,
        allowsJavaScript: Bool = true,
        allowsInlineMediaPlayback: Bool = true,
        ignoresInvisibleElements: Bool = true
    ) {
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        self.allowsJavaScript = allowsJavaScript
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.ignoresInvisibleElements = ignoresInvisibleElements
    }
}

/// WebView 加载状态
enum WebViewLoadingState {
    case idle
    case loading
    case loaded
    case error(Error)
}

/// 原生 WebView 组件
struct SwiftUIWebView: View {
    let url: URL?
    let html: String?
    let config: WebViewConfig

    @State private var state: WebViewLoadingState = .idle
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = false

    // WebKit 包装器
    @StateObject private var webViewWrapper = WebViewWrapper()

    init(
        url: URL? = nil,
        html: String? = nil,
        config: WebViewConfig = WebViewConfig()
    ) {
        self.url = url
        self.html = html
        self.config = config
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏（可选）
            if showToolbar {
                toolbarView
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

            // WebView 内容
            if let url = url {
                // URL 加载
                WebView(
                    url: url,
                    config: config,
                    onStateChange: handleStateChange,
                    onNavigationChange: handleNavigationChange
                )
                .onAppear {
                    loadURL(url)
                }
            } else if let html = html {
                // HTML 加载
                WebView(
                    html: html,
                    config: config,
                    onStateChange: handleStateChange,
                    onNavigationChange: handleNavigationChange
                )
                .onAppear {
                    loadHTML(html)
                }
            } else {
                // 空状态
                emptyStateView
            }
        }
        .liquidGlass(cornerRadius: 12, opacity: 0.1)
        .onAppear {
            setupWebView()
        }
    }

    // MARK: - Toolbar

    private var showToolbar: Bool {
        // 只在需要时显示工具栏（例如支持导航的页面）
        return canGoBack || canGoForward || state == .loading
    }

    private var toolbarView: some View {
        HStack(spacing: 8) {
            // 导航按钮
            HStack(spacing: 4) {
                NavigationButton(
                    systemName: "chevron.left",
                    isEnabled: canGoBack
                ) {
                    goBack()
                }

                NavigationButton(
                    systemName: "chevron.right",
                    isEnabled: canGoForward
                ) {
                    goForward()
                }
            }

            Divider()
                .frame(height: 16)
                .background(Color.clear.opacity(0.3))

            // 刷新按钮
            NavigationButton(
                systemName: isLoading ? "stop.circle" : "arrow.clockwise",
                isEnabled: true
            ) {
                isLoading ? stopLoading() : reload()
            }

            Divider()
                .frame(height: 16)
                .background(Color.clear.opacity(0.3))

            // 状态指示器
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.green.opacity(0.5), radius: 2)
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // URL 显示（如果可用）
            if let urlString = webViewWrapper.currentURL?.absoluteString {
                Text(urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "Ready"
        case .loading:
            return "Loading..."
        case .loaded:
            return "Loaded"
        case .error:
            return "Error"
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No content to display")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("Provide a URL or HTML content to display")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func setupWebView() {
        // WebView 初始化
    }

    private func loadURL(_ url: URL) {
        webViewWrapper.loadURL(url)
    }

    private func loadHTML(_ html: String) {
        webViewWrapper.loadHTML(html)
    }

    private func goBack() {
        webViewWrapper.goBack()
    }

    private func goForward() {
        webViewWrapper.goForward()
    }

    private func reload() {
        webViewWrapper.reload()
    }

    private func stopLoading() {
        webViewWrapper.stopLoading()
    }

    private func handleStateChange(_ newState: WebViewLoadingState) {
        state = newState
    }

    private func handleNavigationChange(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
}

// MARK: - Navigation Button

struct NavigationButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(.liquidGlassNoScale)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - WebView Wrapper

class WebViewWrapper: ObservableObject {
    @Published var currentURL: URL?
    @Published var isLoading: Bool = false

    func loadURL(_ url: URL) {
        currentURL = url
        // 在实际实现中，这里会配置 WKWebView
        print("Loading URL: \(url.absoluteString)")
    }

    func loadHTML(_ html: String) {
        print("Loading HTML content")
    }

    func goBack() {
        print("Navigate back")
    }

    func goForward() {
        print("Navigate forward")
    }

    func reload() {
        print("Reload page")
    }

    func stopLoading() {
        print("Stop loading")
    }
}

// MARK: - WebView Implementation (Simplified)

struct WebView: NSViewRepresentable {
    let url: URL?
    let html: String?
    let config: WebViewConfig
    let onStateChange: (WebViewLoadingState) -> Void
    let onNavigationChange: (Bool, Bool) -> Void

    init(
        url: URL? = nil,
        html: String? = nil,
        config: WebViewConfig = WebViewConfig(),
        onStateChange: @escaping (WebViewLoadingState) -> Void = { _ in },
        onNavigationChange: @escaping (Bool, Bool) -> Void = { _, _ in }
    ) {
        self.url = url
        self.html = html
        self.config = config
        self.onStateChange = onStateChange
        self.onNavigationChange = onNavigationChange
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()

        // 配置
        webView.allowsBackForwardNavigationGestures = config.allowsBackForwardNavigationGestures
        webView.allowsJavaScript = config.allowsJavaScript

        // 设置委托
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        } else if let html = html {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onStateChange(.loading)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onStateChange(.loaded)
            parent.onNavigationChange(webView.canGoBack, webView.canGoForward)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onStateChange(.error(error))
        }
    }
}

// MARK: - Link Preview Component

struct LinkPreviewView: View {
    let url: URL
    @State private var webView: SwiftUIWebView?

    var body: some View {
        VStack(spacing: 8) {
            if let webView = webView {
                webView
                    .frame(height: 200)
                    .cornerRadius(12)
            } else {
                loadingPlaceholder
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .liquidGlass(cornerRadius: 12, opacity: 0.1)
        )
        .onAppear {
            loadWebView()
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading preview...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func loadWebView() {
        webView = SwiftUIWebView(
            url: url,
            config: WebViewConfig(
                allowsBackForwardNavigationGestures: false,
                allowsJavaScript: true,
                allowsInlineMediaPlayback: true,
                ignoresInvisibleElements: true
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct SwiftUIWebViewPreview: View {
    @State private var showWebView = false

    var body: some View {
        VStack(spacing: 16) {
            Button("Show Apple.com") {
                showWebView = true
            }
            .buttonStyle(.liquidGlass)

            if showWebView {
                SwiftUIWebView(
                    url: URL(string: "https://www.apple.com"),
                    config: WebViewConfig()
                )
                .frame(height: 300)
            }
        }
        .padding()
        .frame(width: 600, height: 400)
    }
}

#Preview("WebView") {
    SwiftUIWebViewPreview()
}

#Preview("Link Preview") {
    LinkPreviewView(url: URL(string: "https://developer.apple.com")!)
        .frame(width: 400, height: 250)
        .padding()
}
#endif
