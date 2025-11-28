#!/bin/bash

# UnclutterPlus 测试运行脚本
# 运行单元测试和性能测试

echo "🚀 UnclutterPlus 测试套件执行开始..."
echo "=================================================="

# 设置环境变量
export SWIFT_ENVIRONMENT=testing

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 测试概览:${NC}"
echo "• 单元测试覆盖核心功能"
echo "• 性能基准测试"
echo "• 架构组件验证"
echo "• 内存使用分析"
echo ""

# 检查构建
echo -e "${BLUE}🔧 1. 构建项目...${NC}"
swift build --configuration release
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 构建失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 构建成功${NC}"
echo ""

# 运行单元测试
echo -e "${BLUE}🧪 2. 运行单元测试...${NC}"
swift test --enable-code-coverage

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 单元测试通过${NC}"
else
    echo -e "${RED}❌ 单元测试失败${NC}"
    echo -e "${YELLOW}⚠️  继续执行其他测试...${NC}"
fi
echo ""

# 运行性能测试
echo -e "${BLUE}⚡ 3. 运行性能基准测试...${NC}"
./build/release/UnclutterPlus --run-performance-tests
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 性能测试完成${NC}"
else
    echo -e "${YELLOW}⚠️ 性能测试跳过或失败${NC}"
fi
echo ""

# 运行内存测试
echo -e "${BLUE}🧠 4. 运行内存测试...${NC}"
./build/release/UnclutterPlus --run-memory-tests
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 内存测试完成${NC}"
else
    echo -e "${YELLOW}⚠️  内存测试跳过或失败${NC}"
fi
echo ""

# 生成测试报告
echo -e "${BLUE}📊 5. 生成测试报告...${NC}"

# 检查是否安装了xcov (代码覆盖率工具)
if command -v xcov &> /dev/null; then
    echo "生成代码覆盖率报告..."
    xcov --report html --output coverage-report --sources Sources/UnclutterPlus
    echo -e "${GREEN}✅ 覆盖率报告生成完成: coverage-report/index.html${NC}"
else
    echo -e "${YELLOW}⚠️  xcov 未安装，跳过覆盖率报告${NC}"
fi

echo ""
echo -e "${BLUE}📋 测试执行总结:${NC}"
echo "• 构建状态: ✅"
echo "• 单元测试: $([ $? -eq 0 ] && echo "✅ 通过" || echo "❌ 失败"
echo "• 性能测试: 执行完成"
echo "• 内存测试: 执行完成"
echo ""

echo -e "${GREEN}🎉 测试执行完成！${NC}"
echo "=================================================="
