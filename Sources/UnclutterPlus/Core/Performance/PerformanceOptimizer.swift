import Foundation
import SwiftUI
import Combine

/// 性能优化器 - 管理应用性能和内存使用
@MainActor
final class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    // MARK: - 性能监控
    
    @Published var memoryUsage: Double = 0
    @Published var cpuUsage: Double = 0
    @Published var isOptimizing = false
    @Published var performanceScore: Int = 100
    
    // 性能阈值
    private let memoryWarningThreshold: Double = 500 * 1024 * 1024 // 500MB
    private let memoryCriticalThreshold: Double = 800 * 1024 * 1024 // 800MB
    private let cpuWarningThreshold: Double = 70.0 // 70%
    private let cpuCriticalThreshold: Double = 90.0 // 90%
    
    // MARK: - 内存管理
    
    private var memoryCache = NSCache<NSString, AnyObject>()
    private var imageCache = NSCache<NSString, NSImage>()
    private var dataCache = NSCache<NSString, NSData>()
    
    // 缓存配置
    private let maxCacheMemory: Int = 100 * 1024 * 1024 // 100MB
    private let maxImageCache: Int = 50 * 1024 * 1024 // 50MB
    private let maxDataCache: Int = 30 * 1024 * 1024 // 30MB
    
    // MARK: - 性能优化
    
    private var cancellables = Set<AnyCancellable>()
    private var performanceTimer: Timer?
    private var optimizationTimer: Timer?
    private var memoryWarningObserver: NSObjectProtocol?
    
    // 任务管理
    private var activeTasks: Set<Task<Void, Never>> = []
    private let maxConcurrentTasks = 5
    private let taskQueue = DispatchQueue(label: "performance.task.queue", attributes: .concurrent)
    
    // 节流和防抖
    private var throttleTimers: [String: Timer] = [:]
    private var debounceTimers: [String: Timer] = [:]
    
    private init() {
        setupCache()
        setupPerformanceMonitoring()
        setupMemoryWarnings()
        setupOptimizations()
    }
    
    // MARK: - 公共方法
    
    func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    func stopPerformanceMonitoring() {
        performanceTimer?.invalidate()
        performanceTimer = nil
    }
    
    func optimizeMemory() {
        isOptimizing = true
        
        Task {
            await performMemoryOptimization()
            
            await MainActor.run {
                self.isOptimizing = false
            }
        }
    }
    
    func clearAllCaches() {
        memoryCache.removeAllObjects()
        imageCache.removeAllObjects()
        dataCache.removeAllObjects()
        
        // 清理系统缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 触发垃圾回收
        autoreleasepool {
            // 强制释放未使用的内存
        }
    }
    
    func cacheImage(_ image: NSImage, for key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }
    
    func cachedImage(for key: String) -> NSImage? {
        imageCache.object(forKey: key as NSString)
    }
    
    func cacheData(_ data: Data, for key: String) {
        dataCache.setObject(data as NSData, forKey: key as NSString)
    }
    
    func cachedData(for key: String) -> Data? {
        dataCache.object(forKey: key as NSString) as Data?
    }
    
    func cacheObject<T: AnyObject>(_ object: T, for key: String) {
        memoryCache.setObject(object, forKey: key as NSString)
    }
    
    func cachedObject<T: AnyObject>(for key: String) -> T? {
        memoryCache.object(forKey: key as NSString) as? T
    }
    
    // 节流函数
    func throttle<T>(key: String, interval: TimeInterval, action: @escaping () -> T) -> T? {
        // 取消之前的定时器
        throttleTimers[key]?.invalidate()
        
        var result: T?
        
        // 立即执行第一次
        if throttleTimers[key] == nil {
            result = action()
        }
        
        // 设置新的定时器
        throttleTimers[key] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.throttleTimers[key] = nil
            }
        }
        
        return result
    }
    
    // 防抖函数
    func debounce(key: String, interval: TimeInterval, action: @escaping () -> Void) {
        // 取消之前的定时器
        debounceTimers[key]?.invalidate()
        
        // 设置新的定时器
        debounceTimers[key] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                action()
                self.debounceTimers[key] = nil
            }
        }
    }
    
    // 异步任务管理
    func performTask(_ task: @escaping () async -> Void) {
        let newTask = Task {
            await task()
            removeTask()
        }
        
        addTask(newTask)
    }
    
    // 批量处理
    func processInBatches<T>(items: [T], batchSize: Int = 10, process: @escaping (T) async -> Void) async {
        for batch in items.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for item in batch {
                    group.addTask {
                        await process(item)
                    }
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupCache() {
        // 配置内存缓存
        memoryCache.totalCostLimit = maxCacheMemory
        memoryCache.countLimit = 100
        memoryCache.evictsObjectsWithDiscardedContent = true
        
        // 配置图片缓存
        imageCache.totalCostLimit = maxImageCache
        imageCache.countLimit = 50
        imageCache.evictsObjectsWithDiscardedContent = true
        
        // 配置数据缓存
        dataCache.totalCostLimit = maxDataCache
        dataCache.countLimit = 30
        dataCache.evictsObjectsWithDiscardedContent = true
    }
    
    private func setupPerformanceMonitoring() {
        startPerformanceMonitoring()
        
        // 监听性能变化
        $memoryUsage
            .combineLatest($cpuUsage)
            .sink { [weak self] memory, cpu in
                self?.updatePerformanceScore(memory: memory, cpu: cpu)
            }
            .store(in: &cancellables)
    }
    
    private func setupMemoryWarnings() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSApplicationDidReceiveMemoryWarningNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func setupOptimizations() {
        // 定期优化
        optimizationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performRoutineOptimization()
            }
        }
    }
    
    @MainActor
    private func updatePerformanceMetrics() {
        // 获取内存使用
        let memoryInfo = getMemoryInfo()
        memoryUsage = memoryInfo.used
        
        // 获取CPU使用
        cpuUsage = getCPUUsage()
        
        // 检查是否需要优化
        checkOptimizationNeeded()
    }
    
    private func getMemoryInfo() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return (usedMemory, totalMemory)
        }
        
        return (0, 0)
    }
    
    private func getCPUUsage() -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size / MemoryLayout<integer_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalTime = Double(info.user_time.seconds) + Double(info.system_time.seconds)
            return min(totalTime * 10, 100) // 简化计算
        }
        
        return 0
    }
    
    private func updatePerformanceScore(memory: Double, cpu: Double) {
        var score = 100
        
        // 内存影响
        if memory > memoryCriticalThreshold {
            score -= 40
        } else if memory > memoryWarningThreshold {
            score -= 20
        }
        
        // CPU影响
        if cpu > cpuCriticalThreshold {
            score -= 30
        } else if cpu > cpuWarningThreshold {
            score -= 15
        }
        
        performanceScore = max(0, score)
    }
    
    private func checkOptimizationNeeded() {
        if memoryUsage > memoryWarningThreshold || cpuUsage > cpuWarningThreshold {
            optimizeMemory()
        }
    }
    
    private func performMemoryOptimization() async {
        // 清理缓存
        clearAllCaches()
        
        // 取消低优先级任务
        cancelLowPriorityTasks()
        
        // 压缩内存
        compressMemory()
        
        // 等待系统回收内存
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
    }
    
    private func performRoutineOptimization() {
        // 检查内存使用
        if memoryUsage > memoryWarningThreshold {
            optimizeMemory()
        }
        
        // 清理过期缓存
        cleanupExpiredCache()
        
        // 优化任务队列
        optimizeTaskQueue()
    }
    
    private func handleMemoryWarning() {
        // 立即清理缓存
        clearAllCaches()
        
        // 取消非必要任务
        cancelNonEssentialTasks()
        
        // 通知其他组件
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
    }
    
    private func compressMemory() {
        // 压缩图片缓存 - NSCache 没有 objectEnumerator，使用其他方法
        autoreleasepool {
            // 清理部分缓存来释放内存
            imageCache.removeAllObjects()
            dataCache.removeAllObjects()
        }
    }
    
    private func compressImage(_ image: NSImage) -> NSImage? {
        // 简单的图片压缩逻辑
        let targetSize = NSSize(width: image.size.width * 0.8, height: image.size.height * 0.8)
        
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        newImage.unlockFocus()
        
        return newImage
    }
    
    private func cleanupExpiredCache() {
        // 清理过期对象
        memoryCache.removeAllObjects()
        
        // 清理图片缓存中的大对象
        if imageCache.totalCostLimit > maxImageCache {
            imageCache.removeAllObjects()
        }
        
        // 清理数据缓存中的大对象
        if dataCache.totalCostLimit > maxDataCache {
            dataCache.removeAllObjects()
        }
    }
    
    private func cancelLowPriorityTasks() {
        // 取消低优先级任务
        Task { @MainActor in
            self.activeTasks.forEach { task in
                if !task.isCancelled {
                    task.cancel()
                }
            }
            self.activeTasks.removeAll()
        }
    }
    
    private func cancelNonEssentialTasks() {
        // 取消所有非必要任务
        Task { @MainActor in
            self.activeTasks.forEach { task in
                task.cancel()
            }
            self.activeTasks.removeAll()
        }
    }
    
    private func optimizeTaskQueue() {
        // 限制并发任务数量
        if activeTasks.count > maxConcurrentTasks {
            let tasksToCancel = activeTasks.dropFirst(maxConcurrentTasks)
            tasksToCancel.forEach { $0.cancel() }
            activeTasks.subtract(tasksToCancel)
        }
    }
    
    private func addTask(_ task: Task<Void, Never>) {
        Task { @MainActor in
            self.activeTasks.insert(task)
        }
    }
    
    private func removeTask() {
        Task { @MainActor in
            // 清理已完成的任务
            self.activeTasks = self.activeTasks.filter { !$0.isCancelled }
        }
    }
    
    deinit {
        Task { @MainActor in
            self.stopPerformanceMonitoring()
            
            if let observer = self.memoryWarningObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            
            self.optimizationTimer?.invalidate()
            
            // 清理所有定时器
            self.throttleTimers.values.forEach { $0.invalidate() }
            self.debounceTimers.values.forEach { $0.invalidate() }
            
            // 取消所有任务
            self.activeTasks.forEach { $0.cancel() }
        }
    }
}

// MARK: - 扩展

extension Notification.Name {
    static let memoryWarning = Notification.Name("memoryWarning")
    static let performanceAlert = Notification.Name("performanceAlert")
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - 性能监控视图

struct PerformanceMonitorView: View {
    @StateObject private var optimizer = PerformanceOptimizer.shared
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 性能指示器
            HStack(spacing: 8) {
                performanceIndicator
                
                Text("Performance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showDetails.toggle()
                }) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showDetails ? 90 : 0))
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            if showDetails {
                performanceDetails
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var performanceIndicator: some View {
        Circle()
            .fill(performanceColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(performanceColor.opacity(0.3), lineWidth: 2)
                    .scaleEffect(1.5)
                    .opacity(optimizer.isOptimizing ? 1 : 0)
                    .animation(optimizer.isOptimizing ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: optimizer.isOptimizing)
            )
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
    
    private var performanceDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Memory")
                    .font(.caption)
                Spacer()
                Text(formatBytes(optimizer.memoryUsage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("CPU")
                    .font(.caption)
                Spacer()
                Text("\(Int(optimizer.cpuUsage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Score")
                    .font(.caption)
                Spacer()
                Text("\(optimizer.performanceScore)/100")
                    .font(.caption)
                    .foregroundColor(performanceColor)
            }
            
            if optimizer.performanceScore < 70 {
                Button(action: {
                    optimizer.optimizeMemory()
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Optimize")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.top, 8)
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        PerformanceMonitorView()
        
        HStack(spacing: 20) {
            Button("Optimize Memory") {
                PerformanceOptimizer.shared.optimizeMemory()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Clear Caches") {
                PerformanceOptimizer.shared.clearAllCaches()
            }
            .buttonStyle(.bordered)
        }
    }
    .padding()
}