#!/bin/bash
# 手动快速测试rating API

BASE_URL="http://localhost:8000"

# 启动服务
rm -f zenaipa.db
zig-out/bin/zenaipa &
SERVER_PID=$!
sleep 3

# 直接操作数据库添加管理员
sqlite3 zenaipa.db <<EOF
UPDATE user SET admin = 1 WHERE email = 'admin@test.com';
EOF

# 注册并登录管理员
ADMIN_REG=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!","name":"Admin"}')

ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!"}')
ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.token')

if [ -z "$ADMIN_TOKEN" ]; then
    echo "ERROR: No admin token"
    kill $SERVER_PID
    exit 1
fi

# 更新admin属性后重新登录验证
sqlite3 zenaipa.db "UPDATE user SET admin = 1 WHERE email = 'admin@test.com';"

# 创建项目（作为管理员）
PROJECT=$(curl -s -X POST "$BASE_URL/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"name":"Test Project","slug":"test-proj","sector":"DeFi","official_url":"https://example.com"}')
echo "Project: $PROJECT"
PROJECT_ID=$(echo "$PROJECT" | jq -r '.id')

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
    echo "ERROR: No project ID"
    kill $SERVER_PID
    exit 1
fi

# 测试1: POST评分
echo
echo "[TEST] POST rating"
RATING=$(curl -s -X POST "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"c1_tech":85,"c2_team":90,"c3_token":80,"c4_product":75,"c5_community":70,"c6_governance":65,"red_flags":[]}')
echo "Response: $RATING"

RATING_ID=$(echo "$RATING" | jq -r '.id')
if [ -z "$RATING_ID" ] || [ "$RATING_ID" = "null" ]; then
    echo "ERROR: No rating ID"
    kill $SERVER_PID
    exit 1
fi

# 测试2: GET评分
echo
echo "[TEST] GET rating"
GET_RATING=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
echo "Response: $GET_RATING"

# 测试3: 未登录GET -> 401
echo
echo "[TEST] Anonymous GET"
ANON=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/projects/$PROJECT_ID/ratings/$RATING_ID")
CODE=$(echo "$ANON" | tail -1)
echo "Status: $CODE"
if [ "$CODE" = "401" ]; then
    echo "✓ PASS: Anonymous rejected"
else
    echo "✗ FAIL: Expected 401, got $CODE"
fi

# 清理
kill $SERVER_PID
echo
echo "=== Test complete ==="
