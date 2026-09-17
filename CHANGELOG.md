# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
