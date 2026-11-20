#!/bin/bash
set -e

DB="/tmp/pub_http_$$.db"
API="http://localhost:8000/api/v1"

cleanup() {
    pkill -f "ZENAIPA_SQLITE_PATH=$DB" 2>/dev/null || true
    rm -f "$DB"*
}
trap cleanup EXIT

PASS=0
FAIL=0

assert_http() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "✓ $name"
        PASS=$((PASS + 1))
    else
        echo "✗ $name (expected $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

pkill -9 -f zenaipa 2>/dev/null || true
sleep 2

export ZENAIPA_SQLITE_PATH="$DB"
/workspace/zig-out/bin/zenaipa-admin create-admin --email a@t.co --password Pass123! --name A >/dev/null 2>&1
/workspace/zig-out/bin/zenaipa-admin create-admin --email b@t.co --password Pass123! --name B >/dev/null 2>&1

echo "=== HTTP Publish Flow Test ==="

timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
sleep 8

TOKEN_A=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"a@t.co","password":"Pass123!"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
TOKEN_B=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"b@t.co","password":"Pass123!"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Create project and rating
PROJ_ID=$(curl -s -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"slug":"btc","name":"Bitcoin"}' | grep -o '"id":[0-9]*' | cut -d: -f2)
RATING_ID=$(curl -s -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"c1_tech":70}' | grep -o '"id":[0-9]*' | cut -d: -f2)

echo "  Project: $PROJ_ID, Rating: $RATING_ID"

# T1: Cannot publish before approval
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/internal/projects/$PROJ_ID/ratings/$RATING_ID/publish" -H "Authorization: Bearer $TOKEN_A")
assert_http "T1: Cannot publish draft" "409" "$CODE"

# T2: Submit (with placeholder report fields)
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/submit" -H "Authorization: Bearer $TOKEN_A")
assert_http "T2: Submit succeeds" "200" "$CODE"

# T3: Approve
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $TOKEN_B")
assert_http "T3: Approve succeeds" "200" "$CODE"

# T4: Publish approved rating
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/internal/projects/$PROJ_ID/ratings/$RATING_ID/publish" -H "Authorization: Bearer $TOKEN_A")
assert_http "T4: Publish succeeds" "200" "$CODE"

# T5: Anonymous can read published
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/public/projects/$PROJ_ID/rating")
assert_http "T5: Anonymous read succeeds" "200" "$CODE"

# T6: Published contains grade, no input_json
RESPONSE=$(curl -s -X GET "$API/public/projects/$PROJ_ID/rating")
echo "$RESPONSE" | grep -q '"grade"' && echo "✓ T6: Grade present" && PASS=$((PASS + 1)) || (echo "✗ T6: Grade missing" && FAIL=$((FAIL + 1)))
echo "$RESPONSE" | grep -q 'input_json' && (echo "✗ T7: Input leaked" && FAIL=$((FAIL + 1))) || (echo "✓ T7: Input not leaked" && PASS=$((PASS + 1)))

# T8: Duplicate publish rejected
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/internal/projects/$PROJ_ID/ratings/$RATING_ID/publish" -H "Authorization: Bearer $TOKEN_A")
assert_http "T8: Duplicate publish 409" "409" "$CODE"

# T9: Revoke
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/internal/projects/$PROJ_ID/ratings/$RATING_ID/revoke" -H "Authorization: Bearer $TOKEN_A")
assert_http "T9: Revoke succeeds" "200" "$CODE"

# T10: Anonymous gets 410 after revoke
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/public/projects/$PROJ_ID/rating")
assert_http "T10: Revoked returns 410" "410" "$CODE"

echo ""
echo "=== HTTP Publish: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
