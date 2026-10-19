# zenaipa 开发笔记

项目名：zenaipa

- 后端：zigmodu 最佳实践（依赖经 `build.zig.zon` 以 git tag + hash 锁定：
  zigmodu v0.39.18 / zent v0.96.0，Zig 0.17.0 正式版；本地联调上游改动时临时切回
  `.path = "../../zig_ws/<repo>"`），数据库采用 zent，以
  PostgreSQL 为主、SQLite 兜底
- 前端：Solid 技术栈（参考 `~/w4_proj/dev_machine/saas_admin_ui/zadmin-solid`）

## 常用命令

```sh
zig build test          # 单元测试（内存 SQLite）
zig build lint-size     # 行数门禁（≤1800 行/文件）
zig build lint-fmt      # zig fmt --check
scripts/run_e2e.sh      # 真实进程冒烟 + 关机 panic/泄漏门禁（先 zig build）
zig build -Ddb=sqlite,postgres,mysql   # 需要 MySQL 驱动时（默认不含 mysql）
```

- **换依赖 pin 后必须 `rm -rf .zig-cache`**：陈旧的模块图会继续编译旧版依赖，
  测试全绿也是假的（CHANGELOG 0.2.3 记录过这个坑）。

## 生产形态启动预检（fail-closed）

`ZENAIPA_ENV=production` 或 `ZENAIPA_DB_DRIVER=postgres` 时，启动即拒绝：

- `ZENAIPA_JWT_SECRET` 未显式设置 / 长度 <16 / 占位符（如 `dev-secret-change-me`）；
- `ZENAIPA_CORS_ORIGINS=*`（必须显式白名单）。

## 版本号

`/api/v1/system/info` 的 `version` 来自构建注入（`build.zig` 里 `-Drelease=`，
默认值与 CHANGELOG 同步手动 bump）。
