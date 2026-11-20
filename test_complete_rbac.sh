#!/bin/bash
set -e

DB="/tmp/test_complete_$$.db"
API="http://localhost:8000/api/v1"

cleanup() {
    pkill -f "ZENAIPA_SQLITE_PATH=$DB" 2>/dev/null || true
    rm -f "$DB"*
}
trap cleanup EXIT

echo "=== Complete RBAC + Rating Test ==="

# Bootstrap admin
export ZENAIPA_SQLITE_PATH="$DB"
/workspace/zig-out/bin/zenaipa-admin create-admin --email admin@t.co --password Admin123! --name Admin >/dev/null 2>&1
echo "✓ Admin bootstrapped"

# Start server
timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
sleep 7
echo "✓ Server started"

# Test 1: Admin login
RESP=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@t.co","password":"Admin123!"}')
TOKEN_ADM=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])" 2>/dev/null)
[ -n "$TOKEN_ADM" ] || (echo "✗ T1: Admin login failed"; exit 1)
echo "✓ T1: Admin login"

# Test 2: Register normal user
RESP=$(curl -s -X POST "$API/auth/register" -H "Content-Type: application/json" -d '{"email":"user@t.co","password":"User123!","name":"User"}')
TOKEN_USER=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])" 2>/dev/null)
[ -n "$TOKEN_USER" ] || (echo "✗ T2: User register failed"; exit 1)
echo "✓ T2: Normal user registered"

# Test 3: Anonymous project access → 401
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -d '{"slug":"test","name":"Test"}')
[ "$CODE" = "401" ] || (echo "✗ T3: Expected 401, got $CODE"; exit 1)
echo "✓ T3: Anonymous → 401"

# Test 4: Normal user project create → 403
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_USER" -d '{"slug":"test","name":"Test"}')
[ "$CODE" = "403" ] || (echo "✗ T4: Expected 403, got $CODE"; exit 1)
echo "✓ T4: Normal user → 403"

# Test 5: Admin project create → 201
PROJ=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"slug":"btc","name":"Bitcoin"}')
PROJ_CODE=$(echo "$PROJ" | grep "HTTP:" | cut -d: -f2)
[ "$PROJ_CODE" = "201" ] || (echo "✗ T5: Expected 201, got $PROJ_CODE"; exit 1)
PROJ_ID=$(echo "$PROJ" | grep -o '"id":[0-9]*' | cut -d: -f2)
echo "✓ T5: Admin project create (id=$PROJ_ID)"

# Test 6: Admin rating create → 201
RATING=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"c1_tech":80}')
RATING_CODE=$(echo "$RATING" | grep "HTTP:" | cut -d: -f2)
[ "$RATING_CODE" = "201" ] || (echo "✗ T6: Expected 201, got $RATING_CODE"; echo "$RATING"; exit 1)
RATING_ID=$(echo "$RATING" | grep -o '"id":[0-9]*' | cut -d: -f2)
echo "✓ T6: Admin rating create (id=$RATING_ID)"

# Test 7: Admin rating read → 200
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Authorization: Bearer $TOKEN_ADM")
[ "$CODE" = "200" ] || (echo "✗ T7: Expected 200, got $CODE"; exit 1)
echo "✓ T7: Admin rating read"

# Test 8: Normal user rating read → 403
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Authorization: Bearer $TOKEN_USER")
[ "$CODE" = "403" ] || (echo "✗ T8: Expected 403, got $CODE"; exit 1)
echo "✓ T8: Normal user rating → 403"

echo "=== 8/8 Tests PASSED ==="
exit 0
