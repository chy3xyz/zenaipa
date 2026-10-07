# zenaipa web 控制台 × zweq UI 后台对齐 — 设计

日期：2026-10-06。基线：web/ 当前 HEAD（SolidJS 1.9 + router + axios + rsbuild + TW4/daisyUI + vitest）。
参考：`/Users/n0x/w4_proj/zigmodu_ws/zweq/web`（同血统、更成熟的实现）。只移植**通用模式**，wechat/公众号域（AccountSelector、Menu、RichEditor、营销页）不搬。

## 实测缺陷（本轮必须修）
- **`usePaged` 无自动加载**：6 个表格页挂载后不请求，初始一律"暂无数据"，必须手动点查询/翻页。
- **非 2xx 信封不解析**：拦截器只处理 401，400 的中文 `msg` 变成 axios 默认文案（zweq ec8969a 修的同款问题）。
- **AiAdmin 表单无提交态**：provider 保存、approve/reject 可双击重复提交；其 3 张手写表无分页/骨架。
- **3 种 modal 写法并存** + 7 处 `window.confirm` + 3 处 `window.alert`。

## 移植批次

### W1 数据层（client/envelope/hooks/域目录）
1. `client.ts`：响应拦截器解析非 2xx envelope → `ApiError`（服务端中文 msg 可见）；新增泛型 `get/post/put/deleteEnvelope<T>`；`toApiError` 移入（auth/query.ts 原处改为 re-export）。
2. `envelope.ts`：新增 `PageResult<T>`（list/total/page/pageSize），10 个域类型收敛复用。
3. `usePaged` 重写（zweq 形态）：**挂载自动加载**、`refresh()`、`changePageSize()`、`watch` 访问器（变化即回第 1 页）、保留单调 requestSeq 防乱序。

### W2 组件层（新 components + 既有升级）
4. `BaseModal` / `FormModal` / `FormField`：统一弹窗三层（chrome/表单/字段），消灭 3 种 modal 写法；约定：每弹窗独立 submitting/error、open 翻真重置、`if (submitting()) return` 防双击。
5. `ToastProvider` 升级为 `FeedbackProvider`：show(msg,type) + `confirm()`（Promise，danger 变体）+ `runAction({confirm, action, success, onDone})`，替换全部 `window.confirm/alert`。
6. `Pagination` 独立组件（页码窗口/页大小/跳页，zweq 形态），`DataTable` 内部集成 + 加载遮罩 + 空态文案；props 保持向后兼容。
7. `AdminCrudPage`（页头 + 动作行 + 筛选卡 + 内容卡）、`SearchBar`（草稿式，提交才生效）、`EmptyState`、`StatCard`（从 Dashboard/Tasks 的重复实现上提）。

### W3 壳/页面/清理/测试
8. 侧边栏改配置驱动（`constants/nav.ts`：href/label/adminOnly），消除 10 处重复类名串；深色模式默认跟 `prefers-color-scheme`（保留手动切换 + localStorage 持久化）。
9. 页面迁移：Users 为参照实现；Tenants/Tasks/Files/AuditLogs/MailTemplates/Dashboard/Profile/AiAdmin/AiChat 逐页采用 AdminCrudPage/SearchBar/FormModal/Feedback；MailTemplates 与 AiAdmin 的手写表换 DataTable；NotificationBell 的 window.alert → toast。
10. 清理：删除失联的 `pages/index.ts` barrel、过期 8600 端口注释、未用的 `PUBLIC_API_MODE`。
11. 测试（vitest + jsdom，沿用现配置）：envelope unwrap/ApiError、`usePaged` 自动加载 + 乱序守卫、FormModal 提交态。不引新依赖。

## 明确不做（记录理由）
- 后端驱动导航（zenaipa 无 module-nav API；用前端配置数组即可）
- 登录后回跳原路由（zweq 也没有，列为后续可选项）
- 表格排序/行选择、图标库、i18n、eslint/biome（zweq 均未做，避免超范围）
- 公众号域组件与页面（AccountSelector/RichEditor/Menu 等）
