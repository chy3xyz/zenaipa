#!/bin/bash
set -e

echo "=== Testing FK from App Connection ==="

# 启动服务确保app初始化了连接
pkill -9 zenaipa 2>/dev/null || true
sleep 1

./zig-out/bin/zenaipa serve sqlite,postgres > /tmp/fk_test.log 2>&1 &
SERVER_PID=$!
sleep 4

echo ""
echo "1. Checking FK setting from CLI (not reliable for app setting):"
sqlite3 zenaipa.db "PRAGMA foreign_keys;" | head -1

echo ""
echo "2. Checking WAL mode:"
sqlite3 zenaipa.db "PRAGMA journal_mode;" | head -1

echo ""
echo "3. Creating test tables with FK constraint:"
sqlite3 zenaipa.db << 'EOFSQL'
CREATE TABLE IF NOT EXISTS test_parent (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS test_child (
    id INTEGER PRIMARY KEY,
    parent_id INTEGER NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES test_parent(id)
);

INSERT INTO test_parent (id, name) VALUES (1, 'Parent 1');
EOFSQL

echo "✓ Created test tables with FK"

echo ""
echo "4. Testing FK enforcement:"
echo "   Attempting to insert child with non-existent parent_id=999..."

# 尝试插入非法外键
if sqlite3 zenaipa.db "INSERT INTO test_child (id, parent_id) VALUES (1, 999);" 2>&1 | grep -q "FOREIGN KEY"; then
    echo "✓ FK constraint enforced: insertion rejected"
    FK_WORKING=1
else
    # 检查是否插入成功（说明FK未启用）
    if sqlite3 zenaipa.db "SELECT COUNT(*) FROM test_child WHERE parent_id=999;" | grep -q "1"; then
        echo "✗ FK constraint NOT enforced: invalid insertion succeeded"
        echo ""
        echo "Issue: FK not enabled. Need to call PRAGMA foreign_keys=ON on each connection."
        FK_WORKING=0
    else
        echo "? FK test inconclusive"
        FK_WORKING=0
    fi
fi

echo ""
echo "5. Checking actual FK setting:"
sqlite3 zenaipa.db "PRAGMA foreign_keys;"

# 清理
sqlite3 zenaipa.db "DROP TABLE IF EXISTS test_child; DROP TABLE IF EXISTS test_parent;"
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

echo ""
if [ "$FK_WORKING" = "1" ]; then
    echo "=== FK properly configured ==="
else
    echo "=== FK configuration needed ==="
    echo "Solution: Execute 'PRAGMA foreign_keys=ON' after opening each connection"
fi

exit $((1 - FK_WORKING))
