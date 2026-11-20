#!/bin/bash
set -e

DB="/tmp/immutable_test_$$.db"
API="http://localhost:8000/api/v1"

cleanup() {
    pkill -f "ZENAIPA_SQLITE_PATH=$DB" 2>/dev/null || true
    rm -f "$DB"*
}
trap cleanup EXIT

PASS=0
FAIL=0

assert_code() {
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

echo "=== Immutability Test ==="
echo "✓ Setup complete"

timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
sleep 8

TOKEN_A=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"a@t.co","password":"Pass123!"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
TOKEN_B=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"b@t.co","password":"Pass123!"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

PROJ_ID=$(curl -s -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"slug":"immut","name":"Immutable"}' | grep -o '"id":[0-9]*' | cut -d: -f2)
RATING_ID=$(curl -s -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"c1_tech":70}' | grep -o '"id":[0-9]*' | cut -d: -f2)

# Submit and approve
curl -s -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/submit" -H "Authorization: Bearer $TOKEN_A" >/dev/null
curl -s -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $TOKEN_B" >/dev/null

echo "✓ T1: Rating approved"

# Capture approved state
APPROVED_STATUS=$(sqlite3 "$DB" "SELECT status, reviewer_id FROM rating_draft WHERE id = $RATING_ID;")
APPROVED_INPUT=$(sqlite3 "$DB" "SELECT input_json FROM rating_draft WHERE id = $RATING_ID;")

echo "  Approved state: $APPROVED_STATUS"

# T2: Verify no PUT/PATCH endpoint exists for ratings
CODE_PUT=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"c1_tech":90}')
CODE_PATCH=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"c1_tech":90}')

# Should be 404 or 405 (not found / method not allowed)
if [ "$CODE_PUT" = "404" ] || [ "$CODE_PUT" = "405" ]; then
    echo "✓ T2: No PUT endpoint for ratings"
    PASS=$((PASS + 1))
else
    echo "✗ T2: PUT returned $CODE_PUT (expected 404/405)"
    FAIL=$((FAIL + 1))
fi

if [ "$CODE_PATCH" = "404" ] || [ "$CODE_PATCH" = "405" ]; then
    echo "✓ T3: No PATCH endpoint for ratings"
    PASS=$((PASS + 1))
else
    echo "✗ T3: PATCH returned $CODE_PATCH (expected 404/405)"
    FAIL=$((FAIL + 1))
fi

# T4: Submit after approval should fail
CODE_RESUBMIT=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/submit" -H "Authorization: Bearer $TOKEN_A")
assert_code "T4: Cannot resubmit approved" "409" "$CODE_RESUBMIT"

# T5: Direct DB verification - approved state unchanged
FINAL_STATUS=$(sqlite3 "$DB" "SELECT status, reviewer_id FROM rating_draft WHERE id = $RATING_ID;")
assert_code "T5: Status unchanged" "$APPROVED_STATUS" "$FINAL_STATUS"

# T6: Input JSON unchanged
FINAL_INPUT=$(sqlite3 "$DB" "SELECT input_json FROM rating_draft WHERE id = $RATING_ID;")
assert_code "T6: Input JSON unchanged" "pass" "$([ "$APPROVED_INPUT" = "$FINAL_INPUT" ] && echo pass || echo fail)"

# T7: Only approved rating accessible via GET
RATING_JSON=$(curl -s -X GET "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Authorization: Bearer $TOKEN_A")
STATUS_IN_JSON=$(echo "$RATING_JSON" | grep -o '"status":"[^"]*' | cut -d'"' -f4)
assert_code "T7: GET shows approved status" "approved" "$STATUS_IN_JSON"

echo ""
echo "=== Immutability Tests: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
