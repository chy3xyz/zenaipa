#!/bin/bash
set -e

DB="/tmp/concurrent_test_$$.db"
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

# Setup: Kill any existing server
pkill -9 -f zenaipa 2>/dev/null || true
sleep 2

# Bootstrap DB with 3 admins (A=analyst, B=reviewer1, C=reviewer2)
export ZENAIPA_SQLITE_PATH="$DB"
/workspace/zig-out/bin/zenaipa-admin create-admin --email a@t.co --password Pass123! --name AnalystA >/dev/null 2>&1
/workspace/zig-out/bin/zenaipa-admin create-admin --email b@t.co --password Pass123! --name ReviewerB >/dev/null 2>&1
/workspace/zig-out/bin/zenaipa-admin create-admin --email c@t.co --password Pass123! --name ReviewerC >/dev/null 2>&1

echo "=== Concurrent Approval Test ==="
echo "✓ Three admins created"

# Start server
timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
SERVER_PID=$!
sleep 8
echo "✓ Server started (PID: $SERVER_PID)"

# Login all three
TOKEN_A=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"a@t.co","password":"Pass123!"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
TOKEN_B=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"b@t.co","password":"Pass123!"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
TOKEN_C=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"c@t.co","password":"Pass123!"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Create project and rating
PROJ_ID=$(curl -s -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"slug":"concurrent-test","name":"Concurrent Test"}' | grep -o '"id":[0-9]*' | cut -d: -f2)
RATING_ID=$(curl -s -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_A" -d '{"c1_tech":75,"c2_team":80}' | grep -o '"id":[0-9]*' | cut -d: -f2)

echo "  Project ID: $PROJ_ID"
echo "  Rating ID: $RATING_ID"

# Submit
curl -s -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/submit" -H "Authorization: Bearer $TOKEN_A" >/dev/null

echo "✓ T1: Rating submitted"

# T2: Concurrent approval attempts by B and C
# Launch both in background with sub-second timing
(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $TOKEN_B" > /tmp/approve_b_$$.txt) &
PID_B=$!

(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $TOKEN_C" > /tmp/approve_c_$$.txt) &
PID_C=$!

# Wait for both to complete
wait $PID_B
wait $PID_C

CODE_B=$(grep "HTTP:" /tmp/approve_b_$$.txt | cut -d: -f2)
CODE_C=$(grep "HTTP:" /tmp/approve_c_$$.txt | cut -d: -f2)

echo "  Reviewer B response: HTTP $CODE_B"
echo "  Reviewer C response: HTTP $CODE_C"

# One must be 200, one must be 409
if [ "$CODE_B" = "200" ] && [ "$CODE_C" = "409" ]; then
    echo "✓ T2: Concurrent CAS (B succeeded, C rejected)"
    PASS=$((PASS + 1))
    WINNER="2"  # User ID for B
elif [ "$CODE_C" = "200" ] && [ "$CODE_B" = "409" ]; then
    echo "✓ T2: Concurrent CAS (C succeeded, B rejected)"
    PASS=$((PASS + 1))
    WINNER="3"  # User ID for C
else
    echo "✗ T2: Concurrent CAS failed (B=$CODE_B, C=$CODE_C, expected one 200 and one 409)"
    FAIL=$((FAIL + 1))
    WINNER=""
fi

# T3: Verify exactly one audit entry for approve action
AUDIT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM rating_audit WHERE rating_id = $RATING_ID AND action = 'approve';")
assert_code "T3: Exactly 1 approve audit" "1" "$AUDIT_COUNT"

# T4: Verify reviewer_id matches the winner
if [ -n "$WINNER" ]; then
    REVIEWER=$(sqlite3 "$DB" "SELECT reviewer_id FROM rating_draft WHERE id = $RATING_ID;")
    assert_code "T4: Winner is recorded reviewer" "$WINNER" "$REVIEWER"
fi

# T5: Third attempt by the loser should also fail with 409
LOSER_TOKEN=""
if [ "$WINNER" = "2" ]; then
    LOSER_TOKEN="$TOKEN_C"
else
    LOSER_TOKEN="$TOKEN_B"
fi
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID/approve" -H "Authorization: Bearer $LOSER_TOKEN")
assert_code "T5: Third approve attempt rejected" "409" "$CODE"

# T6: Audit count still 1 after failed attempts
AUDIT_COUNT_FINAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM rating_audit WHERE rating_id = $RATING_ID AND action = 'approve';")
assert_code "T6: Audit count unchanged" "1" "$AUDIT_COUNT_FINAL"

# T7: Concurrent submit test (create new rating)
RATING_ID2=$(curl -s -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_B" -d '{"c1_tech":85}' | grep -o '"id":[0-9]*' | cut -d: -f2)

# Two concurrent submits from same analyst (should race)
(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID2/submit" -H "Authorization: Bearer $TOKEN_B" > /tmp/submit_b1_$$.txt) &
PID_S1=$!
(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings/$RATING_ID2/submit" -H "Authorization: Bearer $TOKEN_B" > /tmp/submit_b2_$$.txt) &
PID_S2=$!

wait $PID_S1
wait $PID_S2

CODE_S1=$(grep "HTTP:" /tmp/submit_b1_$$.txt | cut -d: -f2)
CODE_S2=$(grep "HTTP:" /tmp/submit_b2_$$.txt | cut -d: -f2)

# One 200, one 409 (or both 200 if serialized perfectly fast)
if [ "$CODE_S1" = "200" ] && [ "$CODE_S2" = "409" ]; then
    echo "✓ T7: Concurrent submit serialized (first succeeded)"
    PASS=$((PASS + 1))
elif [ "$CODE_S2" = "200" ] && [ "$CODE_S1" = "409" ]; then
    echo "✓ T7: Concurrent submit serialized (second succeeded)"
    PASS=$((PASS + 1))
elif [ "$CODE_S1" = "200" ] && [ "$CODE_S2" = "200" ]; then
    # Check if status is submitted and only 1 submit audit
    SUBMIT_AUDIT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM rating_audit WHERE rating_id = $RATING_ID2 AND action = 'submit';")
    if [ "$SUBMIT_AUDIT" = "1" ]; then
        echo "✓ T7: Concurrent submit both 200 but CAS serialized (1 audit)"
        PASS=$((PASS + 1))
    else
        echo "✗ T7: Both submit returned 200 with $SUBMIT_AUDIT audits (expected 1)"
        FAIL=$((FAIL + 1))
    fi
else
    echo "✗ T7: Concurrent submit unexpected (S1=$CODE_S1, S2=$CODE_S2)"
    FAIL=$((FAIL + 1))
fi

# Cleanup temp files
rm -f /tmp/approve_b_$$.txt /tmp/approve_c_$$.txt /tmp/submit_b1_$$.txt /tmp/submit_b2_$$.txt

echo ""
echo "=== Concurrent Tests: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
