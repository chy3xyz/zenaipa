#!/bin/bash
set -e

API="http://localhost:8000/api/v1"
DB="/tmp/test_v2_$$.db"

echo "=== HTTP RBAC Test (DB=$DB) ==="

cleanup() {
    pkill -f "ZENAIPA_SQLITE_PATH=$DB" 2>/dev/null || true
    rm -f "$DB"*
}
trap cleanup EXIT

# Step 1: Bootstrap admin (before service starts)
echo -n "Bootstrap admin: "
export ZENAIPA_SQLITE_PATH="$DB"
/workspace/zig-out/bin/zenaipa-admin create-admin --email admin@t.co --password Admin123! --name "Admin" >/dev/null 2>&1 && echo "OK" || (echo "FAIL"; exit 1)

# Step 2: Start service
export ZENAIPA_SQLITE_PATH="$DB"
timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
sleep 7

# Test 1: Register normal user
echo -n "T1 (register): "
RESP=$(curl -s -X POST "$API/auth/register" -H "Content-Type: application/json" -d '{"email":"user@t.co","password":"Pass123!","name":"User"}')
TOKEN_USER=$(echo "$RESP" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
[ -n "$TOKEN_USER" ] && echo "PASS" || (echo "FAIL"; exit 1)

# Test 2: Normal user → 403
echo -n "T2 (user 403): "
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_USER" -d '{"slug":"test","name":"Test"}')
[ "$CODE" = "403" ] && echo "PASS" || (echo "FAIL ($CODE)"; exit 1)

# Test 3: Admin login
echo -n "T3 (admin login): "
RESP_ADM=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@t.co","password":"Admin123!"}')
TOKEN_ADM=$(echo "$RESP_ADM" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
[ -n "$TOKEN_ADM" ] && echo "PASS" || (echo "FAIL: $RESP_ADM"; exit 1)

# Test 4: Admin creates project → 201
echo -n "T4 (admin 201): "
PROJ_RESP=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"slug":"btc","name":"Bitcoin"}')
PROJ_CODE=$(echo "$PROJ_RESP" | grep "HTTP:" | cut -d: -f2)
[ "$PROJ_CODE" = "201" ] && echo "PASS" || (echo "FAIL ($PROJ_CODE): $PROJ_RESP"; exit 1)

PROJ_ID=$(echo "$PROJ_RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "  Project ID=$PROJ_ID"

# Test 5: Admin creates rating → 201
echo -n "T5 (rating 201): "
RATING_RESP=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"c1_tech":80,"c2_team":75,"confidence":85}')
RATING_CODE=$(echo "$RATING_RESP" | grep "HTTP:" | cut -d: -f2)
[ "$RATING_CODE" = "201" ] && echo "PASS" || (echo "FAIL ($RATING_CODE): $RATING_RESP"; exit 1)

RATING_ID=$(echo "$RATING_RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

# Test 6: Admin reads rating → 200
echo -n "T6 (read 200): "
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Authorization: Bearer $TOKEN_ADM")
[ "$CODE" = "200" ] && echo "PASS" || (echo "FAIL ($CODE)"; exit 1)

# Test 7: Normal user rating → 403
echo -n "T7 (user 403): "
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Authorization: Bearer $TOKEN_USER")
[ "$CODE" = "403" ] && echo "PASS" || (echo "FAIL ($CODE)"; exit 1)

echo "=== All 7 tests PASSED ==="
exit 0
