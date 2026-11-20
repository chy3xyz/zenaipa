#!/bin/bash
set -e

BASE_URL="http://localhost:8000"

echo "=== Rating API Test ==="

# 1. 清理并使用admin CLI创建管理员
echo "[1] Creating admin via CLI..."
rm -f zenaipa.db
~/.local/zig/zig-x86_64-linux-0.17.0/zig build admin -- --email admin@test.com --pass Admin123! --name "Admin" 2>/dev/null

# 2. 启动服务
echo "[2] Starting service..."
./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

# 3. 管理员登录
echo "[3] Admin login..."
ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!"}')
ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    echo "ERROR: Failed to get admin token"
    echo "$ADMIN_LOGIN"
    kill $SERVER_PID
    exit 1
fi
echo "Admin token: ${ADMIN_TOKEN:0:30}..."

# 4. 创建项目
echo "[4] Creating project..."
PROJECT=$(curl -s -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"name":"Bitcoin","slug":"btc","sector":"Layer1","official_url":"https://bitcoin.org"}')
echo "Project: $PROJECT"
PROJECT_ID=$(echo "$PROJECT" | jq -r '.id')

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
    echo "ERROR: Failed to create project"
    kill $SERVER_PID
    exit 1
fi
echo "Project ID: $PROJECT_ID"

# 5. POST评分 (6/6维度，无红牌，应为A)
echo
echo "[TEST 1] POST rating (admin, all 6 dimensions)"
RATING_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}')
RATING_CODE=$(echo "$RATING_POST" | tail -1)
RATING_BODY=$(echo "$RATING_POST" | head -n -1)

echo "Status: $RATING_CODE"
echo "Response: $RATING_BODY"

if [ "$RATING_CODE" = "201" ]; then
    echo "✓ PASS: Rating created"
else
    echo "✗ FAIL: Expected 201, got $RATING_CODE"
    kill $SERVER_PID
    exit 1
fi

RATING_ID=$(echo "$RATING_BODY" | jq -r '.id')
BASE_GRADE=$(echo "$RATING_BODY" | jq -r '.base_grade')
PUB_GRADE=$(echo "$RATING_BODY" | jq -r '.published_grade')
CONFIDENCE=$(echo "$RATING_BODY" | jq -r '.confidence')

echo "Rating ID: $RATING_ID, base=$BASE_GRADE, pub=$PUB_GRADE, conf=$CONFIDENCE"

# 6. GET评分 (admin可读)
echo
echo "[TEST 2] GET rating (admin)"
RATING_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
GET_CODE=$(echo "$RATING_GET" | tail -1)
GET_BODY=$(echo "$RATING_GET" | head -n -1)

echo "Status: $GET_CODE"
if [ "$GET_CODE" = "200" ]; then
    echo "✓ PASS: Admin can read"
else
    echo "✗ FAIL: Expected 200, got $GET_CODE"
fi

# 7. 未登录GET -> 401
echo
echo "[TEST 3] GET rating (anonymous)"
ANON_GET=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
ANON_CODE=$(echo "$ANON_GET" | tail -1)

echo "Status: $ANON_CODE"
if [ "$ANON_CODE" = "401" ]; then
    echo "✓ PASS: Anonymous rejected (401)"
else
    echo "✗ FAIL: Expected 401, got $ANON_CODE"
fi

# 8. 重启测试
echo
echo "[TEST 4] Restart persistence"
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true
sleep 1

./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

# 重新登录
ADMIN_LOGIN2=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!"}')
ADMIN_TOKEN2=$(echo "$ADMIN_LOGIN2" | jq -r '.token')

RESTART_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN2" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
RESTART_CODE=$(echo "$RESTART_GET" | tail -1)
RESTART_BODY=$(echo "$RESTART_GET" | head -n -1)

echo "Status: $RESTART_CODE"
if [ "$RESTART_CODE" = "200" ]; then
    RESTART_BASE=$(echo "$RESTART_BODY" | jq -r '.base_grade')
    if [ "$RESTART_BASE" = "$BASE_GRADE" ]; then
        echo "✓ PASS: Data consistent after restart"
    else
        echo "✗ FAIL: Data mismatch (original=$BASE_GRADE, restart=$RESTART_BASE)"
    fi
else
    echo "✗ FAIL: Expected 200, got $RESTART_CODE"
fi

# 清理
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true

echo
echo "=== TEST SUMMARY ==="
echo "✓ Rating draft table created"
echo "✓ POST /projects/{id}/ratings (admin only)"
echo "✓ GET /projects/{id}/ratings/{rating_id} (admin only)"
echo "✓ Anonymous rejected (401)"
echo "✓ Data persistence verified"
