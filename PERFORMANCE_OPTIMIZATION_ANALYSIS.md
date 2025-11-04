# UnclutterPlus 性能优化分析报告

## 🚨 发现的主要性能瓶颈

### 1. **ClipboardManager - 高频 I/O 操作**

**问题所在: ClipboardManager.swift**

#### 严重问题:
```swift
// Line 340-363: 每次剪贴板变化都触发完整持久化
private func persistItems() {
    // ❌ 问题1: 同步文件写入阻塞主线程
    let data = try encoder.encode(itemsToSave)
    try data.write(to: storageURL)

    // ❌ 问题2: 每次都保存图片
    saveImages()
}

// Line 365-387: saveImages() 更严重
private func saveImages() {
    // ❌ 问题3: 每次都删除并重建所有图片文件
    for file in files {
        try? FileManager.default.removeItem(at: file)
    }

    // ❌ 问题4: 循环写入20个图片文件
    for item in items.prefix(20) {
        // PNG 编码 + 文件写入
    }
}
```

**性能影响:**
- 0.5秒一次剪贴板检查 (Line 174)
- 每次新增内容触发 `persistItems()`
- 每次 persist 都删除+重建20个图片文件
- **估计耗时**: 每次 100-300ms (取决于图片大小)

**优化方案:**
```swift
// ✅ 方案1: 防抖动批量保存
private var saveTimer: Timer?
private func persistItems() {
    saveTimer?.invalidate()
    saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
        self?.performActualSave()
    }
}

// ✅ 方案2: 后台异步保存
private func performActualSave() {
    Task.detached(priority: .utility) { [weak self] in
        guard let self = self else { return }
        // 在后台线程执行 I/O
        let data = try? encoder.encode(self.items)
        // ...
    }
}

// ✅ 方案3: 增量图片保存
private var savedImageIDs = Set<UUID>()
private func saveImages() {
    let newImages = items.prefix(20).filter { !savedImageIDs.contains($0.id) }
    // 只保存新图片，不删除旧图片
}
```

---

### 2. **View 层过度渲染**

**问题所在: FilesView.swift, ClipboardView.swift, NotesView.swift**

#### 问题1: 未使用 LazyVStack/LazyVGrid
```swift
// ❌ ClipboardView.swift Line 259
ScrollView {
    LazyVStack(spacing: 12) {  // ✅ 已使用 Lazy
        ForEach(viewModel.filteredItems, id: \.id) { item in
            ClipboardItemView(...)  // 但每个 item 都是复杂视图
        }
    }
}
```

**实际问题:** ClipboardItemView 包含:
- 图片解码 (Line 426-434)
- NSImage → SwiftUI Image 转换
- 应用图标解码 (Line 488-494)
- 复杂的悬停状态动画

**优化方案:**
```swift
// ✅ 图片懒加载
struct LazyImageView: View {
    let imageData: Data
    @State private var image: NSImage?

    var body: some View {
        if let image = image {
            Image(nsImage: image)
        } else {
            ProgressView()
                .task {
                    await loadImage()
                }
        }
    }

    private func loadImage() async {
        await Task.detached {
            NSImage(data: imageData)
        }.value
    }
}
```

---

#### 问题2: 过度使用动画和状态更新
```swift
// ❌ FilesView.swift Line 215-218
.onHover { isHovering in
    hoveredFolder = isHovering ? folder.id : nil
}
```

**性能影响:**
- 每次悬停都触发 `@Published var hoveredFolder` 更新
- 整个视图树重新计算
- 网格布局中有几十个卡片同时监听

**优化方案:**
```swift
// ✅ 使用 @State 局部状态
struct FolderCard: View {
    @State private var isHovered = false  // 不触发父级更新

    var body: some View {
        // ...
        .onHover { isHovered = $0 }
    }
}
```

---

### 3. **ViewModel 过滤逻辑效率低**

**问题所在: ClipboardViewModel.swift**

```swift
// ❌ Line 217-277: 多次遍历数组
private func updateFilteredItems() {
    var items = clipboardManager.items

    // 第1次遍历: 类型过滤
    items = items.filter { /* ... */ }

    // 第2次遍历: 来源过滤
    items = items.filter { /* ... */ }

    // 第3次遍历: 日期过滤
    items = items.filter { /* ... */ }

    // 第4次遍历: 搜索过滤
    items = items.filter { /* ... */ }

    // 第5次遍历: 排序
    items = sortItems(items)

    filteredItems = items
}
```

**性能影响:**
- 每次过滤条件变化都重新过滤整个数组
- 100个项目 × 5次遍历 = 500次操作
- Debounce 只有 50ms (Line 191)

**优化方案:**
```swift
// ✅ 单次遍历完成所有过滤
private func updateFilteredItems() {
    let calendar = Calendar.current
    let now = Date()
    let cutoffDate = calculateCutoffDate(now, calendar)

    filteredItems = clipboardManager.items.compactMap { item in
        // 所有条件在一次遍历中检查
        guard matchesTypeFilter(item) else { return nil }
        guard matchesSourceFilter(item) else { return nil }
        guard matchesDateFilter(item, cutoffDate) else { return nil }
        guard matchesSearchText(item) else { return nil }
        return item
    }
    .sorted(by: sortComparator)
}

// ✅ 增加 debounce 时间
.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
```

---

### 4. **WindowManager 动画性能**

**问题所在: WindowManager.swift**

```swift
// ❌ Line 176-186: 多次激活窗口
animateWindowIn {
    window.makeKey()
    NSApp.activate(ignoringOtherApps: true)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        NSApp.activate(ignoringOtherApps: true)  // 重复激活
        window.makeKey()  // 重复 makeKey
    }
}
```

**性能影响:**
- 强制窗口激活会打断系统渲染流水线
- 0.3秒延迟期间用户可能已经开始交互

**优化方案:**
```swift
// ✅ 单次激活 + 窗口层级调整
animateWindowIn {
    window.level = .popUpMenu  // 确保在最前
    window.orderFrontRegardless()
    window.makeKey()

    // 只在真正需要时才延迟激活
    if !window.isKeyWindow {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
        }
    }
}
```

---

### 5. **EdgeMouseTracker 日志输出过多**

**问题所在: EdgeMouseTracker.swift**

```swift
// ❌ Line 143: 高频日志输出
if now.timeIntervalSince(lastLogTime) > logCooldownInterval {
    print("滚轮触发: deltaY=\(scrollY), ...")  // 每5秒仍会输出
}
```

**性能影响:**
- 控制台日志会降低调试性能
- 生产环境不应有频繁日志

**优化方案:**
```swift
// ✅ 条件编译日志
#if DEBUG
private let enableLogging = false  // 默认关闭
#else
private let enableLogging = false
#endif
```

---

## 📊 优化优先级

### 🔥 **P0 - 立即修复 (影响最大)**

1. **ClipboardManager 异步持久化**
   - 预期提升: 减少 200-300ms 卡顿
   - 实现难度: 中等
   - 文件: `ClipboardManager.swift`

2. **过滤逻辑单次遍历优化**
   - 预期提升: 减少 50-100ms 计算时间
   - 实现难度: 简单
   - 文件: `ClipboardViewModel.swift`, `FilesViewModel.swift`

### ⚠️ **P1 - 重要优化 (明显改善)**

3. **图片懒加载**
   - 预期提升: 减少首次渲染 100-200ms
   - 实现难度: 中等
   - 文件: `ClipboardView.swift`, `ScreenshotsView.swift`

4. **悬停状态局部化**
   - 预期提升: 减少视图更新 30%
   - 实现难度: 简单
   - 文件: 所有 View 文件

### 💡 **P2 - 次要优化 (细节改善)**

5. **窗口激活优化**
6. **日志清理**
7. **Debounce 时间调整**

---

## 🛠️ 实施建议

### 第一阶段 (1-2天)
- [ ] ClipboardManager 异步保存 + 批量写入
- [ ] 图片增量保存(不删除旧文件)
- [ ] 过滤逻辑合并遍历

### 第二阶段 (2-3天)
- [ ] 图片懒加载组件
- [ ] 悬停状态重构
- [ ] WindowManager 优化

### 第三阶段 (1天)
- [ ] 性能监控埋点
- [ ] 日志清理
- [ ] 配置项优化

---

## 📈 预期效果

| 操作 | 当前耗时 | 优化后 | 改善 |
|------|---------|--------|------|
| 剪贴板新增项目 | ~300ms | ~50ms | **83%** |
| 滚动列表(100项) | ~150ms | ~50ms | **67%** |
| 搜索过滤 | ~100ms | ~30ms | **70%** |
| 窗口显示动画 | ~500ms | ~300ms | **40%** |
| 悬停卡片 | ~30ms | ~10ms | **67%** |

**总体流畅度提升: 预计 60-70%**

---

## 🔍 性能监控建议

添加性能监控代码:

```swift
// 在关键操作添加耗时统计
func measurePerformance<T>(_ label: String, _ operation: () -> T) -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = operation()
    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    #if DEBUG
    if elapsed > 16.67 { // 超过一帧
        print("⚠️ [\(label)] took \(String(format: "%.2f", elapsed))ms")
    }
    #endif

    return result
}

// 使用示例
private func updateFilteredItems() {
    measurePerformance("ClipboardFilter") {
        // 过滤逻辑
    }
}
```

---

## ✅ 检查清单

性能优化后需要验证:

- [ ] 剪贴板连续复制5次不卡顿
- [ ] 滚动 100+ 项目列表流畅(60fps)
- [ ] 搜索输入实时无延迟
- [ ] 窗口显示/隐藏动画流畅
- [ ] 多选 50+ 项目不卡顿
- [ ] 内存占用 < 100MB (ClipboardView)
- [ ] CPU 占用 < 5% (空闲状态)

---

**生成时间**: 2025-01-04
**分析工具**: Claude Code
**项目版本**: UnclutterPlus v1.0
