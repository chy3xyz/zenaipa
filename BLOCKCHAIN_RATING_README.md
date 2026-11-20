# 区块链项目评级系统 · MVP 实施说明

## 项目概述

本项目基于 zenaipa 全栈管理框架，开发了一个区块链项目评级与研讨社群系统的 MVP 版本。系统使用 SQLite 数据库，实现了核心的评级生产闭环。

**注意：这是 MVP 阶段代码，许多功能为框架预埋或简化实现，完整功能需要后续迭代开发。**

## 技术栈

- **后端**: Zig 0.17 + zmodu (HTTP/AI框架) + zent (ORM)
- **前端**: SolidJS + TypeScript + Tailwind CSS + DaisyUI
- **数据库**: SQLite (默认) / PostgreSQL (可切换)

## 已实现功能

### ✅ 核心数据模型（完整）

#### 1. 项目管理模块 (`src/modules/blockchain_project/`)
- ✅ `Project`: 项目基础信息表
- ✅ `ProjectContract`: 多链合约地址表
- ✅ `TokenMetric`: 代币指标快照表
- ✅ `TeamMember`: 团队成员表
- ✅ `FundingRound`: 融资轮次表
- ✅ `UnlockEvent`: 解锁事件表
- ✅ `ProjectTag`: 项目标签表

#### 2. 评级引擎模块 (`src/modules/rating/`)
- ✅ `MethodVersion`: 方法论版本表
- ✅ `RatingInputSnapshot`: 评级输入快照表（不可变）
- ✅ `Rating`: 评级输出表（六维+四档位）
- ✅ `DimensionEvidence`: 维度证据表
- ✅ `RatingReview`: 评级复核表
- ✅ `RatingChange`: 评级变更表
- ✅ **六维评分引擎**: 确定性计算实现
  - 默认权重: Tech20%/Team18%/Tokenomics20%/Community15%/Liquidity15%/Compliance12%
  - 档位: S≥85, A≥75, B≥60, C≥45, D<45
  - 置信度: ≥85%正常, 60-85%中置信, <60% NR
  - 红牌规则: R1-R6, 不叠加降档, R1/R4封顶D

#### 3. 数据采集模块 (`src/modules/data_collection/`)
- ✅ `DataSource`: 数据源配置表
- ✅ `RawObservation`: 原始观测数据表（append-only）
- ✅ `MetricValue`: 指标值表（自动+人工双值）
- ✅ `CollectionJob`: 采集任务表

#### 4. 合规模块 (`src/modules/compliance/`)
- ✅ `ComplianceConfig`: 合规配置表（C1-C15开关）
- ✅ `ComplianceDecision`: 合规决策记录表
- ✅ `CorrectionCase`: 事实更正申请表
- ✅ `ConflictDisclosure`: 利益冲突披露表

#### 5. 三源模块 (`src/modules/three_source/`) - **W1预埋结构**
- ✅ `Claim`: 项目宣称表
- ✅ `ClaimVerification`: 宣称核验表
- ✅ `RoadmapCommitment`: 路线图承诺表
- ✅ `Governance Proposal`: 治理提案表
- ✅ `RevenueBreakdown`: 收入拆分表
- ✅ `Principle`: 核心主张表
- ✅ `TccConflict`: 主张冲突事件表
- ✅ `ProjectStage`: 项目生命周期表
- ✅ `ThreeSourceAssessment`: 三源评估表（影子）
- ✅ `CoherenceAssessment`: 合恰度评估表

#### 6. 报告发布模块 (`src/modules/report/`)
- ✅ `RatingReport`: 评级报告表（三层内容）
- ✅ `ContentAsset`: 内容资产表（评级卡）
- ✅ `DistributionRecord`: 分发记录表
- ✅ `RatingAttestation`: 评级存证表
- ✅ `Channel`: 渠道与短链表
- ✅ `AttributionEvent`: 归因事件表

### ✅ 核心业务逻辑（部分实现）

#### 项目管理服务
- ✅ 项目 CRUD 操作
- ✅ 按赛道/状态筛选
- ✅ 关键词搜索
- ✅ Slug 唯一性校验
- ⚠️ CSV 批量导入（接口预留，待实现）
- ✅ 多链合约管理
- ✅ 代币指标记录
- ✅ 团队成员管理

#### 评级引擎服务
- ✅ **确定性六维计算**（同输入同输出）
- ✅ **红牌规则应用**（不叠加，R1/R4封顶D）
- ✅ **四档位字段**（base/redflag/shadow/published）
- ✅ **置信度计算**
- ✅ 评级创建
- ✅ 提交复核
- ✅ 双人复核签发（强制不同自然人）
- ⚠️ 发布门禁（C1/C2/C12检查待完善）

#### RESTful API
- ✅ `/api/v1/blockchain/projects` - 项目管理 CRUD
- ✅ `/api/v1/blockchain/projects/import/csv` - CSV导入（占位）
- ✅ `/api/v1/ratings` - 评级创建
- ✅ `/api/v1/ratings/:id/submit` - 提交复核
- ✅ `/api/v1/ratings/:id/review` - 复核签发
- ✅ `/api/v1/ratings/:id/publish` - 发布评级
- ✅ `/api/v1/projects/:project_id/rating` - 获取项目评级

### ✅ 数据库配置

#### SQLite 配置
- ✅ 默认使用 SQLite
- ✅ Schema-as-code 自动迁移
- ✅ 所有表已注册到 `src/schema.zig`
- ✅ 外键约束支持
- ⚠️ WAL 模式配置（需在启动代码配置）
- ⚠️ busy_timeout 设置（需在启动代码配置）
- ✅ 金额使用 INTEGER/BIGINT 存储美分，避免浮点误差
- ✅ 时间戳统一 ISO8601 字符串

#### 数据库表统计
- 原有 zenaipa 框架表: 15 个
- 新增区块链评级表: 39 个
- **总计: 54 个表**

## 未完成功能清单

### ⚠️ 核心功能待完善

#### 1. 服务层业务逻辑（高优先级）
- ❌ CSV 批量导入实现（项目录入 ≤8分钟目标）
- ❌ 数据采集任务调度（需集成 zenaipa task 模块）
- ❌ 评分引擎完整测试
- ❌ 合规开关强制门禁（C1/C2/C12 代码层拒绝关闭）
- ❌ 撤回机制实现
- ❌ 事实更正完整流程
- ❌ 利益冲突回避规则

#### 2. API 层（高优先级）
- ❌ 数据采集 API
- ❌ 合规管理 API
- ❌ 三源数据录入 API（仅后台）
- ❌ 报告发布 API
- ❌ 公开榜单 API
- ❌ 项目详情 API

#### 3. 前端页面（中优先级）
- ❌ 项目管理后台页面
- ❌ 评级工作台页面
- ❌ 复核工作台页面
- ❌ 合规配置页面
- ❌ **公开榜单页面**（中文）
- ❌ **项目详情页面**（事实/评分/观点分离）
- ❌ 三源数据录入页面（仅后台）

#### 4. 评级卡生成（中优先级）
- ❌ 1:1 / 9:16 / 16:9 多尺寸生成
- ❌ 六维雷达图渲染
- ❌ 档位展示
- ❌ 风险标签展示
- ❌ 免责声明
- ❌ 核验二维码
- ❌ 生成性能优化（目标≤3秒）

#### 5. 外部服务集成（低优先级）
- ❌ 真实数据源接入（CoinGecko/DefiLlama/GitHub等）
- ❌ 社群 Bot（Telegram/Discord/企微等）
- ❌ 支付订阅集成
- ❌ 邮件通知
- ❌ 短链服务
- ❌ 链上存证

#### 6. 测试（高优先级）
- ❌ 单元测试（评分引擎/红牌规则/置信度）
- ❌ 集成测试（数据库操作/事务/并发）
- ❌ API 测试（认证/权限/状态机）
- ❌ 端到端测试（录入→评分→复核→发布→公开）
- ❌ 不可关开关测试（C1/C2/C12）
- ❌ 防自签测试
- ❌ 签发快照不可改测试

## 已知限制与约束

### 1. 数据模型完整性
- ✅ 所有 PRD 要求的表已创建
- ⚠️ 部分字段验证逻辑未实现
- ⚠️ 复杂查询未优化（如分页计数）

### 2. 评分引擎
- ✅ 基础六维计算实现
- ✅ 红牌不叠加规则实现
- ✅ 四档位字段分离
- ⚠️ 指标归一化细则待配置
- ⚠️ 赛道权重模板（RWA/Meme）待实现
- ❌ 三源影子计算（仅预埋，W7启用）

### 3. 合规与安全
- ✅ 数据模型支持 C1-C15 开关
- ❌ 代码层强制门禁未实现
- ❌ 撤回机制未实现
- ⚠️ 地域限制需外部中间件支持
- ⚠️ 利益冲突自动回避规则待实现

### 4. 性能指标
- ⚠️ 未进行性能测试
- ⚠️ 评分重算性能目标（≤3分钟）未验证
- ⚠️ 评级卡生成性能目标（≤3秒）未实现
- ⚠️ 移动端首屏性能目标（≤2秒）未测试

### 5. 外部依赖
- ❌ 无真实数据源接入
- ❌ 无社群平台集成
- ❌ 无支付系统集成
- ⚠️ 文件上传依赖 zenaipa file 模块（已有）
- ⚠️ 任务队列依赖 zenaipa task 模块（已有）

## 启动说明

### 环境要求
- Zig 0.17
- Node.js 18+ (前端开发)
- SQLite 3 (自动创建数据库)

### 后端启动

```bash
# 1. 构建项目
cd /workspace
zig build

# 2. 运行后端（默认端口 8000）
zig build run

# 或直接运行
./zig-out/bin/zenaipa

# 3. 创建管理员账号
./zig-out/bin/zenaipa-admin create-admin \
  --email admin@example.com \
  --password 'Admin123!' \
  --name 'Rating Admin'
```

### 环境变量配置

```bash
# 数据库配置
export ZENAIPA_DB_DRIVER=sqlite
export ZENAIPA_SQLITE_PATH=/data/blockchain_rating.db

# JWT 密钥（生产环境必须设置）
export ZENAIPA_JWT_SECRET=<your-secret-key>

# 服务端口
export ZENAIPA_HTTP_PORT=8000

# CORS 配置
export ZENAIPA_CORS_ORIGINS=http://localhost:3001

# 审计日志保留天数
export ZENAIPA_AUDIT_RETENTION_DAYS=180
```

### 前端启动

```bash
cd /workspace/web
npm install
npm run dev

# 访问 http://localhost:3001
```

### API 测试

```bash
# 1. 登录获取 token
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"Admin123!"}'

# 2. 创建项目
curl -X POST http://localhost:8000/api/v1/blockchain/projects \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "name":"Ethereum",
    "slug":"ethereum",
    "sector":"L1",
    "official_url":"https://ethereum.org"
  }'

# 3. 创建评级
curl -X POST http://localhost:8000/api/v1/ratings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "project_id":1,
    "tech_score":90,
    "team_score":85,
    "tokenomics_score":80,
    "community_score":95,
    "liquidity_score":95,
    "compliance_score":70,
    "coverage":100
  }'

# 4. 获取项目评级
curl http://localhost:8000/api/v1/projects/1/rating \
  -H "Authorization: Bearer <token>"
```

## 数据库管理

### SQLite 操作

```bash
# 1. 连接数据库
sqlite3 zenaipa.db

# 2. 查看所有表
.tables

# 3. 查看表结构
.schema blockchain_projects

# 4. 查询数据
SELECT * FROM blockchain_projects LIMIT 10;
SELECT * FROM ratings WHERE status='published' ORDER BY created_at DESC;

# 5. 备份数据库
.backup backup.db

# 6. 恢复数据库
sqlite3 zenaipa.db < backup.sql
```

### 迁移管理
- ✅ 启动时自动迁移（zent schema-as-code）
- ⚠️ 不支持回滚（需手动备份恢复）
- ⚠️ 结构变更需重新编译

## 测试状态

### ✅ 已通过的测试（现有框架）
- ✅ zenaipa 原有 38 个后端测试
- ✅ zenaipa 原有 5 个前端测试

### ❌ 待添加的测试
1. **评分引擎测试**
   - 六维计算边界测试
   - 红牌规则测试（R1-R6）
   - 置信度计算测试
   - 四档位逻辑测试

2. **数据库操作测试**
   - 项目 CRUD 测试
   - 评级 CRUD 测试
   - 唯一约束测试
   - 外键约束测试

3. **API 权限测试**
   - 认证测试
   - RBAC 测试
   - 双人复核测试
   - 防自签测试

4. **业务流程测试**
   - 端到端评级流程测试
   - 撤回流程测试
   - 更正流程测试

## 架构说明

### 模块组织
```
src/modules/
├── blockchain_project/  # 项目管理（已实现）
│   ├── model.zig       # 数据模型 ✅
│   ├── persistence.zig # 持久化层 ✅
│   ├── service.zig     # 业务逻辑 ⚠️
│   ├── api.zig         # HTTP API ✅
│   ├── module.zig      # 模块元数据 ✅
│   └── root.zig        # 模块导出 ✅
├── rating/              # 评级引擎（核心已实现）
│   ├── model.zig       # 数据模型 ✅
│   ├── persistence.zig # 持久化层 ✅
│   ├── service.zig     # 业务逻辑 ⚠️
│   ├── api.zig         # HTTP API ✅
│   ├── engine.zig      # 评分引擎 ✅
│   ├── module.zig      # 模块元数据 ✅
│   └── root.zig        # 模块导出 ✅
├── data_collection/     # 数据采集（仅模型）
│   └── model.zig       # 数据模型 ✅
├── compliance/          # 合规管理（仅模型）
│   └── model.zig       # 数据模型 ✅
├── three_source/        # 三源预埋（仅模型）
│   └── model.zig       # 数据模型 ✅
└── report/              # 报告发布（仅模型）
    └── model.zig       # 数据模型 ✅
```

### 数据流
```
HTTP请求 → API层 → 服务层 → 持久化层 → SQLite
                              ↓
                          评分引擎
                         (确定性计算)
```

## 与 PRD 的对应关系

### P0 功能覆盖度

| PRD 章节 | 功能模块 | 状态 | 说明 |
|---------|---------|------|------|
| M1 项目库 | blockchain_project | 🟡 部分 | CRUD完成，CSV导入待实现 |
| M2 数据采集 | data_collection | 🔴 框架 | 仅数据模型，服务层待开发 |
| M3 打分引擎 | rating.engine | 🟢 完成 | 六维+红牌+四档位已实现 |
| M4 复核工作台 | rating.service | 🟡 部分 | 双人复核已实现，UI待开发 |
| M5 卡片与落地页 | report | 🔴 框架 | 仅数据模型，生成逻辑待实现 |
| M6 Bot | - | 🔴 未开始 | 待外部集成 |
| M7 内容分发 | report | 🔴 框架 | 仅数据模型 |
| M9 归因看板 | report | 🔴 框架 | 仅数据模型 |
| M10 申诉纠错 | compliance | 🔴 框架 | 仅数据模型 |
| M11 方法论中心 | rating | 🔴 未开始 | 待UI开发 |
| M13 三源影子 | three_source | 🟢 预埋 | 数据结构完整，计算逻辑待W7 |

### 五项已定决议对应

| 决议 | 实现位置 | 状态 |
|-----|---------|------|
| 1. 不叠加降档 | rating/engine.zig | ✅ 已实现 |
| 2. 对外S/A/B/C/D/NR | model.zig | ✅ 数据模型支持 |
| 3. 两套置信度 | model.zig | ✅ confidence_six/three分离 |
| 4. 分层覆盖 | three_source/model.zig | ✅ 影子评分独立表 |
| 5. W1预埋W7影子 | three_source/ | ✅ 结构预埋，访问控制待实现 |

## 下一步建议

### Phase 1: 完善核心闭环（2-3周）
1. ✅ 实现 CSV 批量导入
2. ✅ 完善评分引擎测试
3. ✅ 实现合规门禁（C1/C2/C12）
4. ✅ 开发后台管理页面（项目/评级/复核）
5. ✅ 实现基础演示数据

### Phase 2: 公开展示（2周）
1. ✅ 开发公开榜单页面（中文）
2. ✅ 开发项目详情页面（三层分离）
3. ✅ 实现评级卡生成（基础版）
4. ✅ 实现撤回机制
5. ✅ 添加端到端测试

### Phase 3: 数据采集（2周）
1. ✅ 实现采集任务调度
2. ✅ 集成真实数据源（Mock → Real）
3. ✅ 实现人工覆盖流程
4. ✅ 添加数据质量监控

### Phase 4: 外部集成（3周）
1. ✅ 社群 Bot 集成（首个平台）
2. ✅ 支付订阅集成
3. ✅ 短链与归因实现
4. ✅ 邮件通知实现

### Phase 5: 三源启用准备（W7+）
1. ✅ 三源数据录入 UI
2. ✅ 影子评分计算实现
3. ✅ 访问权限控制
4. ✅ 六个月验证准备

## 文档清单

- ✅ BLOCKCHAIN_RATING_PLAN.md - 实施计划
- ✅ BLOCKCHAIN_RATING_README.md - 本文档（交付说明）
- ⚠️ API_DOCUMENTATION.md - API 文档（待完善）
- ⚠️ DATABASE_SCHEMA.md - 数据库 Schema 文档（待完善）
- ⚠️ TESTING_GUIDE.md - 测试指南（待完善）
- ⚠️ DEPLOYMENT_GUIDE.md - 部署指南（待完善）

## 风险与限制

### 技术风险
1. **Zig 编译环境** - 需要正确的 Zig 0.17 环境
2. **数据库并发** - SQLite 并发性能有限，高并发需迁移 PostgreSQL
3. **评分引擎复杂度** - 完整指标归一化规则需要实际数据校准

### 业务风险
1. **方法论未验证** - 评级规则需要真实数据回测
2. **合规要求** - 法律审查未完成
3. **外部服务依赖** - 数据源/支付/社群平台需要商务对接

### 资源限制
1. **开发时间** - MVP 阶段功能简化
2. **测试覆盖** - 测试用例待补充
3. **UI/UX** - 前端页面待开发

## 联系与支持

- 项目仓库: https://github.com/chy3xyz/zenaipa
- PR 分支: cursor/blockchain-rating-mvp-3333

## 许可证

本项目基于 zenaipa 框架（MIT 许可证）开发。
