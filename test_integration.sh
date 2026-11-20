#!/bin/bash
set -e

echo "========================================="
echo "区块链评级系统 MVP 集成测试"
echo "========================================="

BASE_URL="http://localhost:8000"
API_URL="$BASE_URL/api/v1"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

# 清理旧数据库
rm -f zenaipa.db

# 启动服务器
echo "启动服务器..."
./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

# 确保测试结束后清理
cleanup() {
    echo "清理进程..."
    kill $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT

# 测试1: 健康检查
echo ""
echo "测试1: 健康检查"
RESPONSE=$(curl -s "$BASE_URL/health/live")
if echo "$RESPONSE" | grep -q "UP"; then
    success "健康检查通过"
else
    error "健康检查失败: $RESPONSE"
fi

# 测试2: 注册用户（analyst）
echo ""
echo "测试2: 注册分析师账号"
ANALYST_RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "analyst1",
        "email": "analyst1@test.com",
        "password": "Password123!"
    }')

if echo "$ANALYST_RESPONSE" | grep -q "token"; then
    ANALYST_TOKEN=$(echo "$ANALYST_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    success "分析师注册成功"
else
    error "分析师注册失败: $ANALYST_RESPONSE"
fi

# 测试3: 注册审核人
echo ""
echo "测试3: 注册审核人账号"
REVIEWER_RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "reviewer1",
        "email": "reviewer1@test.com",
        "password": "Password123!"
    }')

if echo "$REVIEWER_RESPONSE" | grep -q "token"; then
    REVIEWER_TOKEN=$(echo "$REVIEWER_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    success "审核人注册成功"
else
    error "审核人注册失败: $REVIEWER_RESPONSE"
fi

# 测试4: 检查数据库
echo ""
echo "测试4: 验证SQLite数据持久化"
if [ -f "zenaipa.db" ]; then
    DB_SIZE=$(stat -f%z "zenaipa.db" 2>/dev/null || stat -c%s "zenaipa.db")
    if [ "$DB_SIZE" -gt 10000 ]; then
        success "SQLite数据库已创建并有数据 (${DB_SIZE} bytes)"
    else
        error "数据库文件太小: ${DB_SIZE} bytes"
    fi
else
    error "数据库文件不存在"
fi

# 测试5: 检查schema表
echo ""
echo "测试5: 验证数据库schema"
TABLES=$(sqlite3 zenaipa.db "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>&1)
echo "数据库表："
echo "$TABLES" | head -10
TABLE_COUNT=$(echo "$TABLES" | wc -l | tr -d ' ')
if [ "$TABLE_COUNT" -gt 10 ]; then
    success "数据库表创建成功 ($TABLE_COUNT 个表)"
else
    error "数据库表不足: $TABLE_COUNT"
fi

echo ""
echo "========================================="
echo "集成测试完成"
echo "========================================="
echo "测试结果摘要:"
echo "- 服务器启动: ✓"
echo "- 健康检查: ✓"
echo "- 用户注册: ✓"
echo "- 数据持久化: ✓"
echo "- Schema验证: ✓"
