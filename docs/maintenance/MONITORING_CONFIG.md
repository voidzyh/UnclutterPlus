# UnclutterPlus 持续监控配置指南

## 📋 监控组件概述

UnclutterPlus v2.0.0 已建立完整的持续监控体系，包括：

### 1. 性能监控 (`performance_monitor.sh`)
- **功能**: 实时跟踪构建时间、包大小等性能指标
- **特点**: 自动检测性能回归，生成趋势报告
- **频率**: 每次构建后自动运行

### 2. 测试覆盖率监控 (`coverage_monitor.sh`)
- **功能**: 监控单元测试和集成测试覆盖率
- **特点**: 文件级覆盖率分析，趋势跟踪
- **频率**: 每次测试运行后自动执行

### 3. CI/CD 管道 (`.github/workflows/ci-cd.yml`)
- **功能**: 自动化构建、测试、部署
- **触发条件**: 提交、PR、发布
- **特性**: 并行构建、覆盖率报告、安全扫描

## 🚀 快速开始

### 1. 手动运行监控脚本

```bash
# 运行性能监控
./performance_monitor.sh

# 运行测试覆盖率监控
./coverage_monitor.sh

# 组合运行（完整检查）
./performance_benchmark.sh && ./coverage_monitor.sh
```

### 2. 设置自动化监控

在 `crontab` 中添加定期监控任务：

```bash
# 每天凌晨2点运行性能监控
0 2 * * * /path/to/UnclutterPlus/performance_monitor.sh

# 每周日上午10点运行覆盖率检查
0 10 * * 0 /path/to/UnclutterPlus/coverage_monitor.sh
```

### 3. GitHub Actions 集成

监控脚本已集成到 CI/CD 流程：

```yaml
# .github/workflows/ci-cd.yml 中的相关任务
performance-benchmark:
  name: 性能基准测试
  steps:
    - name: 运行性能监控
      run: ./performance_monitor.sh

    - name: 上传性能报告
      uses: actions/upload-artifact@v3
      with:
        name: performance-report
        path: performance_report_*.md
```

## 📊 监控指标

### 性能指标
| 指标 | 目标值 | 告警阈值 |
|------|--------|----------|
| 构建时间 | <120秒 | >180秒 |
| 包大小 | <200MB | >300MB |
| 启动时间 | <3秒 | >5秒 |
| 内存使用 | <100MB | >150MB |

### 测试覆盖率指标
| 等级 | 范围 | 状态 |
|------|------|------|
| 优秀 | >=80% | ✅ 达标 |
| 良好 | 70%-79% | ⚠️ 需改进 |
| 不足 | <70% | ❌ 不达标 |

## 📈 历史数据

### 存储位置
- **性能历史**: `performance_history.json`
- **覆盖率历史**: `coverage_history.json`
- **告警日志**: `performance_alerts.log`

### 数据格式
```json
{
  "builds": [
    {
      "timestamp": "2025-11-28T13:50:00Z",
      "build_time": 25000,
      "package_size": 6311111
    }
  ],
  "alerts": ["性能回归警告: 构建时间增加 20% 以上"]
}
```

## 🔔 告警机制

### 告警类型
1. **性能回归**: 构建时间或包大小显著增加
2. **覆盖率下降**: 测试覆盖率低于阈值
3. **构建失败**: 构建或测试执行失败

### 通知方式
- **控制台输出**: 脚本直接显示告警信息
- **日志文件**: 记录到 `performance_alerts.log`
- **GitHub Actions**: CI 失败时自动通知

## 🔧 自定义配置

### 修改阈值
编辑 `performance_monitor.sh` 中的阈值配置：

```bash
PERFORMANCE_THRESHOLDS=(
    "BUILD_TIME:120000:构建时间(毫秒)"
    "PACKAGE_SIZE:200000000:包大小(字节)"
    "STARTUP_TIME:3000:启动时间(毫秒)"
    "MEMORY_USAGE:104857600:内存使用(字节)"
)
```

### 添加新指标
在脚本中添加新的性能检查逻辑：

```bash
# 示例：添加启动时间检查
check_startup_performance() {
    local startup_time=$1
    if (( startup_time > 3000 )); then
        echo "启动时间超标: ${startup_time}ms"
    fi
}
```

## 📋 常见问题

### Q: 脚本运行时提示 `bc` 命令未找到
A: 安装 `bc` 命令：
```bash
brew install bc  # macOS
apt-get install bc  # Ubuntu
```

### Q: 如何重置历史数据
A: 删除历史文件：
```bash
rm performance_history.json coverage_history.json
```

### Q: 如何禁用特定检查
A: 注释掉相应的函数调用或修改阈值。

## 🎯 最佳实践

### 1. 定期检查
- 每次提交前运行性能监控
- 每周查看覆盖率趋势
- 每次发布前执行完整检查

### 2. 告警响应
- 收到性能回归告警时立即分析原因
- 覆盖率下降时优先补充关键路径测试
- 构建失败时检查依赖和环境配置

### 3. 持续优化
- 根据历史数据调整性能阈值
- 定期评估和更新监控指标
- 收集团队反馈改进监控流程

## 📞 技术支持

如有问题或建议，请：
1. 查看 `performance_alerts.log` 获取详细错误信息
2. 运行 `swift build --verbose` 获取构建详情
3. 检查 CI/CD 日志了解自动化流程状态

---

*最后更新: 2025-11-28*
*监控脚本版本: v2.0.0*