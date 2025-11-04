让我深度分析 UnclutterPlus 的业务逻辑和数据存储需求。

  🎯 UnclutterPlus 核心业务逻辑分析

  产品定位

  UnclutterPlus 是一个生产力工具集合，通过统一的悬浮窗口提供快速访问的功能：
  - 临时文件收纳（Files）- 桌面清理的替代方案
  - 剪贴板历史（Clipboard）- 增强的复制粘贴体验
  - 快速笔记（Notes）- 随手记录想法
  - 截图管理（Screenshots）- 快速截图和注释

  核心使用场景

  1. 高频短时操作
    - 用户通过鼠标移至屏幕顶部快速呼出窗口
    - 执行操作后窗口自动隐藏
    - 强调速度和流畅性
  2. 数据生命周期特征
  Files:       临时存放 → 短期访问 → 归档/删除
  Clipboard:   自动收集 → 短期重用 → 自动过期
  Notes:       快速记录 → 长期保存 → 偶尔编辑
  Screenshots: 即时捕获 → 短期标注 → 导出/删除
  3. 数据访问模式
    - 写入频率: Clipboard（高）> Notes（中）> Files（低）> Screenshots（低）
    - 读取频率: Files（高）> Clipboard（高）> Notes（中）> Screenshots（低）
    - 数据量级: Notes（大）> Screenshots（大）> Clipboard（中）> Files（小）
    - 持久化需求: Notes（永久）> Files（长期）> Screenshots（中期）> Clipboard（短期）

  🏗️ 数据存储架构设计

  基于业务特点，我建议采用分层混合存储架构：

  1. 内存层（Hot Data）

  // 运行时缓存 - 最近访问的数据
  class MemoryCache {
      // 最近 20 个剪贴板项目（频繁访问）
      var recentClipboardItems: LRUCache<UUID, ClipboardItem>(maxSize: 20)

      // 最近打开的 10 个笔记（避免重复加载）
      var openNotes: LRUCache<UUID, Note>(maxSize: 10)

      // 所有文件夹快捷方式（数量少，常驻内存）
      var favoriteFolders: [FavoriteFolder]

      // 今日截图缩略图（快速预览）
      var todayScreenshots: [ScreenshotThumbnail]
  }

  2. 索引层（Warm Data）

  // 轻量级索引 - 快速查询和过滤
  struct IndexDatabase {
      // SQLite 索引数据库
      let db = SQLite3Database("index.db")

      // 笔记索引表
      CREATE TABLE note_index (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          modified_at INTEGER,
          tags TEXT,  -- JSON array
          is_favorite INTEGER,
          word_count INTEGER,
          preview TEXT,
          FULLTEXT(title, preview)  -- 全文搜索
      );

      // 剪贴板索引表
      CREATE TABLE clipboard_index (
          id TEXT PRIMARY KEY,
          type TEXT,  -- text/image/file
          timestamp INTEGER,
          source_app TEXT,
          use_count INTEGER,
          preview TEXT,
          is_pinned INTEGER
      );

      // 截图索引表
      CREATE TABLE screenshot_index (
          id TEXT PRIMARY KEY,
          timestamp INTEGER,
          type TEXT,  -- region/window/screen
          has_annotation INTEGER,
          thumbnail BLOB  -- 小尺寸缩略图
      );
  }

  3. 存储层（Cold Data）

  // 完整数据存储 - 按需加载
  struct FileStorage {
      // 目录结构
      UnclutterPlus/
      ├── Config/
      │   └── settings.json      // 用户设置
      │
      ├── Files/
      │   └── folders.json       // 文件夹快捷方式列表
      │
      ├── Clipboard/
      │   ├── items/            // 分片存储
      │   │   ├── 2024-11/      // 按月分组
      │   │   │   ├── [UUID].json
      │   │   │   └── ...
      │   │   └── 2024-10/
      │   └── images/           // 图片文件
      │       └── [UUID].png
      │
      ├── Notes/
      │   ├── notes/            // 笔记内容
      │   │   ├── [UUID].md     // 纯 Markdown 文件
      │   │   └── ...
      │   └── attachments/      // 笔记附件
      │       └── [UUID]/
      │
      └── Screenshots/
          ├── 2024-11/          // 按月分组
          │   ├── [UUID].png    // 原始图片
          │   └── [UUID].json   // 元数据
          └── thumbnails/       // 缩略图缓存
              └── [UUID]_thumb.jpg
  }

  💾 具体存储策略

  ClipboardManager - 时间序列存储

  class ClipboardStorage {
      // 三级存储策略
      private let memoryCache = LRUCache<UUID, ClipboardItem>(maxSize: 20)
      private let indexDB = SQLiteIndex()
      private let fileStorage = FileStorage()

      func addItem(_ item: ClipboardItem) {
          // 1. 添加到内存缓存
          memoryCache.set(item.id, item)

          // 2. 异步更新索引
          Task.detached(priority: .utility) {
              await self.indexDB.insertItem(item.toIndex())
          }

          // 3. 批量持久化（2秒防抖）
          schedulePersistence(item)
      }

      func getItems(limit: Int = 50) -> [ClipboardItem] {
          // 1. 从索引获取最近 ID 列表
          let recentIDs = indexDB.getRecentItemIDs(limit: limit)

          // 2. 从内存缓存获取
          var items: [ClipboardItem] = []
          var missingIDs: [UUID] = []

          for id in recentIDs {
              if let cached = memoryCache.get(id) {
                  items.append(cached)
              } else {
                  missingIDs.append(id)
              }
          }

          // 3. 批量加载缺失项
          if !missingIDs.isEmpty {
              let loaded = fileStorage.loadItems(ids: missingIDs)
              items.append(contentsOf: loaded)
              // 预热缓存
              loaded.forEach { memoryCache.set($0.id, $0) }
          }

          return items.sorted { $0.timestamp > $1.timestamp }
      }

      // 自动清理策略
      func autoCleanup() {
          // 删除 30 天前的非置顶项目
          let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
          indexDB.deleteItemsBefore(cutoffDate, excludePinned: true)
          fileStorage.deleteItemsBefore(cutoffDate, excludePinned: true)
      }
  }

  NotesManager - 文档数据库模式

  class NotesStorage {
      // 索引 + 内容分离
      private let indexDB = SQLiteIndex()       // 元数据和搜索
      private let contentCache = LRUCache<UUID, Note>(maxSize: 10)
      private let fileStorage = MarkdownStorage()

      func loadNotes() -> [NoteIndex] {
          // 只加载索引，不加载内容
          return indexDB.getAllNoteIndexes()
      }

      func getNote(id: UUID) -> Note? {
          // 1. 检查缓存
          if let cached = contentCache.get(id) {
              return cached
          }

          // 2. 从文件加载
          guard let content = fileStorage.loadMarkdown(id: id) else {
              return nil
          }

          // 3. 组合索引和内容
          let index = indexDB.getNoteIndex(id: id)
          let note = Note(index: index, content: content)

          // 4. 更新缓存
          contentCache.set(id, note)

          return note
      }

      func saveNote(_ note: Note) {
          // 1. 更新缓存
          contentCache.set(note.id, note)

          // 2. 异步保存
          Task.detached(priority: .utility) {
              // 保存索引（快速）
              await self.indexDB.upsertNoteIndex(note.toIndex())

              // 保存内容（可能较慢）
              await self.fileStorage.saveMarkdown(
                  id: note.id,
                  content: note.content
              )
          }
      }

      func searchNotes(query: String) -> [NoteIndex] {
          // 利用 SQLite FTS5 全文搜索
          return indexDB.searchNotes(query: query)
      }
  }

  统一的数据访问层

  protocol DataRepository {
      associatedtype Item
      associatedtype Index

      func create(_ item: Item) async throws
      func read(id: UUID) async throws -> Item?
      func update(_ item: Item) async throws
      func delete(id: UUID) async throws
      func search(query: String) async throws -> [Index]
      func list(limit: Int, offset: Int) async throws -> [Index]
  }

  // 实现示例
  class NoteRepository: DataRepository {
      typealias Item = Note
      typealias Index = NoteIndex

      private let storage = NotesStorage()

      func create(_ note: Note) async throws {
          await storage.saveNote(note)
      }

      // ... 其他方法实现
  }

  🚀 性能优化策略

  1. 读取优化

  - 索引预加载: 启动时只加载索引，内容按需加载
  - 智能预取: 根据用户习惯预加载可能访问的内容
  - 并行加载: 多个文件并行读取
  let notes = await withTaskGroup(of: Note?.self) { group in
      for id in noteIDs {
          group.addTask { await self.loadNote(id: id) }
      }
      return await group.compactMap { $0 }.reduce(into: []) { $0.append($1) }
  }

  2. 写入优化

  - 写入合并: 批量写入减少 I/O 次数
  - Copy-on-Write: 只保存变化的部分
  - 异步持久化: 后台线程执行，不阻塞 UI

  3. 内存优化

  - LRU 缓存: 自动淘汰最少使用的项目
  - 弱引用: 大对象使用弱引用避免内存泄漏
  - 压缩存储: 文本内容压缩存储

  📊 监控与维护

  class StorageMonitor {
      func getMetrics() -> StorageMetrics {
          return StorageMetrics(
              totalSize: calculateTotalSize(),
              noteCount: indexDB.getNoteCount(),
              clipboardCount: indexDB.getClipboardCount(),
              cacheHitRate: memoryCache.hitRate,
              averageLoadTime: performanceMonitor.averageLoadTime
          )
      }

      func performMaintenance() {
          // 每天执行一次
          Task {
              await vacuumDatabase()      // 压缩数据库
              await cleanupOldFiles()      // 清理过期文件
              await rebuildIndexes()       // 重建索引
              await optimizeCache()        // 优化缓存
          }
      }
  }

  🔄 迁移路径

  第一阶段：索引分离（1 周）

  1. 创建 SQLite 索引数据库
  2. 保持现有 JSON 存储
  3. 双写模式（同时更新索引和 JSON）

  第二阶段：存储优化（2 周）

  1. 实现分片存储（笔记、剪贴板）
  2. 添加 LRU 内存缓存
  3. 实现异步 I/O

  第三阶段：性能调优（1 周）

  1. 添加监控指标
  2. 优化查询性能
  3. 实现自动维护

  💡 核心设计原则

  1. 分层存储: 热数据内存 → 温数据索引 → 冷数据文件
  2. 索引优先: 元数据和内容分离，优先加载索引
  3. 异步为主: 所有 I/O 操作异步执行
  4. 增量更新: 只保存变化部分，避免全量重写
  5. 智能缓存: LRU + 预取策略
  6. 自动维护: 定期清理和优化

  这个架构能够：
  - ✅ 支持 10000+ 笔记的快速搜索
  - ✅ 毫秒级的界面响应
  - ✅ 最小化内存占用
  - ✅ 优秀的扩展性
  - ✅ 数据安全性保障

  您觉得这个存储架构设计如何？需要我详细展开某个部分的实现吗？