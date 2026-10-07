#!/bin/sh
# 文件行数上限门禁：单文件 ≤1800 行，防"万能文件"回潮（zweq 同款门禁）。
# POSIX sh 兼容（build.zig 以 /bin/sh 调起）。
# 用法: scripts/check_file_size.sh [max_lines]   (默认 1800)
set -eu

MAX="${1:-1800}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

# src/**/*.zig + build.zig；避免进程替换（/bin/sh 无 <()）。
FILES=$(find "$ROOT/src" -name '*.zig' -type f 2>/dev/null
        [ -f "$ROOT/build.zig" ] && echo "$ROOT/build.zig")

for f in $FILES; do
    lines=$(wc -l < "$f" | tr -d ' ')
    if [ "$lines" -gt "$MAX" ]; then
        echo "TOO BIG: $f ($lines > $MAX lines)"
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    echo "lint-size: FAILED (limit ${MAX} lines/file)"
    exit 1
fi
echo "lint-size: OK (all files <= ${MAX} lines)"
