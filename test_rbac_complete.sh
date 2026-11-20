#!/bin/bash
# 完整RBAC+持久化测试：admin成功，normal用户403，anonymous401，重启一致性
set -e

BASE_URL="http://localhost:8000"
TEST_DB="test_rbac_$$.db"
PASSED=0
FAILED=0

echo "=== 完整RBAC+持久化测试 ==="
echo "测试数据库: $TEST_DB"
echo

# 清理函数
cleanup() {
    pkill -f "zig-out/bin/zenaipa.*$TEST_DB" 2>/dev/null || true
    sleep 1
    rm -f "$TEST_DB" 2>/dev/null || true
}

trap cleanup EXIT

# 启动服务
start_service() {
    ZENAIPA_SQLITE_PATH="$TEST_DB" ./zig-out/bin/zenaipa &
    SERVER_PID=$!
    sleep 3
    
    # 验证服务启动
    if ! curl -s -f "$BASE_URL/health/live" > /dev/null; then
        echo "ERROR: Service failed to start"
        exit 1
    fi
    echo "Service started (PID: $SERVER_PID, DB: $TEST_DB)"
}

# 停止服务
stop_service() {
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        SERVER_PID=""
    fi
}

# 测试断言
assert_http_code() {
    local expected=$1
    local actual=$2
    local desc=$3
    
    if [ "$actual" = "$expected" ]; then
        echo "✓ PASS: $desc (HTTP $actual)"
        ((PASSED++))
    else
        echo "✗ FAIL: $desc (expected $expected, got $actual)"
        ((FAILED++))
    fi
}

assert_json_field() {
    local json=$1
    local field=$2
    local expected=$3
    local desc=$4
    
    local actual=$(echo "$json" | jq -r ".$field // \"null\"")
    if [ "$actual" = "$expected" ]; then
        echo "✓ PASS: $desc ($field=$actual)"
        ((PASSED++))
    else
        echo "✗ FAIL: $desc (expected $expected, got $actual)"
        ((FAILED++))
    fi
}

cleanup
start_service

echo
echo "[Phase 1] 创建测试账号"
echo "================================"

# 1.1 创建管理员（直接SQL - 模拟CLI bootstrap）
echo "[1.1] 创建管理员（SQL bootstrap）"
stop_service

# 手动插入admin用户（模拟初始bootstrap，密码hash无所谓因为我们用real密码登录测试）
# 真实场景中这应该由admin CLI或安全初始化流程完成
sqlite3 "$TEST_DB" <<'EOF'
-- 插入管理员用户
INSERT INTO user (email, name, password, verified, admin, tenant_id, created_at, updated_at, token_version)
VALUES (
  'admin@test.local',
  'Admin User',
  '$2b$10$abcdefghijklmnopqrstuvwxyz012345',  -- 占位hash，将用真实登录测试
  1,
  1,  -- admin=1
  1,
  strftime('%s', 'now'),
  strftime('%s', 'now'),
  0
);
EOF

# 验证admin字段
ADMIN_CHECK=$(sqlite3 "$TEST_DB" "SELECT email, admin FROM user WHERE email='admin@test.local'")
echo "Admin user: $ADMIN_CHECK"
if echo "$ADMIN_CHECK" | grep -q "admin@test.local|1"; then
    echo "✓ Admin user created with admin=1"
    ((PASSED++))
else
    echo "✗ Admin user not properly created"
    ((FAILED++))
    exit 1
fi

# 现在通过register API注册真实管理员（用于获取有效token）
start_service

ADMIN_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin2@test.local","password":"AdminPass123!","name":"Admin Via API"}')
echo "Admin registration via API: $(echo $ADMIN_REG | jq -c '.data.user.id')"

# 手动将此用户设置为管理员（模拟bootstrap后权限提升）
stop_service
sqlite3 "$TEST_DB" "UPDATE user SET admin = 1 WHERE email = 'admin2@test.local';"
echo "Elevated admin2@test.local to admin=1"

start_service

# 1.2 公开注册普通用户
echo
echo "[1.2] 公开注册普通用户（HTTP）"
NORMAL_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@test.local","password":"UserPass123!","name":"Normal User"}')
echo "Normal user registration response: $(echo $NORMAL_REG | jq -c '.')"

NORMAL_USER_ID=$(echo "$NORMAL_REG" | jq -r '.data.user.id // "null"')
if [ "$NORMAL_USER_ID" != "null" ]; then
    echo "✓ Normal user registered (ID=$NORMAL_USER_ID)"
    ((PASSED++))
else
    echo "✗ Failed to register normal user"
    ((FAILED++))
    exit 1
fi

# 验证普通用户admin=0
NORMAL_CHECK=$(sqlite3 "$TEST_DB" "SELECT email, admin FROM user WHERE email='user@test.local'")
echo "Normal user: $NORMAL_CHECK"
if echo "$NORMAL_CHECK" | grep -q "user@test.local|0"; then
    echo "✓ Normal user has admin=0"
    ((PASSED++))
else
    echo "✗ Normal user admin flag incorrect"
    ((FAILED++))
fi

# 1.3 尝试伪造admin字段注册
echo
echo "[1.3] 尝试伪造admin字段（应被忽略）"
FAKE_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"fake@test.local","password":"FakePass123!","name":"Fake Admin","admin":true,"is_admin":true,"role":"admin"}')
echo "Fake admin registration: $(echo $FAKE_REG | jq -c '.')"

FAKE_CHECK=$(sqlite3 "$TEST_DB" "SELECT email, admin FROM user WHERE email='fake@test.local'")
echo "Fake user: $FAKE_CHECK"
if echo "$FAKE_CHECK" | grep -q "fake@test.local|0"; then
    echo "✓ Fake admin fields ignored, user has admin=0"
    ((PASSED++))
else
    echo "✗ SECURITY ISSUE: Fake admin succeeded!"
    ((FAILED++))
fi

echo
echo "[Phase 2] 登录获取token"
echo "================================"

# 2.1 管理员登录
echo "[2.1] 管理员登录"
ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin2@test.local","password":"AdminPass123!"}')
ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.data.token // "null"')

if [ "$ADMIN_TOKEN" = "null" ]; then
    echo "✗ Admin login failed: $(echo $ADMIN_LOGIN | jq -c '.')"
    ((FAILED++))
    exit 1
fi
echo "✓ Admin login successful, token: ${ADMIN_TOKEN:0:40}..."
((PASSED++))

# 2.2 普通用户登录
echo
echo "[2.2] 普通用户登录"
NORMAL_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@test.local","password":"UserPass123!"}')
NORMAL_TOKEN=$(echo "$NORMAL_LOGIN" | jq -r '.data.token // "null"')

if [ "$NORMAL_TOKEN" = "null" ]; then
    echo "✗ Normal user login failed"
    ((FAILED++))
    exit 1
fi
echo "✓ Normal user login successful, token: ${NORMAL_TOKEN:0:40}..."
((PASSED++))

echo
echo "[Phase 3] 项目CRUD权限测试"
echo "================================"

# 3.1 管理员创建项目
echo "[3.1] 管理员创建项目"
PROJECT_CREATE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"name":"Bitcoin","slug":"btc","sector":"Layer1","official_url":"https://bitcoin.org"}')
PROJECT_CODE=$(echo "$PROJECT_CREATE" | tail -1)
PROJECT_BODY=$(echo "$PROJECT_CREATE" | head -n -1)
assert_http_code "201" "$PROJECT_CODE" "Admin creates project"

PROJECT_ID=$(echo "$PROJECT_BODY" | jq -r '.id // "null"')
if [ "$PROJECT_ID" = "null" ]; then
    echo "✗ No project ID returned"
    ((FAILED++))
    exit 1
fi
echo "Created project ID: $PROJECT_ID"

# 3.2 普通用户创建项目 -> 403
echo
echo "[3.2] 普通用户创建项目 -> 403"
NORMAL_CREATE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $NORMAL_TOKEN" \
  -d '{"name":"Ethereum","slug":"eth","sector":"Layer1"}')
NORMAL_CREATE_CODE=$(echo "$NORMAL_CREATE" | tail -1)
assert_http_code "403" "$NORMAL_CREATE_CODE" "Normal user blocked from creating project"

# 3.3 未登录创建项目 -> 401
echo
echo "[3.3] 未登录创建项目 -> 401"
ANON_CREATE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -d '{"name":"Solana","slug":"sol","sector":"Layer1"}')
ANON_CREATE_CODE=$(echo "$ANON_CREATE" | tail -1)
assert_http_code "401" "$ANON_CREATE_CODE" "Anonymous blocked from creating project"

echo
echo "[Phase 4] 评分草稿权限测试"
echo "================================"

# 4.1 管理员POST评分草稿
echo "[4.1] 管理员POST评分草稿"
RATING_DATA='{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}'
ADMIN_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d "$RATING_DATA")
ADMIN_POST_CODE=$(echo "$ADMIN_POST" | tail -1)
ADMIN_POST_BODY=$(echo "$ADMIN_POST" | head -n -1)
assert_http_code "201" "$ADMIN_POST_CODE" "Admin creates rating draft"

RATING_ID=$(echo "$ADMIN_POST_BODY" | jq -r '.id // "null"')
if [ "$RATING_ID" = "null" ]; then
    echo "✗ No rating ID returned"
    ((FAILED++))
    exit 1
fi
echo "Created rating ID: $RATING_ID"
echo "Rating response: $(echo $ADMIN_POST_BODY | jq -c '.')"

# 保存关键字段用于后续比较
ORIG_BASE_GRADE=$(echo "$ADMIN_POST_BODY" | jq -r '.base_grade')
ORIG_PUB_GRADE=$(echo "$ADMIN_POST_BODY" | jq -r '.published_grade')
ORIG_CONFIDENCE=$(echo "$ADMIN_POST_BODY" | jq -r '.confidence')
echo "Original: base=$ORIG_BASE_GRADE, pub=$ORIG_PUB_GRADE, conf=$ORIG_CONFIDENCE"

# 4.2 普通用户POST评分 -> 403
echo
echo "[4.2] 普通用户POST评分 -> 403"
NORMAL_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $NORMAL_TOKEN" \
  -d "$RATING_DATA")
NORMAL_POST_CODE=$(echo "$NORMAL_POST" | tail -1)
assert_http_code "403" "$NORMAL_POST_CODE" "Normal user blocked from creating rating"

# 4.3 未登录POST评分 -> 401
echo
echo "[4.3] 未登录POST评分 -> 401"
ANON_POST=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -d "$RATING_DATA")
ANON_POST_CODE=$(echo "$ANON_POST" | tail -1)
assert_http_code "401" "$ANON_POST_CODE" "Anonymous blocked from creating rating"

# 4.4 管理员GET评分
echo
echo "[4.4] 管理员GET评分"
ADMIN_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
ADMIN_GET_CODE=$(echo "$ADMIN_GET" | tail -1)
ADMIN_GET_BODY=$(echo "$ADMIN_GET" | head -n -1)
assert_http_code "200" "$ADMIN_GET_CODE" "Admin reads rating draft"

assert_json_field "$ADMIN_GET_BODY" "id" "$RATING_ID" "GET returns correct rating ID"
assert_json_field "$ADMIN_GET_BODY" "project_id" "$PROJECT_ID" "GET returns correct project ID"

# 4.5 普通用户GET评分 -> 403
echo
echo "[4.5] 普通用户GET评分 -> 403"
NORMAL_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $NORMAL_TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
NORMAL_GET_CODE=$(echo "$NORMAL_GET" | tail -1)
assert_http_code "403" "$NORMAL_GET_CODE" "Normal user blocked from reading rating"

# 4.6 未登录GET评分 -> 401
echo
echo "[4.6] 未登录GET评分 -> 401"
ANON_GET=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
ANON_GET_CODE=$(echo "$ANON_GET" | tail -1)
assert_http_code "401" "$ANON_GET_CODE" "Anonymous blocked from reading rating"

# 4.7 错误project_id访问 -> 404
echo
echo "[4.7] 错误project_id访问rating -> 404"
WRONG_PROJECT_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/api/v1/projects/999/ratings/$RATING_ID")
WRONG_PROJECT_CODE=$(echo "$WRONG_PROJECT_GET" | tail -1)
assert_http_code "404" "$WRONG_PROJECT_CODE" "Rating not accessible via wrong project_id"

echo
echo "[Phase 5] 重启持久化测试"
echo "================================"

echo "[5.1] 停止服务"
stop_service
sleep 2

echo "[5.2] 重启服务（相同数据库）"
start_service

echo "[5.3] 重新登录管理员"
ADMIN_LOGIN2=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin2@test.local","password":"AdminPass123!"}')
ADMIN_TOKEN2=$(echo "$ADMIN_LOGIN2" | jq -r '.data.token // "null"')

if [ "$ADMIN_TOKEN2" = "null" ]; then
    echo "✗ Admin re-login failed"
    ((FAILED++))
    exit 1
fi
echo "✓ Admin re-login successful"
((PASSED++))

echo "[5.4] GET评分验证数据一致性"
RESTART_GET=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN2" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
RESTART_CODE=$(echo "$RESTART_GET" | tail -1)
RESTART_BODY=$(echo "$RESTART_GET" | head -n -1)
assert_http_code "200" "$RESTART_CODE" "Rating accessible after restart"

RESTART_BASE=$(echo "$RESTART_BODY" | jq -r '.base_grade')
RESTART_PUB=$(echo "$RESTART_BODY" | jq -r '.published_grade')
RESTART_CONF=$(echo "$RESTART_BODY" | jq -r '.confidence')

echo "After restart: base=$RESTART_BASE, pub=$RESTART_PUB, conf=$RESTART_CONF"

if [ "$RESTART_BASE" = "$ORIG_BASE_GRADE" ] && \
   [ "$RESTART_PUB" = "$ORIG_PUB_GRADE" ] && \
   [ "$RESTART_CONF" = "$ORIG_CONFIDENCE" ]; then
    echo "✓ PASS: All fields match after restart"
    ((PASSED++))
else
    echo "✗ FAIL: Data mismatch after restart"
    ((FAILED++))
fi

# 验证input_json也持久化了
RESTART_INPUT=$(echo "$RESTART_BODY" | jq -r '.input_json')
if echo "$RESTART_INPUT" | jq . > /dev/null 2>&1; then
    echo "✓ PASS: input_json is valid JSON"
    ((PASSED++))
else
    echo "✗ FAIL: input_json is not valid JSON"
    ((FAILED++))
fi

echo
echo "[Phase 6] SQL数据验证"
echo "================================"

# 验证表存在
TABLE_CHECK=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='rating_draft';")
if [ "$TABLE_CHECK" = "rating_draft" ]; then
    echo "✓ rating_draft table exists"
    ((PASSED++))
else
    echo "✗ rating_draft table missing"
    ((FAILED++))
fi

# 验证FK约束
FK_CHECK=$(sqlite3 "$TEST_DB" "SELECT sql FROM sqlite_master WHERE name='rating_draft';" | grep -c "FOREIGN KEY")
if [ "$FK_CHECK" -ge "2" ]; then
    echo "✓ rating_draft has FK constraints"
    ((PASSED++))
else
    echo "✗ rating_draft missing FK constraints"
    ((FAILED++))
fi

# 验证数据行
ROW_CHECK=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM rating_draft WHERE id=$RATING_ID AND project_id=$PROJECT_ID;")
if [ "$ROW_CHECK" = "1" ]; then
    echo "✓ Rating row exists in database"
    ((PASSED++))
else
    echo "✗ Rating row missing or incorrect"
    ((FAILED++))
fi

echo
echo "==================================="
echo "测试完成: $PASSED passed, $FAILED failed"
echo "==================================="

if [ $FAILED -eq 0 ]; then
    echo "✓ ALL TESTS PASSED"
    exit 0
else
    echo "✗ SOME TESTS FAILED"
    exit 1
fi
