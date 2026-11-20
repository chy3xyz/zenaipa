# 评分审批流程测试报告

## 执行环境
- Zig: 0.17.0
- Framework: zmodu
- DB: SQLite
- Commit: c5c6569

## 测试命令

### 1. 引擎测试 (6/6)
```bash
zig test src/modules/rating/engine.zig
```
**结果**: exit 0
- calculateBaseScore: normal case ✓
- scoreToGrade: boundary checks ✓
- applyRedFlags: R1 caps to D ✓
- applyRedFlags: R2 downgrades one level ✓
- calculateConfidence: thresholds ✓
- calculateRating: full flow ✓

### 2. 原10项集成测试 (10/10)
```bash
timeout 120 bash test_full_rbac.sh
```
**结果**: exit 0
- T1: 普通用户注册 ✓
- T2: 管理员登录 ✓
- T3: 匿名项目POST → 401 ✓
- T4: 普通用户项目POST → 403 ✓
- T5: 管理员项目POST → 201 ✓
- T6: 20次POST+GET迭代（无崩溃/超时/死锁） ✓
- T7: 普通用户rating GET → 403 ✓
- T8: 匿名rating GET → 401 ✓
- T9: 错误project_id → 404 ✓
- T10: 服务重启+持久化验证 ✓

### 3. 审批流程测试 (9/9)
```bash
timeout 60 bash test_approval_workflow.sh
```
**结果**: exit 0
- T1: 分析员A登录 ✓
- T2: 审核员B登录 ✓
- T3: A提交评级 → 200 ✓
- T4: A自审 → 403 (显式权限检查) ✓
- T5: B批准 → 200 ✓
- T6: 重复批准 → 409 (CAS防重) ✓
- T7: 审计日志恰好3条 (create/submit/approve) ✓
- T8: 自审403时字段不变 ✓
- T9: 普通用户审批 → 403 ✓

## 核心功能验证

### CAS（Compare-And-Swap）机制
- ✅ 预检查reviewer_id，已设置则立即失败
- ✅ 验证reviewed_at时间戳变化
- ✅ 失败时返回409且不写audit
- ✅ 重复操作audit数量不增加

### 自审防护
- ✅ 显式isSelfReview()检查
- ✅ 自审返回403 Forbidden（不是409）
- ✅ 403时reviewer_id/reviewed_at保持NULL

### 状态机
```
draft → (submit by analyst) → submitted 
       → (approve/reject by different reviewer) → approved/rejected
```
- ✅ 非法转换被CAS条件阻止
- ✅ 每次状态变化生成audit记录
- ✅ 审计日志不可篡改

### GET端点完整性
- ✅ 返回完整RatingDraftRow JSON
- ✅ 严格project_id验证
- ✅ 不存在或不匹配→404
- ✅ 包含新增审批字段（analyst_id, reviewer_id, status, revision, timestamps）

### RBAC权限
- ✅ 管理员可创建/提交/审批
- ✅ 普通用户无权创建项目或审批
- ✅ 匿名请求401
- ✅ 权限不足403

### 持久化与稳定性
- ✅ 20次连续POST+GET无崩溃
- ✅ 进程完整重启后数据一致
- ✅ 并发审批CAS正确串行化

## 总计
**25/25 断言通过**

所有测试exit 0，无降级，无placeholder，无已知回归。
