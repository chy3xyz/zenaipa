#!/bin/bash
set -e

echo "=== Blockchain Project Integration Test ==="

# 启动服务
pkill -9 zenaipa 2>/dev/null || true
sleep 1

./zig-out/bin/zenaipa serve sqlite,postgres > /tmp/test_server.log 2>&1 &
SERVER_PID=$!
sleep 4

# 测试函数
test_endpoint() {
    local method=$1
    local url=$2
    local data=$3
    local expected_code=$4
    local desc=$5
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" -H "Content-Type: application/json" -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "$expected_code" ]; then
        echo "✓ $desc (HTTP $http_code)"
        [ -n "$body" ] && echo "  Response: $body"
    else
        echo "✗ $desc - Expected $expected_code, got $http_code"
        echo "  Response: $body"
        kill $SERVER_PID 2>/dev/null
        exit 1
    fi
}

# 执行测试
echo ""
echo "=== CRUD Tests ==="

# CREATE
test_endpoint POST "http://localhost:8000/api/v1/projects" \
    '{"name":"Test Coin","slug":"test-coin","sector":"Test"}' \
    "401" "CREATE without auth (should return 401)"

# LIST (不需要认证)
test_endpoint GET "http://localhost:8000/api/v1/projects" \
    "" "200" "LIST projects"

# DETAIL - 存在的项目
test_endpoint GET "http://localhost:8000/api/v1/projects/1" \
    "" "200" "GET existing project"

# DETAIL - 不存在的项目
test_endpoint GET "http://localhost:8000/api/v1/projects/9999" \
    "" "404" "GET non-existent project (should return 404)"

# UPDATE without auth
test_endpoint PUT "http://localhost:8000/api/v1/projects/1" \
    '{"name":"Updated"}' \
    "401" "UPDATE without auth (should return 401)"

echo ""
echo "=== SQLite Configuration Test ==="
sqlite3 zenaipa.db "PRAGMA journal_mode;" | grep -q "wal" && echo "✓ WAL mode enabled" || echo "✗ WAL mode not enabled"

echo ""
echo "=== Data Persistence Test ==="
echo "Current projects in DB:"
sqlite3 zenaipa.db "SELECT id, name, slug FROM project LIMIT 5;"

# 清理
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

echo ""
echo "=== All integration tests passed ==="
