#!/usr/bin/env bash
# E2E 冒烟 + 关机 panic/泄漏门禁（zweq 同款）。
#
# 用真实二进制 + 全新 SQLite 跑一轮完整请求面（健康探针 → 指标 → 建管理员 →
# 登录 → system/info），然后 SIGTERM 优雅关机，断言：
#   1. 20s 内退出（drain 不挂死）；
#   2. 日志无 panic；
#   3. 日志无分配器泄漏报告（SafeAllocator leaked）。
# 单测抓不到"ctx.allocator（请求侧 arena）free 是 no-op"那类静默泄漏
# （单测两侧同为 testing.allocator），只有真实进程的关机报告能抓。
#
# 用法: scripts/run_e2e.sh     （需先 zig build；依赖 curl）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/zig-out/bin"
PORT="${ZENAIPA_E2E_PORT:-18117}"
WORK="$(mktemp -d /tmp/zenaipa-e2e.XXXXXX)"
LOG="$WORK/srv.log"
ADMIN_EMAIL="e2e-admin@example.com"
ADMIN_PASS="e2e-password-123"

SRV_PID=""
cleanup() {
    if [ -n "$SRV_PID" ] && kill -0 "$SRV_PID" 2>/dev/null; then
        kill -9 "$SRV_PID" 2>/dev/null || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

fail() {
    echo "e2e: FAIL — $*"
    echo "--- server log tail ---"
    tail -30 "$LOG" 2>/dev/null || true
    exit 1
}

echo "e2e: boot (workdir $WORK)"
# export:server 与 zenaipa-admin 两个进程都必须打同一块库。
export ZENAIPA_HTTP_PORT="$PORT"
export ZENAIPA_SQLITE_PATH="$WORK/e2e.db"
export ZENAIPA_UPLOAD_DIR="$WORK/uploads"
"$BIN/zenaipa" >"$LOG" 2>&1 &
SRV_PID=$!

up=0
for _ in $(seq 1 50); do
    if ! kill -0 "$SRV_PID" 2>/dev/null; then
        fail "server exited during startup"
    fi
    if curl -sf -m 1 "http://127.0.0.1:$PORT/health/live" >/dev/null 2>&1; then
        up=1
        break
    fi
    sleep 0.2
done
[ "$up" = 1 ] || fail "server did not become ready in 10s"

echo "e2e: probes"
curl -sf -m 3 "http://127.0.0.1:$PORT/api/v1/health/ready" >/dev/null 2>&1 || fail "health/ready"
if ! curl -sf -m 3 "http://127.0.0.1:$PORT/metrics" 2>/dev/null | grep -q zenaipa_task_processed_total; then
    fail "/metrics missing dispatcher counters"
fi

echo "e2e: admin + login + system/info"
"$BIN/zenaipa-admin" create-admin --email "$ADMIN_EMAIL" --password "$ADMIN_PASS" >/dev/null 2>&1 || fail "create-admin"
LOGIN_JSON=$(curl -sf -m 3 -X POST "http://127.0.0.1:$PORT/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}") || fail "login request"
TOKEN=$(printf '%s' "$LOGIN_JSON" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] || fail "login returned no token"
if ! curl -sf -m 3 "http://127.0.0.1:$PORT/api/v1/system/info" -H "Authorization: Bearer $TOKEN" 2>/dev/null | grep -q '"version"'; then
    fail "system/info"
fi

echo "e2e: SIGTERM → graceful drain (≤20s)"
kill -TERM "$SRV_PID"
exited=0
for _ in $(seq 1 100); do
    if ! kill -0 "$SRV_PID" 2>/dev/null; then
        exited=1
        break
    fi
    sleep 0.2
done
[ "$exited" = 1 ] || fail "server did not exit within 20s of SIGTERM"
SRV_PID=""

if grep -qi "panic" "$LOG"; then
    fail "panic found in server log"
fi
if grep -qi "leaked" "$LOG"; then
    fail "allocator leak report found in server log"
fi
echo "e2e: OK (boot → probes → admin/login/info → graceful shutdown, no panic/leak)"
