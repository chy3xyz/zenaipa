#!/bin/bash
# RBAC+持久化测试：admin/normal/anonymous + 重启验证
set -e

BASE_URL="http://localhost:8000"
TEST_DB="rbac_test_$$.db"
PASS=0
FAIL=0

echo "=== RBAC + Persistence Test ==="
echo "Test DB: $TEST_DB"

cleanup() {
    pkill -f "zig-out/bin/zenaipa" 2>/dev/null || true
    sleep 1
}
trap cleanup EXIT

# 初始化数据库并启动
echo
echo "[Setup] Initialize database and service"
rm -f "$TEST_DB"
ZENAIPA_SQLITE_PATH="$TEST_DB" ./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 4

# 验证服务
if ! curl -s -f "$BASE_URL/health/live" > /dev/null; then
    echo "ERROR: Service not responding"
    exit 1
fi
echo "✓ Service running (PID: $SERVER_PID)"
((PASS++))

#注册两个用户：admin + normal
echo
echo "[1] Register users"
ADMIN_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"adm@t.co","password":"Pass123!","name":"Admin"}')
ADMIN_ID=$(echo "$ADMIN_REG" | jq -r '.data.user.id')
echo "Admin registered: ID=$ADMIN_ID"

NORMAL_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"usr@t.co","password":"Pass123!","name":"User"}')
NORMAL_ID=$(echo "$NORMAL_REG" | jq -r '.data.user.id')
echo "Normal registered: ID=$NORMAL_ID"

# 提升第一个用户为admin（模拟bootstrap）
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true
sqlite3 "$TEST_DB" "UPDATE user SET admin=1 WHERE id=$ADMIN_ID;"
echo "✓ Elevated user $ADMIN_ID to admin"
((PASS++))

# 验证伪造admin字段无效
FAKE_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"fake@t.co","password":"Pass123!","name":"Fake","admin":true,"role":"admin"}')
FAKE_ADMIN=$(sqlite3 "$TEST_DB" "SELECT admin FROM user WHERE email='fake@t.co';")
if [ "$FAKE_ADMIN" = "0" ]; then
    echo "✓ Fake admin fields ignored (admin=$FAKE_ADMIN)"
    ((PASS++))
else
    echo "✗ SECURITY: Fake admin accepted!"
    ((FAIL++))
fi

# 重启服务
ZENAIPA_SQLITE_PATH="$TEST_DB" ./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 4

# 登录
echo
echo "[2] Login"
ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"adm@t.co","password":"Pass123!"}')
AT=$(echo "$ADMIN_LOGIN" | jq -r '.data.token')
echo "Admin token: ${AT:0:30}..."

NORMAL_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"usr@t.co","password":"Pass123!"}')
NT=$(echo "$NORMAL_LOGIN" | jq -r '.data.token')
echo "Normal token: ${NT:0:30}..."

# 项目CRUD权限测试
echo
echo "[3] Project CRUD permissions"

# Admin creates -> 201
PROJ=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AT" \
  -d '{"name":"BTC","slug":"btc","sector":"Layer1"}')
PROJ_CODE=$(echo "$PROJ" | tail -1)
PROJ_ID=$(echo "$PROJ" | head -n -1 | jq -r '.id')
if [ "$PROJ_CODE" = "201" ]; then
    echo "✓ Admin creates project: $PROJ_CODE (ID=$PROJ_ID)"
    ((PASS++))
else
    echo "✗ Admin create failed: $PROJ_CODE"
    ((FAIL++))
fi

# Normal creates -> 403
NORM_PROJ=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $NT" \
  -d '{"name":"ETH","slug":"eth","sector":"Layer1"}')
NORM_CODE=$(echo "$NORM_PROJ" | tail -1)
if [ "$NORM_CODE" = "403" ]; then
    echo "✓ Normal user blocked: $NORM_CODE"
    ((PASS++))
else
    echo "✗ Normal user not blocked: $NORM_CODE"
    ((FAIL++))
fi

# Anonymous -> 401
ANON_PROJ=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -d '{"name":"SOL","slug":"sol","sector":"Layer1"}')
ANON_CODE=$(echo "$ANON_PROJ" | tail -1)
if [ "$ANON_CODE" = "401" ]; then
    echo "✓ Anonymous blocked: $ANON_CODE"
    ((PASS++))
else
    echo "✗ Anonymous not blocked: $ANON_CODE"
    ((FAIL++))
fi

# Rating草稿权限测试
echo
echo "[4] Rating draft permissions"

RATING_JSON='{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}'

# Admin POST -> 201
RATING=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJ_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AT" \
  -d "$RATING_JSON")
RATING_CODE=$(echo "$RATING" | tail -1)
RATING_BODY=$(echo "$RATING" | head -n -1)
RATING_ID=$(echo "$RATING_BODY" | jq -r '.id')
if [ "$RATING_CODE" = "201" ]; then
    echo "✓ Admin creates rating: $RATING_CODE (ID=$RATING_ID)"
    ((PASS++))
else
    echo "✗ Admin rating failed: $RATING_CODE"
    ((FAIL++))
fi

BASE_G=$(echo "$RATING_BODY" | jq -r '.base_grade')
PUB_G=$(echo "$RATING_BODY" | jq -r '.published_grade')
CONF=$(echo "$RATING_BODY" | jq -r '.confidence')
echo "Rating: base=$BASE_G, pub=$PUB_G, conf=$CONF"

# Normal POST -> 403
NORM_RATING=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJ_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $NT" \
  -d "$RATING_JSON")
NORM_R_CODE=$(echo "$NORM_RATING" | tail -1)
if [ "$NORM_R_CODE" = "403" ]; then
    echo "✓ Normal user blocked from POST: $NORM_R_CODE"
    ((PASS++))
else
    echo "✗ Normal user not blocked: $NORM_R_CODE"
    ((FAIL++))
fi

# Anonymous POST -> 401
ANON_RATING=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJ_ID/ratings" \
  -H "Content-Type: application/json" \
  -d "$RATING_JSON")
ANON_R_CODE=$(echo "$ANON_RATING" | tail -1)
if [ "$ANON_R_CODE" = "401" ]; then
    echo "✓ Anonymous blocked from POST: $ANON_R_CODE"
    ((PASS++))
else
    echo "✗ Anonymous not blocked: $ANON_R_CODE"
    ((FAIL++))
fi

# Admin GET -> 200
GET_RATING=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $AT" \
  "$BASE_URL/api/v1/projects/$PROJ_ID/ratings/$RATING_ID")
GET_CODE=$(echo "$GET_RATING" | tail -1)
if [ "$GET_CODE" = "200" ]; then
    echo "✓ Admin GET rating: $GET_CODE"
    ((PASS++))
else
    echo "✗ Admin GET failed: $GET_CODE"
    ((FAIL++))
fi

# Normal GET -> 403
NORM_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $NT" \
  "$BASE_URL/api/v1/projects/$PROJ_ID/ratings/$RATING_ID")
NORM_GET_CODE=$(echo "$NORM_GET" | tail -1)
if [ "$NORM_GET_CODE" = "403" ]; then
    echo "✓ Normal user blocked from GET: $NORM_GET_CODE"
    ((PASS++))
else
    echo "✗ Normal user not blocked from GET: $NORM_GET_CODE"
    ((FAIL++))
fi

# Anonymous GET -> 401
ANON_GET=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/projects/$PROJ_ID/ratings/$RATING_ID")
ANON_GET_CODE=$(echo "$ANON_GET" | tail -1)
if [ "$ANON_GET_CODE" = "401" ]; then
    echo "✓ Anonymous blocked from GET: $ANON_GET_CODE"
    ((PASS++))
else
    echo "✗ Anonymous not blocked from GET: $ANON_GET_CODE"
    ((FAIL++))
fi

# 错误project_id -> 404
WRONG_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $AT" \
  "$BASE_URL/api/v1/projects/999/ratings/$RATING_ID")
WRONG_CODE=$(echo "$WRONG_GET" | tail -1)
if [ "$WRONG_CODE" = "404" ]; then
    echo "✓ Wrong project_id rejected: $WRONG_CODE"
    ((PASS++))
else
    echo "✗ Wrong project_id not rejected: $WRONG_CODE"
    ((FAIL++))
fi

# 重启测试
echo
echo "[5] Restart persistence"
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true
sleep 2

ZENAIPA_SQLITE_PATH="$TEST_DB" ./zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 4

# 重新登录
RE_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"adm@t.co","password":"Pass123!"}')
AT2=$(echo "$RE_LOGIN" | jq -r '.data.token')
echo "Relogin token: ${AT2:0:30}..."

# GET评分验证数据
RE_GET=$(curl -s -H "Authorization: Bearer $AT2" \
  "$BASE_URL/api/v1/projects/$PROJ_ID/ratings/$RATING_ID")
RE_BASE=$(echo "$RE_GET" | jq -r '.base_grade')
RE_PUB=$(echo "$RE_GET" | jq -r '.published_grade')
RE_CONF=$(echo "$RE_GET" | jq -r '.confidence')

echo "After restart: base=$RE_BASE, pub=$RE_PUB, conf=$RE_CONF"

if [ "$RE_BASE" = "$BASE_G" ] && [ "$RE_PUB" = "$PUB_G" ] && [ "$RE_CONF" = "$CONF" ]; then
    echo "✓ Data consistent after restart"
    ((PASS++))
else
    echo "✗ Data mismatch after restart"
    ((FAIL++))
fi

# SQL验证
echo
echo "[6] Database verification"
TABLE_EXISTS=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='rating_draft';")
if [ "$TABLE_EXISTS" = "1" ]; then
    echo "✓ rating_draft table exists"
    ((PASS++))
else
    echo "✗ rating_draft table missing"
    ((FAIL++))
fi

ROW_EXISTS=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM rating_draft WHERE id=$RATING_ID AND project_id=$PROJ_ID;")
if [ "$ROW_EXISTS" = "1" ]; then
    echo "✓ Rating row persisted"
    ((PASS++))
else
    echo "✗ Rating row missing"
    ((FAIL++))
fi

# 总结
echo
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ $FAIL -eq 0 ]; then
    echo "✓ ALL TESTS PASSED"
    exit 0
else
    echo "✗ TESTS FAILED"
    exit 1
fi
