#!/bin/bash
set -e

DB="/tmp/final_test_$$.db"
API="http://localhost:8000/api/v1"
EXIT_CODE=0

cleanup() {
    pkill -f "ZENAIPA_SQLITE_PATH=$DB" 2>/dev/null || true
    rm -f "$DB"*
}
trap cleanup EXIT

echo "=== Final RBAC + Rating Test ==="

# Ensure clean state
pkill -9 -f zenaipa 2>/dev/null || true
sleep 2

# Bootstrap
export ZENAIPA_SQLITE_PATH="$DB"
if ! /workspace/zig-out/bin/zenaipa-admin create-admin --email admin@t.co --password Admin123! --name Admin >/dev/null 2>&1; then
    echo "✗ Admin bootstrap failed"
    exit 1
fi
echo "✓ Admin bootstrapped"

# Start server
timeout 120 /workspace/zig-out/bin/zenaipa >/dev/null 2>&1 &
SVC_PID=$!
sleep 8

# Wait for server
for i in {1..10}; do
    if curl -s http://localhost:8000/health/live >/dev/null 2>&1; then
        echo "✓ Server ready"
        break
    fi
    [ $i -eq 10 ] && (echo "✗ Server timeout"; exit 1)
    sleep 1
done

# T1: Admin login
if ! RESP=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@t.co","password":"Admin123!"}' 2>&1); then
    echo "✗ T1: Curl failed"; EXIT_CODE=1
elif ! TOKEN_ADM=$(echo "$RESP" | grep -o '"token":"[^"]*' | cut -d'"' -f4) || [ -z "$TOKEN_ADM" ]; then
    echo "✗ T1: Token extraction failed"; EXIT_CODE=1
else
    echo "✓ T1: Admin login"
fi

# T2: Admin project create
if [ $EXIT_CODE -eq 0 ]; then
    PROJ=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"slug":"btc","name":"Bitcoin"}' 2>&1)
    CODE=$(echo "$PROJ" | grep "HTTP:" | cut -d: -f2)
    if [ "$CODE" = "201" ]; then
        PROJ_ID=$(echo "$PROJ" | grep -o '"id":[0-9]*' | cut -d: -f2)
        echo "✓ T2: Admin project create (id=$PROJ_ID)"
    else
        echo "✗ T2: Expected 201, got $CODE"
        EXIT_CODE=1
    fi
fi

# T3: Admin rating create
if [ $EXIT_CODE -eq 0 ]; then
    RATING=$(curl -s -w "\nHTTP:%{http_code}" -X POST "$API/projects/$PROJ_ID/ratings" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADM" -d '{"c1_tech":80}' 2>&1)
    CODE=$(echo "$RATING" | grep "HTTP:" | cut -d: -f2)
    if [ "$CODE" = "201" ]; then
        RATING_ID=$(echo "$RATING" | grep -o '"id":[0-9]*' | cut -d: -f2)
        echo "✓ T3: Admin rating create (id=$RATING_ID)"
    else
        echo "✗ T3: Expected 201, got $CODE"
        echo "Response: $RATING"
        EXIT_CODE=1
    fi
fi

# T4: Admin rating read
if [ $EXIT_CODE -eq 0 ]; then
    CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API/projects/$PROJ_ID/ratings/$RATING_ID" -H "Authorization: Bearer $TOKEN_ADM" 2>&1)
    if [ "$CODE" = "200" ]; then
        echo "✓ T4: Admin rating read"
    else
        echo "✗ T4: Expected 200, got $CODE"
        EXIT_CODE=1
    fi
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "=== 4/4 Core tests PASSED ==="
else
    echo "=== Tests FAILED ==="
fi

exit $EXIT_CODE
