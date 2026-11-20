#!/bin/bash
set -e

DB="/tmp/approval_test_$$.db"
API="http://localhost:8000/api/v1"
PASS=0
FAIL=0

assert_code() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "✓ $name"
        PASS=$((PASS + 1))
    else
        echo "✗ $name (expected $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

cleanup() {
    pkill -f "ZENAIPA_SQLITE_PATH=$DB" 2>/dev/null || true
    rm -f "$DB"*
}
trap cleanup EXIT

echo "=== Approval Workflow Test ==="
pkill -9 -f zenaipa 2>/dev/null || true
sleep 2

# Create two admin users (analyst A and reviewer B)
export ZENAIPA_SQLITE_PATH="$DB"
/workspace/zig-out/bin/zenaipa-admin create-admin --email analyst@t.co --password Pass123! --name AnalystA >/dev/null 2>&1
/workspace/zig-out/bin/zenaipa-admin create-admin --email reviewer@t.co --password Pass123! --name ReviewerB >/dev/null 2>&1
echo "✓ Two admins created"

# Start server
timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
sleep 8
echo "✓ Server started"

# Login A and B
RESP_A=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"analyst@t.co","password":"Pass123!"}')
TOKEN_A=$(echo "$RESP_A" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
assert_code "T1: Analyst A login" "pass" "$([ -n "$TOKEN_A" ] && echo pass || echo fail)"

RESP_B=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"reviewer@t.co","password":"Pass123!"}')
TOKEN_B=$(echo "$RESP_B" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
assert_code "T2: Reviewer B login" "pass" "$([ -n "$TOKEN_B" ] && echo pass || echo fail)"

# A creates project
PROJ=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"slug":"btc","name":"Bitcoin"}')
PROJ_ID=$(echo "$PROJ" | grep -o '"id":[0-9]*' | cut -d: -f2)
echo "  Project ID: $PROJ_ID"

# A creates rating draft
RATING=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"c1_tech":80}')
RATING_ID=$(echo "$RATING" | grep -o '"id":[0-9]*' | cut -d: -f2)
echo "  Rating ID: $RATING_ID"

# T3: A submits rating
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/submit" -H "Authorization: Bearer $TOKEN_A")
assert_code "T3: A submits rating" "200" "$CODE"

# T4: A tries to self-approve → 409
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $TOKEN_A")
assert_code "T4: Self-approve rejected" "409" "$CODE"

# T5: B approves → 200
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $TOKEN_B")
assert_code "T5: B approves rating" "200" "$CODE"

# T6: Duplicate approve → 409
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $TOKEN_B")
assert_code "T6: Duplicate approve rejected" "409" "$CODE"

# T7: Check audit log
AUDIT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM rating_audit WHERE rating_id = $RATING_ID;")
assert_code "T7: Audit entries exist" "pass" "$([ "$AUDIT_COUNT" -ge 3 ] && echo pass || echo fail)"

echo ""
echo "=== Approval Tests: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
