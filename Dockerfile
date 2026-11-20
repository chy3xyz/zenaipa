# zenaipa — 单二进制 API 服务（Zig 后端；SPA 由静态主机托管，镜像内附带 dist 备用）
#
# 自包含构建：依赖按 build.zig.zon 的 git tag 引用在容器内 fetch（需 git 与网络），
# 构建上下文即本仓库（配合根 .dockerignore 裁剪），不再依赖兄弟目录布局。
#
# Zig 版本说明：0.17.0 正式版已发布，本地/CI/Dockerfile 统一钉 0.17.0
# （ziglang.org/download），与 build.zig.zon 的 minimum_zig_version 一致，
# 避免 dev 快照漂移导致编译差异。

# ── 前端：SolidJS → web/dist ──────────────────────────────────────
FROM node:22-alpine AS frontend
WORKDIR /app
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY web/ ./
RUN npm run build

# ── 后端：Zig 0.17.0 正式版 ───────────────────────────────────────
# alpine 与运行阶段同基底（musl ABI 一致）；dev 包提供 pq/sqlite3 的头文件
# 与链接库（驱动按需链接：默认 sqlite+postgres，不含 mysql，见 build.zig -Ddb=）。
FROM alpine:3.21 AS backend
# TARGETARCH 由 BuildKit 注入（amd64/arm64），映射到 zig 官方 tarball 的命名
ARG TARGETARCH
ARG ZIG_VERSION=0.17.0
RUN apk add --no-cache git postgresql-dev sqlite-dev tar xz \
 && case "${TARGETARCH}" in \
      amd64) ZIG_TUPLE=x86_64-linux ;; \
      arm64) ZIG_TUPLE=aarch64-linux ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_TUPLE}-${ZIG_VERSION}.tar.xz" \
 && tar -xJf "zig-${ZIG_TUPLE}-${ZIG_VERSION}.tar.xz" -C /opt \
 && mv "/opt/zig-${ZIG_TUPLE}-${ZIG_VERSION}" /opt/zig \
 && ln -s /opt/zig/zig /usr/local/bin/zig
WORKDIR /src
COPY build.zig build.zig.zon db_link.zig ./
COPY src ./src
# BuildKit cache mount 复用依赖 fetch 与编译缓存（.zig-cache 本地 / ~/.cache/zig 全局）
RUN --mount=type=cache,target=/src/.zig-cache \
    --mount=type=cache,target=/root/.cache/zig \
    zig build -Doptimize=ReleaseSafe --summary all
# 运行镜像不需要调试符号：strip 掉 DWARF/符号表，二进制体积约砍 2/3
RUN apk add --no-cache binutils \
 && strip /src/zig-out/bin/zenaipa /src/zig-out/bin/zenaipa-admin

# ── 运行镜像（与构建阶段同 alpine 版本，动态库版本匹配）──────────
FROM alpine:3.21
RUN apk add --no-cache ca-certificates libpq sqlite-libs \
 && addgroup -S zenaipa && adduser -S -G zenaipa zenaipa
WORKDIR /app
COPY --from=backend /src/zig-out/bin/zenaipa /usr/local/bin/zenaipa
COPY --from=backend /src/zig-out/bin/zenaipa-admin /usr/local/bin/zenaipa-admin
# SPA 静态资源：本镜像不直接服务静态文件（反代/静态主机指向该目录即可）
COPY --from=frontend /app/dist /app/web-dist
# 数据目录（sqlite/上传）归非 root 用户；/app/web-dist 只读即可
RUN mkdir -p /data && chown -R zenaipa:zenaipa /data
ENV ZENAIPA_DB_DRIVER=sqlite \
    ZENAIPA_SQLITE_PATH=/data/zenaipa.db \
    ZENAIPA_UPLOAD_DIR=/data/uploads \
    ZENAIPA_HTTP_PORT=8000
VOLUME ["/data"]
EXPOSE 8000
# 非 root 运行：被攻破的进程拿不到容器 root
USER zenaipa
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8000/health/live || exit 1
CMD ["/usr/local/bin/zenaipa"]
