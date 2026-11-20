#!/bin/bash
set -e

BASE_URL="http://localhost:8000"

echo "=== Rating Draft API Test ==="

# 1. 创建管理员
echo "[1] Creating admin..."
rm -f zenaipa.db
cd /workspace && ~/.local/zig/zig-x86_64-linux-0.17.0/zig build admin -- create-admin --email admin@test.com --password Admin123! --name Admin 2>&1 | grep -v "error(SafeAllocator)"

# 2. 启动服务
echo "[2] Starting service..."
./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

# 3. 登录管理员
echo "[3] Admin login..."
ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!"}')
ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    echo "ERROR: No admin token: $ADMIN_LOGIN"
    kill $SERVER_PID
    exit 1
fi
echo "Token OK"

# 4. 创建项目
echo "[4] Creating project..."
PROJECT=$(curl -s -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"name":"Bitcoin","slug":"btc","sector":"Layer1"}')
PROJECT_ID=$(echo "$PROJECT" | jq -r '.id')

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
    echo "ERROR: No project: $PROJECT"
    kill $SERVER_PID
    exit 1
fi
echo "Project ID=$PROJECT_ID"

# 5. 测试未登录POST -> 401
echo
echo "[TEST 1] Anonymous POST -> 401"
ANON_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -d '{"c1_tech":85,"c2_team":90}')
ANON_CODE=$(echo "$ANON_POST" | tail -1)
if [ "$ANON_CODE" = "401" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL: Got $ANON_CODE"
fi

# 6. 管理员POST评分
echo
echo "[TEST 2] Admin POST rating"
RATING=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}')
RATING_CODE=$(echo "$RATING" | tail -1)
RATING_BODY=$(echo "$RATING" | head -n -1)

if [ "$RATING_CODE" = "201" ]; then
    echo "✓ PASS"
    RATING_ID=$(echo "$RATING_BODY" | jq -r '.id')
    echo "Rating ID=$RATING_ID, response=$RATING_BODY"
else
    echo "✗ FAIL: Got $RATING_CODE, body=$RATING_BODY"
    kill $SERVER_PID
    exit 1
fi

# 7. 管理员GET评分
echo
echo "[TEST 3] Admin GET rating"
GET_RATING=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
GET_CODE=$(echo "$GET_RATING" | tail -1)
if [ "$GET_CODE" = "200" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL: Got $GET_CODE"
fi

# 8. 未登录GET -> 401
echo
echo "[TEST 4] Anonymous GET -> 401"
ANON_GET=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
ANON_GET_CODE=$(echo "$ANON_GET" | tail -1)
if [ "$ANON_GET_CODE" = "401" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL: Got $ANON_GET_CODE"
fi

# 9. 重启验证
echo
echo "[TEST 5] Restart persistence"
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true
sleep 1

./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

ADMIN_LOGIN2=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!"}')
ADMIN_TOKEN2=$(echo "$ADMIN_LOGIN2" | jq -r '.token')

RESTART_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN2" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
RESTART_CODE=$(echo "$RESTART_GET" | tail -1)
if [ "$RESTART_CODE" = "200" ]; then
    echo "✓ PASS: Data persisted"
else
    echo "✗ FAIL: Got $RESTART_CODE"
fi

# 清理
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true

echo
echo "=== ALL TESTS PASSED ==="
