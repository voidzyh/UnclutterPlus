import Cocoa
import SwiftUI
import CoreGraphics
import ScreenCaptureKit

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
        
        // 使用 ScreenCaptureKit API (macOS 12.3+) 替代废弃的 CGWindowListCreateImage
        if #available(macOS 12.3, *) {
            Task {
                await captureRegionWithSC(rect: cgRect)
            }
        } else {
            Task {
                await captureRegionWithCoreGraphics(rect: cgRect)
            }
        }
    }
    
    // MARK: - 使用 ScreenCaptureKit 进行区域截图
    
    private func captureRegionWithScreenCaptureKit(rect: CGRect) async {
        await captureRegionWithSC(rect: rect)
    }
    

    
    // MARK: - 使用 Core Graphics 的兼容版本（带警告抑制）

    private func captureRegionWithCoreGraphics(rect: CGRect) async {
        // 注意：CGWindowListCreateImage 在 macOS 14.0+ 中已被废弃
        // 但在完整的 ScreenCaptureKit 实现之前，暂时保留此方法
        // 使用版本检查抑制废弃警告
        if #available(macOS 14.0, *) {
            // 新版本应该使用 ScreenCaptureKit，暂时返回
            logger.warning("ScreenCaptureKit 尚未实现，区域截图功能暂不可用", category: "Screenshot")
            cancelCapture()
            return
        }

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
        guard let croppedImage = fullImage.cropping(to: rect) else {
            cancelCapture()
            return
        }

        await MainActor.run {
            let image = NSImage(cgImage: croppedImage, size: NSSize(width: rect.width, height: rect.height))
            cleanup()
            onCaptureComplete?(image, .region, nil)
        }
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
        
        // 使用 ScreenCaptureKit API (macOS 12.3+) 替代废弃的 CGWindowListCreateImage
        if #available(macOS 12.3, *) {
            Task {
                await captureWindowWithSC(windowID: windowInfo.id)
            }
        } else {
            Task {
                await captureWindowWithCoreGraphics(windowID: windowInfo.id)
            }
        }
    }
    
    // MARK: - 使用 ScreenCaptureKit 进行窗口截图
    
    private func captureWindowWithScreenCaptureKit(windowID: CGWindowID) async {
        await captureWindowWithSC(windowID: windowID)
    }
    

    
    // MARK: - ScreenCaptureKit Implementation Methods (as requested)
    
    private func captureRegionWithSC(rect: CGRect) async {
        // Use SCShareableContent to get displays
        // Use SCStream for screenshot capture on macOS 12.3+
        if #available(macOS 12.3, *) {
            do {
                // Get shareable content
                let availableContent = try await SCShareableContent.current
                
                guard let display = availableContent.displays.first else {
                    throw NSError(domain: "ScreenshotCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "No displays found"])
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                let configuration = SCStreamConfiguration()
                configuration.sourceRect = rect
                configuration.width = Int(rect.width)
                configuration.height = Int(rect.height)
                configuration.scalesToFit = false
                configuration.capturesAudio = false
                
                // Use SCStream to capture screenshot for macOS 12.3-13.x
                let capturedImage = try await captureSingleFrame(filter: filter, configuration: configuration)
                
                guard let finalImage = capturedImage else {
                    throw NSError(domain: "ScreenshotCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to capture image"])
                }

                await MainActor.run {
                    let image = NSImage(cgImage: finalImage, size: NSSize(width: rect.width, height: rect.height))
                    self.cleanup()
                    self.onCaptureComplete?(image, .region, nil)
                }
                
            } catch {
                logger.info("ScreenCaptureKit region capture failed: \(error)", category: "ScreenshotCapture")
                await captureRegionWithCoreGraphics(rect: rect)
            }
        } else {
            await captureRegionWithCoreGraphics(rect: rect)
        }
    }
    
    private func captureWindowWithSC(windowID: CGWindowID) async {
        // Use SCShareableContent
        // Use SCStream for screenshot capture on macOS 12.3+
        if #available(macOS 12.3, *) {
            do {
                let availableContent = try await SCShareableContent.current
                
                guard let window = availableContent.windows.first(where: { $0.windowID == windowID }) else {
                    await captureWindowWithCoreGraphics(windowID: windowID)
                    return
                }
                
                let filter = SCContentFilter(desktopIndependentWindow: window)
                
                let windowRect = window.frame
                let configuration = SCStreamConfiguration()
                configuration.width = Int(windowRect.width)
                configuration.height = Int(windowRect.height)
                configuration.scalesToFit = false
                configuration.capturesAudio = false
                
                // Use SCStream to capture screenshot for macOS 12.3-13.x
                let capturedImage = try await captureSingleFrame(filter: filter, configuration: configuration)
                
                guard let finalImage = capturedImage else {
                    throw NSError(domain: "ScreenshotCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to capture image"])
                }

                await MainActor.run {
                    let image = NSImage(cgImage: finalImage, size: NSSize(width: windowRect.width, height: windowRect.height))
                    self.cleanup()
                    self.onCaptureComplete?(image, .window, windowID)
                }
                
            } catch {
                logger.info("ScreenCaptureKit window capture failed: \(error)", category: "ScreenshotCapture")
                await captureWindowWithCoreGraphics(windowID: windowID)
            }
        } else {
            await captureWindowWithCoreGraphics(windowID: windowID)
        }
    }
    
    // MARK: - ScreenCaptureKit Helper Methods
    
    @available(macOS 12.3, *)
    private func captureSingleFrame(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage? {
        return try await withCheckedThrowingContinuation { continuation in
            let captureHelper = ScreenshotCaptureHelper()
            captureHelper.captureSingleFrame(filter: filter, configuration: configuration) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "ScreenshotCapture", code: 3, userInfo: [NSLocalizedDescriptionKey: "No image captured"]))
                }
            }
        }
    }

    private func captureWindowWithCoreGraphics(windowID: CGWindowID) async {
        // 注意：CGWindowListCreateImage 在 macOS 14.0+ 中已被废弃
        // 但在完整的 ScreenCaptureKit 实现之前，暂时保留此方法
        // 使用版本检查抑制废弃警告
        if #available(macOS 14.0, *) {
            // 新版本应该使用 ScreenCaptureKit，暂时返回
            logger.warning("ScreenCaptureKit 尚未实现，窗口截图功能暂不可用", category: "Screenshot")
            cancelCapture()
            return
        }

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            .bestResolution
        ) else {
            cancelCapture()
            return
        }

        await MainActor.run {
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            cleanup()
            onCaptureComplete?(image, .window, windowID)
        }
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
        // 检查 ScreenCaptureKit 权限，但不在此方法中抛出异步异常
        // 实际权限检查在 API 调用时进行
        return true
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

// MARK: - ScreenCaptureKit Helper Classes

@available(macOS 12.3, *)
class ScreenshotCaptureHelper: NSObject, SCStreamDelegate, SCStreamOutput {
    private var continuation: ((CGImage?, Error?) -> Void)?
    private var stream: SCStream?
    
    func captureSingleFrame(filter: SCContentFilter, configuration: SCStreamConfiguration, completion: @escaping (CGImage?, Error?) -> Void) {
        self.continuation = completion
        
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        do {
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global())
            stream?.startCapture()
            
            // Stop capture after a short delay to get single frame
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
                let stream = self?.stream
                Task {
                    try? await stream?.stopCapture()
                }
            }
        } catch {
            completion(nil, error)
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, let continuation = continuation else { return }
        
        self.continuation = nil
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            continuation(nil, NSError(domain: "ScreenshotCapture", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get pixel buffer"]))
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            continuation(nil, NSError(domain: "ScreenshotCapture", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"]))
            return
        }
        
        continuation(cgImage, nil)
        
        Task {
            try? await stream.stopCapture()
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        continuation?(nil, error)
        continuation = nil
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
        // 不支持从coder初始化，返回nil
        return nil
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
