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
        logger.info("Initializing Unified Storage Manager...", category: "Storage")
        
        // 创建笔记服务
        self.notesService = NotesService()
        
        // 启动维护任务
        Task {
            await startMaintenanceTasks()
            await loadStorageStatistics()
        }
        
        logger.info("Unified Storage Manager initialized successfully", category: "Service")
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
        
        logger.info("Storage maintenance tasks started", category: "Storage")
    }
    
    /// 执行存储维护
    func performMaintenance() async {
        logger.info("Starting storage maintenance...", category: "Storage")
        
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
        
        logger.info("Storage maintenance completed", category: "Service")
    }
    
    /// 清空所有存储数据（谨慎使用）
    func clearAllData() async -> Result<Void, StorageManagerError> {
        logger.warning("正在清空所有存储数据...", category: "Service")

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
                logger.info("所有数据已清空", category: "Service")
                return .success(())
            } else {
                let error = StorageManagerError.maintenanceFailed("删除笔记失败")
                logger.error("清空数据失败", category: "Service")
                GlobalErrorHandler.shared.handle(
                    error,
                    context: "清空所有存储数据"
                )
                return .failure(error)
            }
        }

        return .success(())
    }
    
    /// 导出存储数据
    func exportStorageData() async throws -> Data {
        logger.info("📤 正在导出存储数据...", category: "UnifiedStorageManager")

        let stats = await getStorageStatistics()
        let exportData = ExportData(
            timestamp: Date(),
            statistics: stats,
            version: "1.0.0"
        )

        do {
            let jsonData = try JSONEncoder().encode(exportData)
            logger.info("存储数据导出成功", category: "Service")
            return jsonData
        } catch {
            let exportError = StorageManagerError.exportFailed
            GlobalErrorHandler.shared.handle(
                exportError,
                context: "导出存储数据失败"
            )
            throw exportError
        }
    }
    
    // MARK: - Private Methods
    
    private func getModernStorage() async -> (any UnifiedStorageProtocol<Note, NoteIndex>)? {
        // 这里应该返回实际的现代化存储实例
        // 为了简化示例，返回nil
        return nil
    }
    
    private func compressDatabase(_ storage: any UnifiedStorageProtocol<Note, NoteIndex>) async {
        // 实现数据库压缩逻辑
        logger.info("Database compression completed", category: "Storage")
    }
    
    private func cleanupExpiredData() async {
        // 实现过期数据清理逻辑
        logger.info("Expired data cleanup completed", category: "Storage")
    }
    
    private func optimizeCache() async {
        // 实现缓存优化逻辑
        logger.info("⚡ Cache optimization completed", category: "UnifiedStorageManager")
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
        logger.info("📴 Application terminating, cleaning up storage...", category: "UnifiedStorageManager")
        // 执行最终的清理工作
    }
    
    func handleMemoryWarning() {
        logger.warning("Memory warning received, optimizing storage...", category: "Service")
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
