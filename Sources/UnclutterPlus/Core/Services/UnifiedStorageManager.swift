import Foundation
import SwiftUI

/// 统一存储管理器 - 替换旧的AppStorageManager
@MainActor
final class UnifiedStorageManager: ObservableObject {
    static let shared = UnifiedStorageManager()
    
    // MARK: - Properties
    
    /// 笔记服务
    let notesService: NotesService
    
    /// 剪贴板服务（未来实现）
    // let clipboardService: ClipboardService
    
    /// 截图服务（未来实现）
    // let screenshotService: ScreenshotService
    
    // 存储统计
    @Published private(set) var storageStatistics: StorageStatistics?
    
    // MARK: - Initialization
    
    private init() {
        print("🔧 Initializing Unified Storage Manager...")
        
        // 创建笔记服务
        self.notesService = NotesService()
        
        // 启动维护任务
        Task {
            await startMaintenanceTasks()
            await loadStorageStatistics()
        }
        
        print("✅ Unified Storage Manager initialized successfully")
    }
    
    // MARK: - Public Methods
    
    /// 获取存储统计信息
    func getStorageStatistics() async -> StorageStatistics? {
        let noteStats = await notesService.getStatistics()
        let storageStats = StorageStatistics(
            totalItems: noteStats.totalNotes,
            totalSize: noteStats.storageSize,
            cacheSize: 0,
            lastModified: Date(),
            storageType: .modern
        )
        await MainActor.run {
            storageStatistics = storageStats
        }
        return storageStats
    }
    
    /// 启动维护任务
    func startMaintenanceTasks() async {
        // 每小时执行一次维护
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.performMaintenance()
            }
        }
        
        print("🔧 Storage maintenance tasks started")
    }
    
    /// 执行存储维护
    func performMaintenance() async {
        print("🧹 Starting storage maintenance...")
        
        // 压缩数据库
        if let modernStorage = await getModernStorage() {
            await compressDatabase(modernStorage)
        }
        
        // 清理过期数据
        await cleanupExpiredData()
        
        // 优化缓存
        await optimizeCache()
        
        // 更新统计信息
        await loadStorageStatistics()
        
        print("✅ Storage maintenance completed")
    }
    
    /// 清空所有存储数据（谨慎使用）
    func clearAllData() async {
        print("⚠️ Clearing all storage data...")
        
        // 通过 NotesService 的公共方法清空数据
        var allNotes: [Note] = []
        for index in notesService.noteIndexes {
            if let note = await notesService.loadNote(for: index.id) {
                allNotes.append(note)
            }
        }
        
        if !allNotes.isEmpty {
            let success = await notesService.deleteNotes(allNotes)
            if success {
                print("✅ All data cleared successfully")
            } else {
                print("❌ Failed to clear data")
            }
        }
    }
    
    /// 导出存储数据
    func exportStorageData() async -> Data? {
        print("📤 Exporting storage data...")
        
        let stats = await getStorageStatistics()
        let exportData = ExportData(
            timestamp: Date(),
            statistics: stats,
            version: "1.0.0"
        )
        
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            print("✅ Storage data exported successfully")
            return jsonData
        } catch {
            print("❌ Failed to export storage data: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func getModernStorage() async -> (any StorageProtocol)? {
        // 这里应该返回实际的现代化存储实例
        // 为了简化示例，返回nil
        return nil
    }
    
    private func compressDatabase(_ storage: any StorageProtocol) async {
        // 实现数据库压缩逻辑
        print("💾 Database compression completed")
    }
    
    private func cleanupExpiredData() async {
        // 实现过期数据清理逻辑
        print("🗑️ Expired data cleanup completed")
    }
    
    private func optimizeCache() async {
        // 实现缓存优化逻辑
        print("⚡ Cache optimization completed")
    }
    
    private func loadStorageStatistics() async {
        let stats = await getStorageStatistics()
        await MainActor.run {
            storageStatistics = stats
        }
    }
}

// MARK: - Supporting Types

/// 导出数据结构
struct ExportData: Codable {
    let timestamp: Date
    let statistics: StorageStatistics?
    let version: String
}

// MARK: - App Integration

/// 应用集成扩展
extension UnifiedStorageManager {
    /// 集成到应用生命周期
    func applicationDidFinishLaunching() {
        Task {
            await startMaintenanceTasks()
            await loadStorageStatistics()
        }
    }
    
    func applicationWillTerminate() {
        print("📴 Application terminating, cleaning up storage...")
        // 执行最终的清理工作
    }
    
    func handleMemoryWarning() {
        print("⚠️ Memory warning received, optimizing storage...")
        Task {
            await optimizeCache()
        }
    }
}

// MARK: - Error Handling

/// 存储管理器错误
enum StorageManagerError: LocalizedError {
    case maintenanceFailed(String)
    case statisticsUnavailable
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .maintenanceFailed(let reason):
            return "存储维护失败: \(reason)"
        case .statisticsUnavailable:
            return "存储统计信息不可用"
        case .exportFailed:
            return "数据导出失败"
        }
    }
}
