# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2026-10-12

### Dependencies

- **zent v0.87.0 → v0.91.0 + zigmodu v0.39.9 → v0.39.11**（上游最新）。
  zigmodu 用面签名零变化（drop-in）。zent 0.88–0.91：受控 JOIN v1
  （`QueryBuilder.joinEdge`）、0.90 的四个可失败孪生构造器（原
  `Insert/Update/Delete` 工厂不变，本 app 零改动）、SQLite 文本数值可选
  解析、一批 OOM 路径修复（分配失败扫描覆盖 eager-load/join 组装/
  `BulkDeleteBuilder` 等）。清 `.zig-cache` 后 38 测试 + e2e 门禁全绿。

## [0.3.1] - 2026-10-10

### Fixed

- **web 依赖审计收敛**：`npm audit fix` 处理 6 → 3 个通告；剩余 3 个位于
  dev 工具链（vitest→tinypool，需 vitest@5 跨大版本），不在 rsbuild 产物
  内。CI 审计门禁改为 `npm audit --omit=dev --audit-level=high`（只把
  发布面当门禁），生产依赖实测 0 漏洞。

### Dependencies

- **zent v0.83.0 → v0.87.0 + zigmodu v0.39.6 → v0.39.9**（上游最新）。
  zigmodu 对本 app 用面零签名变化（仅新增 `tableLoaderSlotsClaimed` /
  `openApiBindingsClaimed` / `resultHandler`），drop-in。zent 0.84–0.87
  为驱动与内存修复（PG prepared-statement 缓存接入 `query()`、MySQL
  bool/float 假漂移、edge FK 按 `table_name` 解析、若干 OOM 泄漏）加
  附加式 API（`field.String…VarChar(n)`、`client.<t>.AllOwned(alloc)`）；
  0.84 的 EntQL "字段名优先" 改动不涉及本 app（未用 `WhereEntQL`/`has()`）。
  无代码改动，清 `.zig-cache` 后 38 测试 + e2e 门禁全绿。

## [0.3.0] - 2026-10-07

### Web 控制台（对齐 zweq UI 实践）

- **修复：表格页不再"打开即空"**。`usePaged` 原本不自动加载，6 个表格页挂载后
  必须手动点查询才出数据；现在挂载自动请求，并新增 `refresh()` /
  `changePageSize()` / `watch`（依赖变化自动回第 1 页），保留防乱序的
  requestSeq 守卫。浏览器实测：登录落地 /users 即见数据。
- **修复：服务端中文错误信息真正可见**。axios 响应拦截器解析非 2xx 响应体的
  `{code,msg}` 信封并抛 `ApiError`（此前 400 只能看到 axios 默认英文文案）。
- **请求数据层收敛**：`get/post/put/deleteEnvelope<T>` 上移到 `client.ts`，
  10 个域目录的重复实现与 ~8 处手写 `XListResult` 分页形状（→ `PageResult<T>`）
  全部收敛；`toApiError` 移入 client（barrel 保持原导出路径）。
- **组件基建**（新）：`BaseModal`/`FormModal`/`FormField`（统一弹窗三层 +
  每弹窗独立提交态，防双击）、`FeedbackProvider`（toast + Promise 确认框 +
  `runAction` 标准动作流，替换全部 `window.confirm`(7 处)/`window.alert`(3 处)
  与内联成功块）、`Pagination`（页码窗口/页大小/跳页）、`AdminCrudPage`
  页骨架、`SearchBar`（草稿式筛选）、`EmptyState`、`StatCard`；
  `DataTable` 集成完整分页器 + 加载遮罩 + 吸右操作列。
- **页面迁移**：Users 为参照实现；Tenants/Tasks/Files/AuditLogs/MailTemplates/
  Dashboard/Profile/AiAdmin/AiChat 全部采用新组件。AiAdmin 三张手写表换
  DataTable + 分页，provider 弹窗补提交态（此前可双击重复提交），批准/拒绝
  加行级 busy；Tasks/Dashboard 统计卡片改挂载即加载。
- **壳与导航**：侧边栏改 `constants/nav.ts` 配置驱动（消除 10 处重复类名串）；
  深色模式默认跟随 `prefers-color-scheme`（保留手动切换 + 持久化）。
- **清理与测试**：删除失联的 `pages/index.ts` barrel、过期注释与未用 env 声明；
  新增 5 个测试文件 21 个用例（envelope 解包、usePaged 自动加载/乱序守卫/
  changePageSize/watch、FormModal 提交态）。`typecheck`/`vitest`(21)/`build`
  全绿，并经真实浏览器（登录 → 表格自动加载 → 跨页抽查）验证。

### Dependencies

- **zent v0.67.0 → v0.83.0 + zigmodu v0.20.1 → v0.39.6**, pinned by git
  tag + content hash. zigmodu v0.39.6 is upstream's latest; zent lands on
  the current latest (v0.83.0, ahead of the sibling project's v0.78.0).
  Compile-level breaks adopted: middleware factories (`cors`,
  `securityHeaders`, `rateLimitPerClient`) are now fallible (`try`);
  `SecurityModule.verifyPassword` returns
  `error{MalformedStoredHash, OutOfMemory}!bool`. Behavior changes that
  ride along: SQLite now enforces foreign keys (test fixtures stay
  child-before-parent clean — no escape hatch added); aggregates on
  grouped queries error instead of lying (`GroupByNotSupported`); empty
  `Sum`/`Avg` answer `EmptyAggregate` (app already used `SumOrZero`).
  zent 0.79–0.83 ride-alongs are transparent to this app (we use
  `crud_helpers`, not `CrudService`; no grouped single-value aggregates;
  error switches are `else`-based) but fix real classes underneath us:
  PostgreSQL prepared-statement 42P05/0A000 after DDL, MySQL lost
  connections now classified `ConnectionFailed` + `dead` marking,
  `beginTx` no longer strands a transaction on OOM, `uuidv4` seeded from
  OS entropy + thread-safe, pool borrow bookkeeping races, comptime
  branch-quota hardening for mid-size graphs (our 12-group migration
  qualifies). Not hit (verified unused here): `ThreadSafeEventBus.subscribe`
  → `!void`, `Method.fromString` → optional, builder bind-then-build
  idiom, `CrudService.get` → `getOwned`.
- **Toolchain unified on the Zig 0.17.0 official release** (zon
  `minimum_zig_version`, CI tarball URL, Dockerfile `ARG ZIG_VERSION`)
  — the dev-snapshot pin (`0.17.0-dev.1970`) is gone. One std
  regression workaround: `std.Io.net.Stream.read` fails to compile on
  0.17.0 stable (ReadResult destructure); the SMTP read path uses raw
  `std.posix.read` (same fix as upstream zigmodu's 127th batch).

### Security

- **SSRF baseline for admin-configured outbound URLs** (new
  `src/http/url_guard.zig`, ported pattern): scheme allow-list
  (http/https), userinfo stripping (`http://x@127.0.0.1/` bypass),
  literal loopback/private-host rejection — no DNS resolution
  (documented limitation). Enforced at both AI provider endpoint write
  paths (`POST/PUT /ai/providers` → 400) and, defense-in-depth, before
  every server-side outbound call (`chat`, `checkProvider` → logged +
  502), so legacy rows or direct DB writes cannot bypass the API gate.
  Covered by 3 new unit tests (38 total).
- **AI admin route group now also runs `tokenVersionGuard`** — the
  user-facing AI group had it, the admin group silently didn't; a
  kicked-out admin's pre-revocation token stayed valid until expiry.
- **Production preflight is fail-closed** (zigmodu `Preflight`):
  prod-like mode (`ZENAIPA_ENV=production` **or** postgres driver)
  now refuses to start on placeholder/short JWT secrets (min 16 chars)
  or `ZENAIPA_CORS_ORIGINS=*`. Previously only the postgres case
  checked secret-explicitness.
- **Upload hardening**: the previously dead `sanitizeFilename` is now
  wired into the upload handler (stored/display names are basename +
  control-char/quote stripped; raw `X-File-Name` is no longer persisted
  verbatim), and `extensionOf` only accepts alphanumeric extensions —
  a crafted `x.png/../../etc` tail can no longer slip path components
  into the storage key.

### Fixed

- **Double-`join` panic on every graceful shutdown**: the server thread
  was joined explicitly after `server.stop()` *and* again by a `defer`
  — joining a joined pthread is ESRCH → `unreachable` → panic on every
  SIGTERM. Now a single join with an error-path-only safety net.
- **~1 silent allocator leak per login** (found by the new e2e
  shutdown-leak gate on its first run): `login` copied the password hash
  with the store's allocator but freed it with `ctx.allocator` — the
  request-side arena whose `free` is a no-op. Session teardown is now
  ownership-explicit via `UserService.freeSession` (token → security
  module's allocator, row → store's allocator); `login` frees the hash
  with its owner; the `/health/ready` probe frees list rows with the
  store. AI API no longer frees store-owned rows with `ctx.allocator`.
- **Task queue state machine made race-honest**: `markDone` and
  `markFailedOrRetry` now transition only rows still in `claimed`
  (conditional UPDATE), and `markDone` reports affected rows — a worker
  that stalled past the stale threshold can no longer overwrite the
  requeue/failed verdict written while it ran (dispatcher logs the
  rejection). `retryTask`/`cancelTask` return the real affected-row
  result instead of unconditional `true` (already-pending retry reads
  as "nothing to do", not fabricated success).
- **`mail.send` handler validates its payload**: malformed JSON /
  missing fields / wrong-typed values now fail the run (→ `last_error`
  + retry within budget) instead of silently counting as done;
  unchecked `.string` dereferences on wrong-typed fields could panic
  the dispatcher thread and stall the queue.
- **Purge/delete counts are real**: `purgeFinished`,
  `purgeExpiredPasswordTokens`, `purgeExpiredEmailVerifications`,
  `notify.purgeOlderThan` returned hardcoded 0; `notify.markRead`/
  `delete` returned unconditional `true`. API consumers and cron logs
  now see actual affected-row counts.
- **`register` no longer masks DB errors as 409**: an unreachable DB
  during signup answered "email already taken"; the pre-check and the
  race re-check now propagate storage failures as 500.
- **`system/info` version came from a hardcoded `"0.2.0"`** (project at
  0.2.3); it is injected from the build (`-Drelease=x.y.z`, default
  synced with CHANGELOG).
- **27 silent `catch {}` sites triaged**: cron purges, fire-and-forget
  mail/notify enqueues, token housekeeping, AI best-effort persistence,
  cache set, orphan-file cleanup — each now either logs with context or
  carries a comment justifying the swallow. Internal `@errorName`s no
  longer reach clients (3 leaks: SSE error events, chat 502, provider
  check 502 now answer generic messages and log the detail).

### Changed

- **SQL drivers linked on demand (`-Ddb=`)**: default
  `sqlite,postgres` (both are runtime-switchable via
  `ZENAIPA_DB_DRIVER`, so both must be linked); `mysql` — never used —
  is now opt-in (`-Ddb=sqlite,postgres,mysql`), skipping ~30 s / ~590 MB
  of translate-c per build. The choice is forwarded to both framework
  deps, which otherwise default to `all` and sneak unused drivers back
  in.
- **Server caps configured**: `max_connections` +
  `over_limit_response = .unavailable` (accept-flood now answers 503
  instead of exhausting fd/memory) and `request_timeout_ms` (default
  30 s) — new env `ZENAIPA_HTTP_MAX_CONNECTIONS` /
  `ZENAIPA_HTTP_REQUEST_TIMEOUT_MS`.
- **Cache service is now thread-safe**: zigmodu's `CacheManager` is
  documented single-threaded but connections arrive concurrently; all
  manager access is serialized through an `std.Io.Mutex` (`getOrSet`
  runs its loader outside the lock), and a failed cache set after a
  successful loader is logged instead of swallowed.
- **`resetPassword` is transactional**: password update + clearing all
  password-reset tokens commit atomically (`UserStore.
  resetPasswordAtomic`), closing the window where an old reset link
  could still be replayed against an already-changed password.
- **zent library diagnostics are visible**: `zent.runtime.log.setSink`
  forwards the driver's internal err/warn/info/debug (scan/migrate/
  pool) into `std.log`.
- **Dispatcher counters are exported**: `processed`/`failed` existed as
  atomics but were never rendered; `/metrics` now includes
  `zenaipa_task_processed_total` / `zenaipa_task_failed_total`.

### Added

- **Static gates as `zig build` steps**: `lint-size` (≤1800 lines/file,
  `scripts/check_file_size.sh`) and `lint-fmt` (`zig fmt --check`),
  both wired into CI.
- **E2E smoke + shutdown leak gate** (`scripts/run_e2e.sh`, CI job):
  real binary + fresh SQLite → probes → admin/login/system-info →
  SIGTERM → assert exit ≤20 s, no panic, no SafeAllocator leak report.
  This gate caught the login leak listed above on its first run.
- **Dockerfile rewritten self-contained**: builds deps from the zon
  pins in-container (no sibling checkouts), Zig 0.17.0 official via
  TARGETARCH-mapped tarball, BuildKit cache mounts, ReleaseSafe +
  stripped binaries, non-root user, `/data` volume, `HEALTHCHECK` on
  `/health/live`. The previous file cloned `zig_ws/*` siblings and
  pinned a stale dev snapshot — it could not build the current tree.

## [0.2.3] - 2026-09-17

### Security

- **`file` upload now sniffs bytes via zigmodu `UploadGuard` (v0.15.46)**
  instead of checking only the extension: active content (SVG/HTML —
  stored-XSS vectors) is rejected even when renamed to `.txt`, alongside
  the existing extension allowlist and size cap. `require_extension_match`
  stays off because this is a general file store (docx/xlsx sniff as zip
  containers, tar/mov have no magic number). Also fixes
  `FileTypeNotAllowed` being misreported as HTTP 500 — now 400 with a
  message. New service-level test covers rename-bypass rejection, svg,
  php-extension, size cap, and happy-path png/md round-trip (35 backend
  tests total).

### Changed

- **Adopted zigmodu `bindJsonLoose` across all 16 JSON write endpoints**
  (auth/user/tenant/ai/mail_template): camelCase↔snake_case fields and
  `"field": null` no longer fail binding or wipe declared defaults;
  required-field empty strings are caught by existing service validations.
- **`mail_template` upsert** replaced the "exists → insert/update" two-step
  with a single-statement business-key upsert (zent
  `SaveOrUpdateOnWith` on `code`; explicit SET exprs preserve row id +
  `created_at` and route SQLite through ON CONFLICT DO UPDATE instead of
  INSERT OR REPLACE) — idempotent under races.
- **`task.requeueStale`** requeues stale claims with one
  `UPDATE ... WHERE id IN (...)` via `zent.sql.In` instead of a per-row
  loop; over-budget tasks still go through `markFailedOrRetry`
  individually. Direct `countByStatus` assertions added.
- **`ai.quotaForUser`** switched from `Sum` to `SumOrZero`: empty quota
  windows (user with no runs) previously propagated
  `error.TypeMismatch` from SQL NULL; now COALESCEs to 0 (covered by a
  new empty-window assertion).
- Schema graphs merged into a single `buildGraph` in `src/schema.zig`
  (previously split 3-way against old comptime-quota guidance) —
  cross-graph edges are possible again.
- Dependencies now pinned by git tag + content hash (`git+https` URL in
  `build.zig.zon`) instead of local sibling paths — `zig build` fetches
  from GitHub; CI no longer clones/recreates the `zig_ws` layout.

### Dependencies

- **zent v0.29.7 → v0.67.0 + zigmodu v0.15.22 → v0.20.1**, upgraded in
  three rounds (v0.32.1/v0.15.32 → v0.34.0/v0.15.36 → v0.67.0/v0.20.1),
  each pinned by git tag + content hash. Stability wins adopted
  automatically: zent connection-pool use-after-free fix, SQLite
  cross-thread connection serialization, zigmodu accept-loop keep-alive
  hang fix. Behavior changes that ride along at v0.67/v0.20:
  `migrateSchema` takes an advisory lock by default (10 s; multi-instance
  migrations serialise), `crud.update`/`increment` report rows *matched*
  on every dialect (idempotent updates no longer read as "missing" on
  MySQL), `cursorPage` rejects non-integer cursor columns, and
  `ctx.route_template` metrics labels are normalised with a leading
  slash.
- **Tooling pitfall found and documented**: with the vendored `zig-pkg/`
  layout, `zig fetch --save` updates `build.zig.zon` but a stale
  `.zig-cache` module graph keeps compiling the *old* dependency —
  silently green. Fix: clean `.zig-cache` / verify the
  `-M<dep>=zig-pkg/<version>-…` path (guide §5.5 + §7).
- Not adopted (evaluated): zent v0.33 Create/BulkInsert interceptors for
  tenant injection (guide §4 keeps hand-written predicates; separate
  assessment needed); zigmodu custom 404 handler (this project's
  `{code,msg,data}` envelope already matches the framework default);
  zent `AggregateBy` for grouped stats — **blocked by an upstream SQLite
  bug** (TEXT group keys coerce to `.int = 0` via `readAggValue`'s
  getInt-first path; PostgreSQL unaffected; re-verified unfixed in
  v0.67.0); growth-table `cursorPage` conversion (breaking change to the
  page-based HTTP contract + frontend; deferred, guide §5.4); MySQL
  VARCHAR(255) string columns (PG/SQLite only); RFC 7807 error bodies
  (opt-in, not enabled); zigmodu v0.16–v0.20 runtime additions (worker
  supervision / SagaOrchestrator / ClusterView — overlap with the
  built-in task queue).

### Fixed

- **CI resurrected** (red since late August for infrastructure reasons,
  not code): `mlugg/setup-zig@v1` builds old-pattern URLs that 404 for
  current dev builds and `0.17.0-dev.1567` had been garbage-collected
  from every mirror — replaced with a direct ziglang.org tarball
  download pinned to `0.17.0-dev.1970+67f39b551` (the toolchain this
  release was built and tested with). Frontend: `web/package-lock.json`
  was never committed (and an unanchored `package-lock.json` gitignore
  pattern was hiding it), breaking `npm ci` + the setup-node cache —
  anchored the pattern and committed the real lockfile.

### Docs

- `docs/development-guide.md`: new-capability inventories per round
  (§3.6), Sum-on-empty-set trap (§3.5), batch/IN pattern landed (§5.2),
  cursorPage deferral decision (§5.4), zig-pkg stale-graph trap (§5.5),
  quick-reference rows for `SumOrZero` / `AggregateBy` TEXT keys /
  stale-dependency compilation (§7). README badges/roadmap + zh-CN
  synced to the new baselines.

## [0.2.2] - 2026-08-11

### Fixed

- **Security**: `bumpTokenVersion` is now a single atomic
  `token_version = token_version + 1` UPDATE (no read-modify-write race);
  `changePassword` propagates `TokenInvalidationFailed` instead of silently
  swallowing it
- **Security**: `claimNext` checks affected rows — concurrent workers no
  longer execute the same task twice
- **Security**: `deleteSession` wrapped in a transaction with an owner check
  (fixes a pre-existing authorization bypass where a non-owner could wipe
  another user's session messages)
- **Security**: public registration is pinned to the default tenant
  (`X-Tenant-ID` header no longer selects a target tenant)
- **Security/leak**: JWT guard now reads only the `token_version` column
  (column projection) and drops the per-request arena free of gpa-owned rows
- **Performance**: Task table gains a `status + available_at` index
  (claimNext / listTasks hot path)

### Changed

- Persistence layer refactored onto `zent.crud_helpers`
  (`get/first/count/exists/latest/paginatedWithOptions`) — 7 modules, ~65
  lines of hand-rolled Query lifecycles removed
- zent v0.29.7 dynamic `[]sql.Predicate` Where support adopted: all
  optional-predicate lists (user/task/notify/file/audit/ai) now use
  `paginatedWithOptions` with sort whitelists
- Added `docs/development-guide.md` — secondary-development best practices
  (module skeleton, zent conventions, transactions, security, performance,
  testing pitfalls)

### Dependencies

- zigmodu v0.15.22+ (sqlx Threaded-Io, HttpMetrics/AccessLogger thread-safety)
- zent v0.29.7 (dynamic Where slices, crud_helpers: latest/paginatedWithOptions/
  increment, Sum → f64, comptime quota fix)

## [0.2.1] - 2026-08-10

### Fixed

- zent v0.29.4 `QueryBuilder.Sum` now returns `f64` (numeric SUM parsed via
  text representation); `quotaForUser` converted with `@intFromFloat` and
  covered by a quota-aggregation test (was a dormant `@intCast(f64)` compile
  error on an unreferenced path)

### Dependencies

- zigmodu v0.15.22 (sqlx Threaded-Io + HttpMetrics/AccessLogger thread-safety
  fixes, no API change)
- zent v0.29.4 (Sum → f64, Rows pool UAF fix, From-edge FK dedup)

## [0.2.0] - 2026-08-07

First tagged release — the full-stack admin framework with an agentic AI
assistant, streaming chat, governance and security hardening.

### Added

- **Full-stack admin framework** — task dispatcher (durable queue + mail.send),
  email templates + verification, files, notifications, cache, admin CLI
  (`zenaipa-admin create-admin`)
- **Multi-tenant isolation** — Tenant entity, JWT `aud` binding, row-level
  scoping
- **Audit & ops** — audit log with CSV export & retention, dashboard stats,
  email templates, per-IP login rate limiting, graceful shutdown
- **Agentic AI assistant** — admin-managed providers (AES-256-GCM encrypted
  keys), platform skills (user/task/audit/tenant search + `notify.send`),
  human approval queue for write actions, workflow orchestration, rolling 24h
  quota, 4-way concurrency bulkhead, provider health check
- **Streaming chat** — `chatStream` + `on_delta` (zigmodu v0.15.16); SSE
  reasoning/delta/done feed with typing effect and JSON fallback
- **Run usage audit** — per-run tokens/steps/tool-call snapshot via
  `AgentMetrics.toStats()` (zigmodu v0.15.17); actual model recorded
- **Resilience** — circuit breaker on provider calls (5-failure → 60s OPEN +
  half-open probe), fail-closed JWT, session revocation (JWT credential
  version)
- **Hardening** — file allow-list, error redaction, metrics IP ACL, audit
  retention, Docker, CI (backend + frontend), frontend tests + theme,
  toast notifications, DataTable skeleton loading, backup playbook

### Fixed

- Streaming tool schemas rejected by DeepSeek/OpenAI (HTTP 400 →
  `ProviderError`): upstream zigmodu v0.15.18 `tools_json` brace fix; zenaipa
  consumes it via `SkillRegistry`
- zent `migrate.zig` comptime branch-quota overflow on 15+ table schemas
  (upstream `10ab9ce`); schemas now compile on zent v0.29.2+

### Dependencies

- zigmodu v0.15.21 (HTTP, security, AI, resilience, Application lifecycle)
- zent v0.29.3 (ORM, schema-as-code, migrations)
