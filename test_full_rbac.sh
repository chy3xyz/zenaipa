#!/bin/bash
# Full RBAC + Rating Test: admin/normal/anonymous, 20 iterations, restart persistence
set -e

DB="/tmp/full_test_$$.db"
API="http://localhost:8000/api/v1"
PASS_COUNT=0
FAIL_COUNT=0

test_assert() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    
    if [ "$expected" = "$actual" ]; then
        echo "✓ $name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo "✗ $name (expected $expected, got $actual)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

cleanup() {
    pkill -f "ZENAIPA_SQLITE_PATH=$DB" 2>/dev/null || true
    rm -f "$DB"*
}
trap cleanup EXIT

echo "=== Full RBAC + Persistence Test ==="

# Clean state
pkill -9 -f zenaipa 2>/dev/null || true
sleep 2

# Bootstrap
export ZENAIPA_SQLITE_PATH="$DB"
/workspace/zig-out/bin/zenaipa-admin create-admin --email admin@t.co --password Admin123! --name Admin >/dev/null 2>&1
echo "✓ Admin bootstrapped"

# Start server
timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
SVC_PID=$!
sleep 8
echo "✓ Server started"

# Register normal user
RESP=$(curl -s -X POST "$API/auth/register" -H "Content-Type: application/json" -d '{"email":"user@t.co","password":"User123!","name":"User"}')
TOKEN_USER=$(echo "$RESP" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
test_assert "T1: Normal user register" "pass" "$([ -n "$TOKEN_USER" ] && echo pass || echo fail)"

# Admin login
RESP=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@t.co","password":"Admin123!"}')
TOKEN_ADM=$(echo "$RESP" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
test_assert "T2: Admin login" "pass" "$([ -n "$TOKEN_ADM" ] && echo pass || echo fail)"

# T3: Anonymous project POST → 401
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -d '{"slug":"test","name":"Test"}')
test_assert "T3: Anonymous project POST" "401" "$CODE"

# T4: Normal user project POST → 403
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_USER" -d '{"slug":"test","name":"Test"}')
test_assert "T4: Normal user project POST" "403" "$CODE"

# T5: Admin project POST → 201
PROJ=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"slug":"btc","name":"Bitcoin"}')
CODE=$(echo "$PROJ" | grep "HTTP:" | cut -d: -f2)
PROJ_ID=$(echo "$PROJ" | grep -o '"id":[0-9]*' | cut -d: -f2)
test_assert "T5: Admin project POST" "201" "$CODE"

# T6-25: 20 iterations of rating POST + GET
echo "Running 20 rating iterations..."
for i in {1..20}; do
    RATING=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"c1_tech":80}' 2>&1)
    CODE=$(echo "$RATING" | grep "HTTP:" | cut -d: -f2)
    if [ "$CODE" != "201" ]; then
        echo "✗ Iteration $i POST failed ($CODE)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        break
    fi
    
    RATING_ID=$(echo "$RATING" | grep -o '"id":[0-9]*' | cut -d: -f2)
    CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Authorization: Bearer $TOKEN_ADM")
    if [ "$CODE" != "200" ]; then
        echo "✗ Iteration $i GET failed ($CODE)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        break
    fi
    
    [ $((i % 5)) -eq 0 ] && echo "  $i/20 iterations OK"
done
if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ T6: 20 rating POST+GET iterations"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# Store last rating ID for restart test
LAST_RATING_ID=$RATING_ID

# T7: Normal user rating GET → 403
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$LAST_RATING_ID" -H "Authorization: Bearer $TOKEN_USER")
test_assert "T7: Normal user rating GET" "403" "$CODE"

# T8: Anonymous rating GET → 401
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$LAST_RATING_ID")
test_assert "T8: Anonymous rating GET" "401" "$CODE"

# T9: Wrong project_id → 404
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/9999/ratings/$LAST_RATING_ID" -H "Authorization: Bearer $TOKEN_ADM")
test_assert "T9: Wrong project_id" "404" "$CODE"

# T10: Restart persistence
echo "Restarting server..."
kill $SVC_PID 2>/dev/null || true
sleep 3
timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
sleep 8

RESP=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@t.co","password":"Admin123!"}')
TOKEN_ADM2=$(echo "$RESP" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

RATING_DATA=$(curl -s -X GET "$API/projects/$PROJ_ID/ratings/$LAST_RATING_ID" -H "Authorization: Bearer $TOKEN_ADM2")
RETRIEVED_ID=$(echo "$RATING_DATA" | grep -o '"id":[0-9]*' | cut -d: -f2)
test_assert "T10: Restart persistence" "$LAST_RATING_ID" "$RETRIEVED_ID"

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
