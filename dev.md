# zenaipa 开发笔记

项目名：zenaipa

- 后端：zigmodu 最佳实践（依赖经 `build.zig.zon` 以 git tag + hash 锁定：
  zigmodu v0.15.36 / zent v0.34.0；本地联调上游改动时临时切回
  `.path = "../../zig_ws/<repo>"`），数据库采用 zent，以
  PostgreSQL 为主、SQLite 兜底
- 前端：Solid 技术栈（参考 `~/w4_proj/dev_machine/saas_admin_ui/zadmin-solid`）
