# UnclutterPlus 日志使用规范

## 概述

本文档定义了 UnclutterPlus 项目的日志使用标准，确保所有日志记录统一、可控制和有意义的调试信息。

## 日志系统架构

### StructuredLogger

项目使用 `StructuredLogger` 作为统一的日志系统，提供以下特性：

- **日志级别控制**：可根据环境（Debug/Release）动态调整
- **结构化输出**：包含时间戳、级别、分类、文件位置
- **分类管理**：支持按模块分类（Storage、Service、UI等）
- **性能优化**：生产环境自动过滤低级别日志

## 日志级别

### 级别定义

| 级别 | 值 | 使用场景 | 示例 |
|------|-----|---------|------|
| **DEBUG** | 0 | 详细的调试信息，仅在开发环境使用 | 缓存命中、方法执行路径 |
| **INFO** | 1 | 重要的信息流，表示正常操作 | 服务启动、数据保存成功 |
| **WARNING** | 2 | 潜在问题，不影响功能 | 降级操作、重试机制触发 |
| **ERROR** | 3 | 错误但应用可继续运行 | 网络请求失败、文件读取失败 |
| **CRITICAL** | 4 | 严重错误，可能导致应用崩溃 | 核心服务初始化失败、数据损坏 |

### 级别控制策略

```swift
// Debug 模式：显示所有级别日志
#if DEBUG
minimumLevel = .debug
#else
// Release 模式：只显示 info 及以上级别
minimumLevel = .info
#endif
```

## 日志分类

| 分类 | 说明 | 典型场景 |
|------|------|---------|
| **General** | 通用日志 | 应用生命周期、配置加载 |
| **Storage** | 存储操作 | 文件读写、数据库操作、缓存管理 |
| **Service** | 业务服务 | 笔记创建、剪贴板管理、搜索服务 |
| **UI** | 界面交互 | 窗口显示、用户点击、菜单操作 |
| **Performance** | 性能监控 | 操作耗时、内存使用、缓存命中率 |
| **Security** | 安全相关 | 权限验证、数据加密、访问控制 |
| **Network** | 网络通信 | API 请求、数据同步（未来功能） |

## 使用指南

### 基本用法

```swift
// 导入 Logger
// （无需显式导入，已在全局命名空间）

// 记录信息
logger.info("用户登录成功", category: "Service")

// 记录警告
logger.warning("内存使用超过 80%", category: "Performance")

// 记录错误
logger.error("文件加载失败: \(error.localizedDescription)", category: "Storage")

// 记录严重错误
logger.critical("核心服务初始化失败", category: "Service")
```

### 正确的错误日志

```swift
// ✅ 推荐：捕获并记录详细错误信息
do {
    try await storage.save(note)
} catch {
    logger.error("保存笔记失败: \(error.localizedDescription)", category: "Storage")
}

// ❌ 避免：只记录简单消息
print("保存失败")
```

### 性能日志

```swift
// 使用 PerformanceMonitor 包装耗时操作
let measure = PerformanceMonitor(label: "笔记搜索")
let results = await searchNotes(query: "test")
measure.stop() // 自动记录耗时到 Performance 分类
```

### 调试日志

```swift
// Debug 级别日志只在开发环境显示
#if DEBUG
logger.debug("缓存状态: \(cache.description)", category: "Storage")
#endif
```

## 日志级别决策树

```
是否影响功能？
├─ 否 → DEBUG（详细调试信息）
└─ 是 → 是否需要用户干预？
   ├─ 否 → INFO（正常操作流程）
   ├─ 是 → 是否可自动恢复？
      ├─ 是 → WARNING（警告但可继续）
      └─ 否 → ERROR（错误但应用可继续）
         └─ 是否导致崩溃？→ CRITICAL（严重错误）
```

## 最佳实践

### 1. 使用适当的日志级别

```swift
// ✅ 正确：级别选择合理
logger.info("应用启动完成", category: "General")
logger.warning("使用降级策略：内存缓存", category: "Performance")
logger.error("网络请求失败: \(error)", category: "Network")

// ❌ 错误：级别滥用
logger.critical("按钮点击事件", category: "UI") // 应该是 DEBUG 或 INFO
logger.debug("数据库崩溃", category: "Storage") // 应该是 CRITICAL
```

### 2. 包含上下文信息

```swift
// ✅ 正确：包含关键上下文
logger.error("加载笔记失败 [ID: \(noteId)]: \(error.localizedDescription)", category: "Storage")

// ❌ 错误：缺少上下文
logger.error("加载失败", category: "Storage")
```

### 3. 避免重复日志

```swift
// ✅ 正确：在一处记录
func saveNote(_ note: Note) async throws {
    try await storage.save(note)
    // 只在这里记录成功
    logger.info("笔记保存成功: \(note.title)", category: "Service")
}

// ❌ 错误：多层重复记录
func saveNote(_ note: Note) async throws {
    logger.info("准备保存笔记", category: "Service") // 多余
    try await storage.save(note) // 内部也会记录
    logger.info("笔记保存成功", category: "Service")
}
```

### 4. 敏感信息保护

```swift
// ✅ 正确：脱敏敏感信息
logger.info("用户登录: \(User.maskedEmail)", category: "Security")

// ❌ 错误：记录完整敏感信息
logger.info("用户登录: \(user.password)", category: "Security")
```

### 5. 性能考虑

```swift
// ✅ 正确：避免在热路径中使用复杂日志
for item in items {
    process(item)
}
// 批量记录
logger.info("处理了 \(items.count) 个项目", category: "Performance")

// ❌ 错误：在循环中频繁记录
for item in items {
    logger.debug("处理项目: \(item.id)", category: "Performance") // 性能影响
    process(item)
}
```

## 禁止事项

### ❌ 禁止使用 print()

```swift
// ❌ 错误：使用 print()
print("应用启动")
print("错误: \(error)")

// ✅ 正确：使用 StructuredLogger
logger.info("应用启动", category: "General")
logger.error("错误: \(error.localizedDescription)", category: "Service")
```

### ❌ 禁止吞掉错误

```swift
// ❌ 错误：只打印错误但不处理
do {
    try riskyOperation()
} catch {
    print("错误: \(error)") // 错误信息丢失
}

// ✅ 正确：记录并传播错误
do {
    try await riskyOperation()
} catch {
    logger.error("操作失败: \(error.localizedDescription)", category: "Service")
    throw error // 继续传播给调用者
}
```

### ❌ 禁止在日志中执行耗时操作

```swift
// ❌ 错误：日志中包含耗时计算
logger.debug("缓存详情: \(cache.generateDetailedReport())", category: "Storage")

// ✅ 正确：延迟计算或使用惰性求值
if logger.isEnabled(level: .debug) {
    let report = cache.generateDetailedReport()
    logger.debug("缓存详情: \(report)", category: "Storage")
}
```

## 单元测试中的日志

### 禁用日志输出

在单元测试中，建议禁用日志以保持测试输出清晰：

```swift
// 在测试设置中临时提升日志级别
#if DEBUG
// 测试时只显示错误及以上级别
StructuredLogger.shared.minimumLevel = .error
#endif
```

### 验证日志调用

使用 Mock 验证日志调用：

```swift
func testSaveNoteLogsSuccess() async throws {
    // given
    let mockLogger = MockLogger()
    let note = Note(title: "Test")

    // when
    try await service.save(note)

    // then
    XCTAssertTrue(mockLogger.didLog("笔记保存成功", level: .info))
}
```

## 常见问题

### Q: 为什么不直接使用 print()？

**A**: `print()` 有以下缺点：
1. 无法控制日志级别（开发/生产环境无法区分）
2. 缺少结构化信息（时间戳、分类、文件位置）
3. 性能无法优化（始终执行字符串拼接）
4. 难以集成到日志收集系统

### Q: 何时使用 DEBUG vs INFO？

**A**:
- **DEBUG**: 开发者需要了解的内部细节（缓存状态、方法执行路径）
- **INFO**: 用户可能关心的正常操作流程（应用启动、功能使用）

### Q: 错误应该记录多少次？

**A**: 遵循"就近捕获，一次记录"原则：
1. 在捕获错误的最近处记录详细信息
2. 向上传播时不要再重复记录
3. 只有在处理策略不同时才补充记录

### Q: 如何避免日志过多？

**A**:
1. 使用适当的日志级别（Release 模式自动过滤 DEBUG）
2. 批量操作时记录摘要而非每个条目
3. 避免在循环中记录日志

## 迁移指南

### 从 print() 迁移到 StructuredLogger

```swift
// 旧代码
print("✅ 服务启动成功")
print("❌ 加载失败: \(error)")
print("⚠️ 内存使用高")

// 新代码
logger.info("服务启动成功", category: "Service")
logger.error("加载失败: \(error.localizedDescription)", category: "Service")
logger.warning("内存使用超过阈值", category: "Performance")
```

### 常见模式替换

| 旧模式 | 新模式 |
|--------|--------|
| `print("✅ ...")` | `logger.info("...", category: "...")` |
| `print("❌ ...")` | `logger.error("...", category: "...")` |
| `print("⚠️ ...")` | `logger.warning("...", category: "...")` |
| `print("📱 ...")` | `logger.info("...", category: "UI")` |
| `print("💾 ...")` | `logger.info("...", category: "Storage")` |

## 参考资源

- [Swift Logging 最佳实践](https://developer.apple.com/documentation/os/logging)
- [结构化日志设计](https://www.datadoghq.com/blog/engineering/structured-logging/)
- 项目文件：`Sources/UnclutterPlus/Core/Utils/Logger.swift`

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2025-12-24 | 初始版本，定义 StructuredLogger 使用规范 |
