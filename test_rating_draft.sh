#!/bin/bash
set -e

BASE_URL="http://localhost:8080"
DB_FILE="zenaipa.db"

echo "=== Rating Draft Persistence API Test ==="
echo

# 清理并启动
echo "[1] Cleaning and starting service..."
pkill -f zig-out/bin/zenaipa || true
rm -f "$DB_FILE"
sleep 1

zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

if ! ps -p $SERVER_PID > /dev/null; then
    echo "ERROR: Server failed to start"
    exit 1
fi
echo "Server started (PID: $SERVER_PID)"

# 创建管理员用户
echo
echo "[2] Creating admin user..."
ADMIN_EMAIL="admin@test.com"
ADMIN_PASS="Admin123!"
ADMIN_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\",\"name\":\"Admin User\",\"admin\":true}")
echo "Admin registration: $ADMIN_REG"

# 管理员登录
ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")
ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.token // empty')

if [ -z "$ADMIN_TOKEN" ]; then
    echo "ERROR: Failed to get admin token"
    echo "Response: $ADMIN_LOGIN"
    kill $SERVER_PID
    exit 1
fi
echo "Admin token: ${ADMIN_TOKEN:0:20}..."

# 创建普通用户
echo
echo "[3] Creating normal user..."
USER_EMAIL="user@test.com"
USER_PASS="User123!"
USER_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASS\",\"name\":\"Normal User\"}")
echo "User registration: $USER_REG"

USER_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASS\"}")
USER_TOKEN=$(echo "$USER_LOGIN" | jq -r '.token // empty')

if [ -z "$USER_TOKEN" ]; then
    echo "ERROR: Failed to get user token"
    echo "Response: $USER_LOGIN"
    kill $SERVER_PID
    exit 1
fi
echo "User token: ${USER_TOKEN:0:20}..."

# 管理员创建项目
echo
echo "[4] Admin creates demo project..."
PROJECT_CREATE=$(curl -s -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"name":"Test Project","slug":"test-proj","sector":"DeFi","official_url":"https://example.com"}')
PROJECT_ID=$(echo "$PROJECT_CREATE" | jq -r '.id // empty')

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: Failed to create project"
    echo "Response: $PROJECT_CREATE"
    kill $SERVER_PID
    exit 1
fi
echo "Created project ID: $PROJECT_ID"

# TEST 1: 未登录POST评分 -> 401
echo
echo "[TEST 1] Anonymous POST rating -> 401"
ANON_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -d '{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}')
ANON_POST_CODE=$(echo "$ANON_POST" | tail -1)
ANON_POST_BODY=$(echo "$ANON_POST" | head -n -1)

if [ "$ANON_POST_CODE" = "401" ]; then
    echo "✓ PASS: Anonymous POST rejected with 401"
else
    echo "✗ FAIL: Expected 401, got $ANON_POST_CODE"
    echo "Response: $ANON_POST_BODY"
    kill $SERVER_PID
    exit 1
fi

# TEST 2: 普通用户POST评分 -> 403
echo
echo "[TEST 2] Normal user POST rating -> 403"
USER_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -d '{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}')
USER_POST_CODE=$(echo "$USER_POST" | tail -1)
USER_POST_BODY=$(echo "$USER_POST" | head -n -1)

if [ "$USER_POST_CODE" = "403" ]; then
    echo "✓ PASS: Normal user POST rejected with 403"
else
    echo "✗ FAIL: Expected 403, got $USER_POST_CODE"
    echo "Response: $USER_POST_BODY"
    kill $SERVER_PID
    exit 1
fi

# TEST 3: 管理员POST评分 -> 201
echo
echo "[TEST 3] Admin POST rating -> 201"
ADMIN_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}')
ADMIN_POST_CODE=$(echo "$ADMIN_POST" | tail -1)
ADMIN_POST_BODY=$(echo "$ADMIN_POST" | head -n -1)

if [ "$ADMIN_POST_CODE" = "201" ]; then
    echo "✓ PASS: Admin POST accepted with 201"
else
    echo "✗ FAIL: Expected 201, got $ADMIN_POST_CODE"
    echo "Response: $ADMIN_POST_BODY"
    kill $SERVER_PID
    exit 1
fi

RATING_ID=$(echo "$ADMIN_POST_BODY" | jq -r '.id // empty')
if [ -z "$RATING_ID" ]; then
    echo "ERROR: No rating ID in response"
    echo "Response: $ADMIN_POST_BODY"
    kill $SERVER_PID
    exit 1
fi
echo "Created rating ID: $RATING_ID"
echo "Response: $ADMIN_POST_BODY"

# 验证评级结果
BASE_GRADE=$(echo "$ADMIN_POST_BODY" | jq -r '.base_grade // empty')
PUBLISHED_GRADE=$(echo "$ADMIN_POST_BODY" | jq -r '.published_grade // empty')
CONFIDENCE=$(echo "$ADMIN_POST_BODY" | jq -r '.confidence // empty')

echo "Calculated: base_grade=$BASE_GRADE, published_grade=$PUBLISHED_GRADE, confidence=$CONFIDENCE"

# TEST 4: 未登录GET评分 -> 401
echo
echo "[TEST 4] Anonymous GET rating -> 401"
ANON_GET=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
ANON_GET_CODE=$(echo "$ANON_GET" | tail -1)
ANON_GET_BODY=$(echo "$ANON_GET" | head -n -1)

if [ "$ANON_GET_CODE" = "401" ]; then
    echo "✓ PASS: Anonymous GET rejected with 401"
else
    echo "✗ FAIL: Expected 401, got $ANON_GET_CODE"
    echo "Response: $ANON_GET_BODY"
    kill $SERVER_PID
    exit 1
fi

# TEST 5: 普通用户GET评分 -> 403
echo
echo "[TEST 5] Normal user GET rating -> 403"
USER_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
USER_GET_CODE=$(echo "$USER_GET" | tail -1)
USER_GET_BODY=$(echo "$USER_GET" | head -n -1)

if [ "$USER_GET_CODE" = "403" ]; then
    echo "✓ PASS: Normal user GET rejected with 403"
else
    echo "✗ FAIL: Expected 403, got $USER_GET_CODE"
    echo "Response: $USER_GET_BODY"
    kill $SERVER_PID
    exit 1
fi

# TEST 6: 管理员GET评分 -> 200 (相同结果)
echo
echo "[TEST 6] Admin GET rating -> 200"
ADMIN_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
ADMIN_GET_CODE=$(echo "$ADMIN_GET" | tail -1)
ADMIN_GET_BODY=$(echo "$ADMIN_GET" | head -n -1)

if [ "$ADMIN_GET_CODE" = "200" ]; then
    echo "✓ PASS: Admin GET accepted with 200"
else
    echo "✗ FAIL: Expected 200, got $ADMIN_GET_CODE"
    echo "Response: $ADMIN_GET_BODY"
    kill $SERVER_PID
    exit 1
fi

echo "Response: $ADMIN_GET_BODY"

# 验证数据一致
GET_BASE=$(echo "$ADMIN_GET_BODY" | jq -r '.base_grade // empty')
GET_PUB=$(echo "$ADMIN_GET_BODY" | jq -r '.published_grade // empty')
GET_CONF=$(echo "$ADMIN_GET_BODY" | jq -r '.confidence // empty')

if [ "$GET_BASE" = "$BASE_GRADE" ] && [ "$GET_PUB" = "$PUBLISHED_GRADE" ] && [ "$GET_CONF" = "$CONFIDENCE" ]; then
    echo "✓ PASS: GET result matches POST result"
else
    echo "✗ FAIL: Data mismatch"
    echo "POST: base=$BASE_GRADE, pub=$PUBLISHED_GRADE, conf=$CONFIDENCE"
    echo "GET:  base=$GET_BASE, pub=$GET_PUB, conf=$GET_CONF"
    kill $SERVER_PID
    exit 1
fi

# TEST 7: 重启后一致性
echo
echo "[TEST 7] Restart and verify consistency..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true
sleep 1

if [ ! -f "$DB_FILE" ]; then
    echo "ERROR: Database file missing after shutdown"
    exit 1
fi

zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

if ! ps -p $SERVER_PID > /dev/null; then
    echo "ERROR: Server failed to restart"
    exit 1
fi
echo "Server restarted (PID: $SERVER_PID)"

# 重新登录管理员
ADMIN_LOGIN2=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")
ADMIN_TOKEN2=$(echo "$ADMIN_LOGIN2" | jq -r '.token // empty')

if [ -z "$ADMIN_TOKEN2" ]; then
    echo "ERROR: Failed to re-login admin"
    kill $SERVER_PID
    exit 1
fi

# GET评分
RESTART_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN2" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
RESTART_GET_CODE=$(echo "$RESTART_GET" | tail -1)
RESTART_GET_BODY=$(echo "$RESTART_GET" | head -n -1)

if [ "$RESTART_GET_CODE" != "200" ]; then
    echo "✗ FAIL: GET after restart returned $RESTART_GET_CODE"
    echo "Response: $RESTART_GET_BODY"
    kill $SERVER_PID
    exit 1
fi

RESTART_BASE=$(echo "$RESTART_GET_BODY" | jq -r '.base_grade // empty')
RESTART_PUB=$(echo "$RESTART_GET_BODY" | jq -r '.published_grade // empty')
RESTART_CONF=$(echo "$RESTART_GET_BODY" | jq -r '.confidence // empty')

if [ "$RESTART_BASE" = "$BASE_GRADE" ] && [ "$RESTART_PUB" = "$PUBLISHED_GRADE" ] && [ "$RESTART_CONF" = "$CONFIDENCE" ]; then
    echo "✓ PASS: Data consistent after restart"
else
    echo "✗ FAIL: Data inconsistency after restart"
    echo "Original: base=$BASE_GRADE, pub=$PUBLISHED_GRADE, conf=$CONFIDENCE"
    echo "Restart:  base=$RESTART_BASE, pub=$RESTART_PUB, conf=$RESTART_CONF"
    kill $SERVER_PID
    exit 1
fi

# 清理
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true

echo
echo "=== ALL TESTS PASSED ==="
echo "✓ Anonymous POST/GET rejected (401)"
echo "✓ Normal user POST/GET rejected (403)"
echo "✓ Admin POST/GET accepted"
echo "✓ Data consistency verified"
echo "✓ Restart persistence verified"
exit 0
