# zenaipa × Zig 0.17.0 正式版 + 依赖升级 + zweq 最佳实践对齐 — 设计

日期：2026-10-05
参考：`/Users/n0x/w4_proj/zigmodu_ws/zweq`（zigmodu v0.39.6 + zent v0.78.0 已落地）
基线：zenaipa @ b876e12（v0.2.3，zent v0.67.0 + zigmodu v0.20.1）

## 背景与目标

Zig 0.17.0 正式版发布，zigmodu 升级至 v0.39.6（zent 至 v0.78.0）。参照 zweq 项目的优化批次，把 zenaipa 对齐到同一工具链与工程实践水平。范围限定在**通用工程优化**；zweq 中 wechat/支付/电商域的代码不移植，只移植模式。

## 依赖差异结论（探索报告要点）

**编译破坏（必须修）：**
- `http_middleware.cors(...)` 等中间件工厂 → `!Middleware`（main.zig:282 需加 `try`）
- zent `CrudService.get` → `getOwned`（zenaipa 用的是 `crud_helpers.get`，签名未变，**不受影响**）
- 新错误集成员（`GroupByNotSupported`/`EmptyAggregate`/`MissingPrimaryKey`/`InconsistentRowFields`/`RowsAffectedUnknown`）— zenaipa 均为 `else` 分支，安全
- `ThreadSafeEventBus.subscribe → !void`、`Method.fromString → ?Method`、builder 绑定习语 — zenaipa 未使用，**不适用**

**行为变化（必须验证）：**
- SQLite 默认强制外键 → 测试清理顺序需"先子后父"；孤儿插入将报 `ForeignKeyViolation`
- `Sum/Avg` 空集 → `EmptyAggregate`（zenaipa 用的是 `SumOrZero`，安全）
- 聚合遇 GroupBy → 报错（zenaipa 无分组聚合，安全）
- 连接池借用失败错误归因变化（`PingFailed`/`ConnectionFailed`）

**新能力（择优采用）：**
- zent 0.76+ 按驱动编译选项（`.{ .sqlite=, .pg=, .mysql= }`，省 ~26s/~590MB/驱动）
- zent `AllOwned()` / `deinitRowWith(alloc, &e)` — 所有权显式化
- `zent.runtime.log.setSink` — 库诊断接入应用日志
- zigmodu `-Ddb=` 构建选项（转发 app 的驱动选择）
- `zigmodu.Preflight`（生产预检）、`PanicHook`、`Context.setDeadline/sqlContext`
- `initWithConfig` 新字段：`max_connections`/`over_limit_response`/`request_timeout_ms`

## 方案选择

考虑过三条路线：
1. **仅 bump 依赖 + 修编译**（最小）— 丢掉 zweq 两波最佳实践的价值，不满足"完善"诉求。
2. **全量照搬 zweq 基建**（url_guard + rate_limit 全家桶 + metrics 直方图 + request budget + wire + 四道门禁 + e2e）— 一半条目对纯管理后台无收益（per-openid 限流、webhook transport、license、cron 分布式锁），引入大量无主代码。
3. **定向移植（选定）**：依赖升级 + 编译修复之外，从 zweq 清单挑出对管理后台有实际收益的通用项，按批次落地；明确记录"跳过项与理由"。

## 批次设计

### Batch 1 — 依赖升级 + 编译修复
- `build.zig.zon`：zent v0.78.0（`fe04124a…`）、zigmodu v0.39.6（`df6259ac…`），hash 照抄 zweq；`.paths` 修正 `"frontend"` → `"web"`
- 修 `cors(...)` `try`；清 `.zig-cache`（换 pin 后缓存会骗人）；`zig build` / `zig build test` 迭代至全绿
- 测试重点：SQLite 外键强制后的清理顺序、聚合错误路径

### Batch 2 — 构建系统
- `build.zig`：新增 `-Ddb=` 选项 → `db_link.parseDb` → 转发给 zent（`.{.sqlite=,.pg=,.mysql=}`）与 zigmodu（`.db=`）；三个 module（exe/admin/tests）统一走该 features
- CI：zig 直接 tarball `0.17.0-dev.1970` → 官方 `0.17.0`

### Batch 3 — 错误处理治理
- 3 处 `@errorName` 泄漏给客户端（ai/api.zig:445/463/539）→ 通用中文消息 + `std.log` 留内部细节
- 27 处静默 `catch {}` 逐一分诊：清理/回滚/尽力而为类加注释，其余补 `log.err/warn` 上下文（保持 best-effort 控制流）
- `purgeFinished/purgeOlderThan/purgeExpired*` 硬编码返回 0 → 返回真实 `Exec()` 计数
- `retryTask/cancelTask` 无条件 true → 条件 UPDATE（`WHERE status=...`）+ affected 语义（0 → 幂等结果而非错误）
- `notify markRead/delete` 返回真实 affected
- `mailSend` handler 载荷解析失败静默吞 → 返回错误（走 markFailedOrRetry 重试语义）
- `register` 邮箱冲突：`getUserByEmail catch return error.EmailTaken` 掩盖 DB 错误 → 精化错误映射

### Batch 4 — 并发与一致性
- task `markDone` 加 fencing：`WHERE id=? AND claim_owner=?`，0 行 → warn 留痕（防停摆 worker 覆写）
- `resetPassword`（改密 + 删令牌两条写）→ `beginTx` 事务包裹（复用 ai/persistence 的 tx 模式）
- 行内存释放统一为**所有者分配器**（store.allocator），ai/api 用 ctx.allocator 释放 store 行的不一致点修正；顺手采用 `AllOwned()`/`deinitRowWith` 低风险处

### Batch 5 — 安全
- 移植 `src/http/url_guard.zig`（scheme 白名单、去 userinfo、字面量私网/环回拒绝）→ AI provider endpoint 写入路径 + 服务端外呼前双重校验（zenaipa 唯一 SSRF 面）
- AI admin 路由组补挂 `tokenVersionGuard`（用户组已挂，管理组漏了）
- `zigmodu.Preflight` 生产预检：prod-like（postgres 或 `ZENAIPA_ENV=production`）时 JWT secret 长度 + CORS 非 `*` fail-closed
- 上传：接入闲置的 `sanitizeFilename`（存储名净化）；`extensionOf` 产出含 `/` 的扩展名 → 扩展名字符集校验

### Batch 6 — 可观测性与生命周期
- `/metrics`：渲染 dispatcher `processed/failed` 原子计数（已存在但从未导出）
- `system/info` 硬编码 `version = "0.2.0"` → `b.addOptions` 注入构建期版本
- `initWithConfig` 补 `max_connections`/`over_limit_response=.unavailable`/`request_timeout_ms`（config 新增对应项，默认合理值）
- 关机路径审计：确认单次 join、释放顺序（探索显示基本健康，修发现的问题即可）
- `zent.runtime.log.setSink` 接入 `std.log`（库级诊断可见）

### Batch 7 — 容器与门禁
- Dockerfile 重写：现版引用兄弟目录 clone 与 0.17.0-dev.1567（已失效）→ 多阶段（node:22-alpine 构建 SPA → zig 官方 0.17.0 tarball 构建 ReleaseSafe → alpine 运行时仅 ca-certificates/sqlite-libs/libpq），非 root 用户、HEALTHCHECK 打 `/api/v1/health/live`
- `zig build lint-size`（≤1800 行/文件门禁）+ `scripts/check_file_size.sh`
- `scripts/run_e2e.sh` 最小版：全新 SQLite 启动 → health/login 冒烟 → SIGTERM → 断言 20s 内退出且日志无 panic/leak（关机泄漏门禁）
- CI 补门禁 job（lint-size、e2e 可选）；gitleaks/npm audit 视时间取舍

### Batch 8 — 文档与验证
- `CHANGELOG.md`：Unreleased 段，含依赖适配说明（0.78/0.39.6 对我们的实际影响点）与优化批次
- 验证：`zig fmt --check`、`zig build test`、ReleaseSafe 构建、`run_e2e.sh` 全过；前端不动（`tsc --noEmit` 冒烟确认无影响）

## 明确跳过（理由记录）

| zweq 项 | 理由 |
|---|---|
| per-openid 限流维度 / fan 经济规则表 | 无 C 端；保留现有 auth 路由 IP 限流 |
| DB-lease cron 分布式锁 | 单进程 + SQLite 单连接架构，无多副本 |
| request budget 深度打通 DB deadline | 管理后台查询短平快；`request_timeout_ms` 已覆盖服务器侧 |
| metrics ns 直方图全家桶 | 先验证 0.39.6 采集器是否仍按秒截断，未截断则不移植 |
| panic hook / request-id 中间件 | tracingMiddleware + AccessLogger 已覆盖主要诉求；PanicHook 列为可选 |
| JWT kid 轮换环 | 已有 token_version 撤销机制；列为后续可选 |
| wire.zig 提取 | main.zig 仅 414 行，不值得 |
| lint-alloc / lint-deps 静态门禁 | 单一 gpa 设计 + 模块未声明 `.dependencies` 元数据，前提不成立 |
| webhook transport / license / zwechat | 域专属 |

## 风险

- zent 0.78 外键强制可能暴露既有测试/数据顺序问题 → 逐个修清理顺序，不出 `enforce_foreign_keys=false` 逃生门
- 新错误集成员进入 switch → 全部用 `else` 兜底，编译期暴露处再精化
- pin 更换后必须 `rm -rf .zig-cache`（zweq CLAUDE.md 的教训）
