import Cocoa
import SwiftUI
import CoreGraphics

enum ScreenshotMode {
    case region
    case window
}

class ScreenshotCapture: ObservableObject {
    static let shared = ScreenshotCapture()
    
    @Published var isCapturing: Bool = false
    @Published var currentMode: ScreenshotMode = .region
    
    private var overlayWindow: NSWindow?
    private var regionStartPoint: NSPoint?
    private var regionEndPoint: NSPoint?
    private var selectedWindowID: CGWindowID?
    private var windows: [WindowInfo] = []
    
    var onCaptureComplete: ((NSImage, ScreenshotMode, CGWindowID?) -> Void)?
    var onCaptureCancel: (() -> Void)?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func startCapture(mode: ScreenshotMode) {
        guard !isCapturing else { return }
        
        // 检查屏幕录制权限
        if !hasScreenRecordingPermission() {
            requestScreenRecordingPermission()
            return
        }
        
        currentMode = mode
        isCapturing = true
        
        DispatchQueue.main.async {
            self.setupOverlay()
        }
    }
    
    func cancelCapture() {
        cleanup()
        onCaptureCancel?()
    }
    
    // MARK: - Region Capture
    
    private func setupOverlay() {
        // 创建全屏透明窗口
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        overlayWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow?.level = .screenSaver
        overlayWindow?.backgroundColor = .clear
        overlayWindow?.isOpaque = false
        overlayWindow?.ignoresMouseEvents = false
        
        // 创建 SwiftUI 视图
        let overlayView = ScreenshotOverlayView(
            mode: currentMode,
            onMouseDown: handleMouseDown,
            onMouseDragged: handleMouseDragged,
            onMouseUp: handleMouseUp,
            onCancel: cancelCapture,
            regionStart: regionStartPoint,
            regionEnd: regionEndPoint,
            windows: windows,
            selectedWindowID: selectedWindowID,
            onWindowSelected: { [weak self] windowID in
                self?.selectedWindowID = windowID
            }
        )
        
        let containerView = ScreenshotOverlayContainerView(
            overlayView: overlayView,
            onMouseDown: handleMouseDown,
            onMouseDragged: handleMouseDragged,
            onMouseUp: handleMouseUp,
            onCancel: cancelCapture
        )
        containerView.frame = screenFrame
        overlayWindow?.contentView = containerView
        
        overlayWindow?.makeKeyAndOrderFront(nil)
        
        // 加载窗口列表（用于窗口模式）
        if currentMode == .window {
            loadWindows()
        }
    }
    
    
    private func handleMouseDown(_ point: NSPoint) {
        if currentMode == .region {
            regionStartPoint = point
            regionEndPoint = point
        }
    }
    
    private func handleMouseDragged(_ point: NSPoint) {
        if currentMode == .region {
            regionEndPoint = point
            updateOverlay()
        }
    }
    
    private func handleMouseUp(_ point: NSPoint) {
        if currentMode == .region {
            regionEndPoint = point
            captureRegion()
        } else if currentMode == .window {
            captureWindow(at: point)
        }
    }
    
    private func captureRegion() {
        guard let start = regionStartPoint,
              let end = regionEndPoint else {
            cancelCapture()
            return
        }
        
        let rect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        guard rect.width > 10 && rect.height > 10 else {
            cancelCapture()
            return
        }
        
        // 获取主显示器信息
        let displayID = CGMainDisplayID()
        let screenFrame = CGDisplayBounds(displayID)
        
        // 转换坐标系统（macOS使用左下角为原点）
        let screenHeight = screenFrame.height
        let cgRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        
        // 创建屏幕截图 - 使用 CGWindowListCreateImage 获取整个屏幕
        guard let fullImage = CGWindowListCreateImage(
            .null,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            .bestResolution
        ) else {
            cancelCapture()
            return
        }
        
        // 裁剪到指定区域
        guard let croppedImage = fullImage.cropping(to: cgRect) else {
            cancelCapture()
            return
        }
        
        let image = NSImage(cgImage: croppedImage, size: rect.size)
        cleanup()
        onCaptureComplete?(image, .region, nil)
    }
    
    // MARK: - Window Capture
    
    private func loadWindows() {
        windows = []
        
        // 获取所有窗口
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"],
                  let y = bounds["Y"],
                  let width = bounds["Width"],
                  let height = bounds["Height"],
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String else {
                continue
            }
            
            // 过滤掉系统窗口和一些不需要的窗口
            if ownerName == "WindowServer" || ownerName == "Dock" {
                continue
            }
            
            let rect = NSRect(x: x, y: y, width: width, height: height)
            windows.append(WindowInfo(
                id: windowID,
                rect: rect,
                ownerName: ownerName,
                windowName: windowInfo[kCGWindowName as String] as? String
            ))
        }
        
        updateOverlay()
    }
    
    private func captureWindow(at point: NSPoint) {
        // 找到点击位置下的窗口
        guard let windowInfo = windows.first(where: { $0.rect.contains(point) }) else {
            cancelCapture()
            return
        }
        
        selectedWindowID = windowInfo.id
        
        // 获取窗口截图
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowInfo.id,
            .bestResolution
        ) else {
            cancelCapture()
            return
        }
        
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cleanup()
        onCaptureComplete?(image, .window, windowInfo.id)
    }
    
    // MARK: - Helper Methods
    
    private func updateOverlay() {
        guard let containerView = overlayWindow?.contentView as? ScreenshotOverlayContainerView else {
            return
        }
        
        let overlayView = ScreenshotOverlayView(
            mode: currentMode,
            onMouseDown: handleMouseDown,
            onMouseDragged: handleMouseDragged,
            onMouseUp: handleMouseUp,
            onCancel: cancelCapture,
            regionStart: regionStartPoint,
            regionEnd: regionEndPoint,
            windows: windows,
            selectedWindowID: selectedWindowID,
            onWindowSelected: { [weak self] windowID in
                self?.selectedWindowID = windowID
            }
        )
        
        containerView.hostingView.rootView = overlayView
    }
    
    private func cleanup() {
        overlayWindow?.close()
        overlayWindow = nil
        regionStartPoint = nil
        regionEndPoint = nil
        selectedWindowID = nil
        windows = []
        isCapturing = false
    }
    
    // MARK: - Permissions
    
    private func hasScreenRecordingPermission() -> Bool {
        // 尝试获取屏幕截图来检测权限
        let displayID = CGMainDisplayID()
        if let _ = CGDisplayCreateImage(displayID) {
            return true
        }
        return false
    }
    
    private func requestScreenRecordingPermission() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要屏幕录制权限"
            alert.informativeText = "为了使用截图功能，请在系统设置 > 隐私与安全性 > 屏幕录制中授予权限。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

// MARK: - Window Info

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let rect: NSRect
    let ownerName: String
    let windowName: String?
}

// MARK: - Overlay View

// MARK: - Container View

class ScreenshotOverlayContainerView: NSView {
    let hostingView: NSHostingView<ScreenshotOverlayView>
    private let onMouseDown: (NSPoint) -> Void
    private let onMouseDragged: (NSPoint) -> Void
    private let onMouseUp: (NSPoint) -> Void
    private let onCancel: () -> Void
    
    init(
        overlayView: ScreenshotOverlayView,
        onMouseDown: @escaping (NSPoint) -> Void,
        onMouseDragged: @escaping (NSPoint) -> Void,
        onMouseUp: @escaping (NSPoint) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.hostingView = NSHostingView(rootView: overlayView)
        self.onMouseDown = onMouseDown
        self.onMouseDragged = onMouseDragged
        self.onMouseUp = onMouseUp
        self.onCancel = onCancel
        super.init(frame: .zero)
        addSubview(hostingView)
        hostingView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMouseDown(point)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMouseDragged(point)
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMouseUp(point)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        hostingView.frame = bounds
    }
}

// MARK: - Overlay View

struct ScreenshotOverlayView: View {
    let mode: ScreenshotMode
    let onMouseDown: (NSPoint) -> Void
    let onMouseDragged: (NSPoint) -> Void
    let onMouseUp: (NSPoint) -> Void
    let onCancel: () -> Void
    let regionStart: NSPoint?
    let regionEnd: NSPoint?
    let windows: [WindowInfo]
    let selectedWindowID: CGWindowID?
    let onWindowSelected: (CGWindowID) -> Void
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            if mode == .region {
                regionOverlay
            } else {
                windowOverlay
            }
        }
    }
    
    private var regionOverlay: some View {
        Group {
            if let start = regionStart, let end = regionEnd {
                // 选区矩形
                Rectangle()
                    .fill(Color.clear)
                    .border(Color.accentColor, width: 2)
                    .frame(
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    .position(
                        x: (start.x + end.x) / 2,
                        y: (start.y + end.y) / 2
                    )
                
                // 尺寸标签
                Text("\(Int(abs(end.x - start.x))) × \(Int(abs(end.y - start.y)))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .position(
                        x: (start.x + end.x) / 2,
                        y: min(start.y, end.y) - 20
                    )
            } else {
                // 提示文字
                VStack {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.8))
                    Text("拖拽选择区域")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    Text("按 ESC 取消")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    private var windowOverlay: some View {
        Group {
            ForEach(windows) { window in
                if selectedWindowID == window.id {
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 3)
                        .frame(width: window.rect.width, height: window.rect.height)
                        .position(
                            x: window.rect.midX,
                            y: window.rect.midY
                        )
                } else {
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: window.rect.width, height: window.rect.height)
                        .position(
                            x: window.rect.midX,
                            y: window.rect.midY
                        )
                }
            }
            
            // 提示文字
            VStack {
                Image(systemName: "macwindow")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.8))
                Text("点击窗口进行截图")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Text("按 ESC 取消")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
