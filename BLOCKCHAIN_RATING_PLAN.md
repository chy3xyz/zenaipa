# 区块链项目评级系统 - 实施计划

## 项目概述

基于 zenaipa 框架开发区块链项目评级与研讨社群系统，使用 SQLite 数据库。

## PRD 需求映射

### 核心实体（参考 PRD 第六章）

1. **项目管理模块** (projects)
   - projects: 项目基础信息
   - project_contracts: 多链合约地址
   - token_metrics: 代币指标快照
   - team_members: 团队成员
   - funding_rounds: 融资轮次
   - unlock_events: 解锁事件
   - project_tags: 项目标签

2. **数据采集模块** (data_collection)
   - data_sources: 数据源配置
   - raw_observations: 原始抓取数据
   - metric_values: 指标值（自动+人工覆盖）
   - collection_jobs: 采集任务

3. **评级引擎模块** (rating_engine)
   - method_versions: 方法论版本
   - rating_input_snapshots: 输入快照（不可变）
   - ratings: 评级输出（六维+四档位）
   - rating_reviews: 复核记录
   - rating_changes: 评级变更
   - dimension_evidence: 维度证据

4. **三源扩展模块** (three_source) - W1预埋，W7启用
   - claims: 项目宣称
   - claim_verifications: 宣称核验
   - roadmap_commitments: 路线图承诺
   - governance_proposals: 治理提案
   - revenue_breakdowns: 收入拆分
   - principles: 核心主张
   - tcc_conflicts: 主张冲突事件
   - three_source_assessments: 三源评估
   - coherence_assessments: 合恰度评估
   - project_stages: 生命周期阶段

5. **报告与发布模块** (rating_reports)
   - rating_reports: 评级报告（三层内容）
   - content_assets: 评级卡与资产
   - distribution_records: 分发记录
   - rating_attestations: 存证记录

6. **合规与审核模块** (compliance)
   - compliance_config: 合规配置（C1-C15）
   - compliance_decisions: 合规决策
   - correction_cases: 事实更正申请

7. **社群与归因模块** (community) - 简化版
   - members: 社群成员
   - admission_challenges: 准入验证
   - event_touches: 事件与归因
   - channels: 渠道与短链

8. **订阅与支付模块** (subscriptions) - 最小闭环
   - orders: 订单
   - subscriptions: 订阅
   - entitlements: 权益
   - payment_webhook_events: 支付事件

## 架构适配策略

### 1. 利用 zenaipa 现有能力

- ✅ 认证系统：复用 auth 模块（JWT + RBAC）
- ✅ 审计日志：复用 audit 模块
- ✅ 任务队列：复用 task 模块（用于后台采集）
- ✅ 文件管理：复用 file 模块（用于评级卡图片）
- ✅ 通知系统：复用 notify 模块
- ✅ 多租户：复用 tenant 模块（可选）

### 2. 新增业务模块

按 zenaipa 模块结构（model → persistence → service → api → module）：

1. `src/modules/blockchain_project/` - 项目管理
2. `src/modules/rating/` - 评级引擎
3. `src/modules/data_collection/` - 数据采集
4. `src/modules/compliance/` - 合规管理
5. `src/modules/three_source/` - 三源（预埋结构）
6. `src/modules/report/` - 报告发布

### 3. 前端扩展

- `web/src/pages/Projects/` - 项目管理页面
- `web/src/pages/Rating/` - 评级工作台
- `web/src/pages/Review/` - 复核工作台
- `web/src/pages/Compliance/` - 合规配置
- `web/src/pages/PublicRanking/` - 公开榜单（中文）
- `web/src/api/blockchain/` - API 客户端

## 数据库策略

### SQLite 配置
- 使用 WAL 模式
- 设置合理的 busy_timeout (5000ms)
- 金额使用 INTEGER（存储最小单位，避免浮点）
- 外键约束开启
- 事务隔离级别：SERIALIZABLE（SQLite默认）

### 迁移策略
- Schema-as-code 定义在各模块 model.zig
- 统一注册到 src/schema.zig
- 启动时自动迁移
- repository/service 分层便于后续迁移 PG

### 并发控制
- 评分/签发/发布使用唯一约束防重复
- 乐观锁（version 字段）防止 TOCTOU
- 关键操作使用事务

## P0 功能清单

### W1-W2: 地基与引擎（2周）

#### 1.1 项目库 CRUD ✓
- [ ] 项目基础信息管理
- [ ] 多链合约地址管理
- [ ] CSV 批量导入（校验+去重）
- [ ] 基础录入 ≤8 分钟/条

#### 1.2 数据采集框架 ✓
- [ ] 数据源配置管理
- [ ] 原始数据抓取记录（observed_at vs ingested_at）
- [ ] 自动值与人工覆盖双值记录
- [ ] 采集任务调度（基于 zenaipa task）

#### 1.3 六维评分引擎 ✓
- [ ] 方法论版本管理（权重可配置）
- [ ] 六维计算：Tech/Team/Tokenomics/Community/Liquidity/Compliance
- [ ] 默认权重：20/18/20/15/15/12
- [ ] 档位计算：S≥85, 75≤A<85, 60≤B<75, 45≤C<60, D<45
- [ ] 置信度计算：≥85%正常，60-85%中置信，<60% NR
- [ ] 确定性重算（同输入同输出）

#### 1.4 红牌规则 ✓
- [ ] R1: 全匿名+无审计 → 封顶D
- [ ] R2: 前10持仓>60% → 降1档
- [ ] R3: 90日解锁>30%流通 → 降1档
- [ ] R4: 立案/处罚/下架 → 封顶D
- [ ] R5: 分叉抄袭 → 降1档
- [ ] R6: ±2%深度<5万美元 → 降1档
- [ ] 不叠加规则：普通红牌最多降1档，R1/R4封顶优先

#### 1.5 四档位字段 ✓
- [ ] base_grade: 仅六维+置信度
- [ ] redflag_grade: base_grade + 红牌
- [ ] shadow_grade: 预留（W7启用三源）
- [ ] published_grade: 实际发布档位（=redflag_grade in W1-W6）

### W3: 复核与审计（1周）

#### 3.1 双人复核工作台 ✓
- [ ] 分析师提交评级
- [ ] 复核人逐维审核
- [ ] 差异对比展示
- [ ] 驳回/签发流程
- [ ] 强制不同自然人校验

#### 3.2 利益冲突管理 ✓
- [ ] 持仓/投资/顾问关系披露
- [ ] 冲突项目回避规则
- [ ] 披露随签发冻结

#### 3.3 审计追踪 ✓
- [ ] 完整审批链导出
- [ ] 操作者/时间/IP/输入哈希
- [ ] 复用 zenaipa audit 模块

### W4: 对外展示（1周）

#### 4.1 公开榜单（中文）✓
- [ ] 总榜与分榜（L1/L2/DeFi/RWA/AI-Agent/Meme/Infra）
- [ ] 筛选：赛道/档位/风险标签
- [ ] 项目列表与搜索

#### 4.2 项目详情页 ✓
- [ ] S/A/B/C/D/NR 显示
- [ ] 六维雷达图
- [ ] 置信度展示
- [ ] 更新时间
- [ ] 免责声明
- [ ] 利益冲突披露
- [ ] 版本与存证哈希
- [ ] 动态有效状态（撤回标记）

#### 4.3 评级卡生成 ✓
- [ ] 1:1 / 9:16 / 16:9 尺寸
- [ ] 档位 + 六维雷达
- [ ] 风险标签（最多3个）
- [ ] 免责声明
- [ ] 核验二维码
- [ ] 生成 ≤3秒

#### 4.4 事实/评分/观点分离 ✓
- [ ] 三层内容独立展示
- [ ] 明确区分标识
- [ ] C1 强制披露（不可关闭）

### W5: 合规开关（1周）

#### 5.1 C1-C15 实现 ✓
- [ ] C1 三段披露（开、不可关）
- [ ] C2 非投资建议（开、不可关）
- [ ] C3 地域屏蔽（开、可配置）
- [ ] C4 利益冲突披露（开）
- [ ] C5 激励模式（单层积分）
- [ ] C6 KYC（默认关、可开）
- [ ] C7 报告哈希存证（开）
- [ ] C8 可撤回（开）
- [ ] C9 事实申诉（开）
- [ ] C10 数据源授权（开）
- [ ] C11 匿名团队标注（开）
- [ ] C12 Bot溯源（开、不可关）
- [ ] C13 证券属性预警（开、触发人工审查）
- [ ] C14 更正删除通道（开、72h SLA）
- [ ] C15 未成年人限制（开）

#### 5.2 发布门禁 ✓
- [ ] C1/C2/C12 强制校验
- [ ] 代码层拒绝关闭
- [ ] 缺失条件拒绝发布

#### 5.3 撤回机制 ✓
- [ ] 合规负责人撤回权限
- [ ] 动态核验页显示撤回状态
- [ ] 可控站点/缓存失效
- [ ] 不承诺全网物理删除

### W6: 最小闭环（1周）

#### 6.1 事实更正入口 ✓
- [ ] 更正申请提交
- [ ] 证据材料上传
- [ ] 复核流程
- [ ] 公开更正记录

#### 6.2 基础归因 ✓
- [ ] 短链生成
- [ ] UTM 参数追踪
- [ ] 事件记录（page_view/bot_start等）
- [ ] 渠道统计

#### 6.3 示例数据 ✓
- [ ] 20个演示项目
- [ ] 明确标注"演示"
- [ ] 不捏造真实评级

## 三源预埋（W1）

### 数据结构预埋 ✓
- [ ] claims/claim_verifications 表
- [ ] roadmap_commitments 表
- [ ] governance_proposals 表
- [ ] revenue_breakdowns 表
- [ ] principles/tcc_conflicts 表
- [ ] three_source_assessments 表
- [ ] coherence_assessments 表
- [ ] project_stages 表

### 后台接口预留 ✓
- [ ] 三源数据录入接口（仅后台）
- [ ] 影子评分计算接口（不影响published_grade）
- [ ] 访问权限控制（仅授权人员）

### 明确不实现（W1-W6）✓
- ❌ 三源公开展示
- ❌ 象强物弱降档
- ❌ 三角图/合恰度公开
- ❌ 三源标签（传播不足等）

## 外部服务接口

### 数据采集（本地模式）✓
- [ ] 适配器接口定义
- [ ] Mock 数据源
- [ ] 本地测试模式
- [ ] 清晰标注"需配置真实API"

### 社群 Bot（占位）✓
- [ ] 接口定义
- [ ] 命令解析框架
- [ ] 演示模式（不真实发消息）
- [ ] 配置文档

### 支付集成（占位）✓
- [ ] Webhook 接口定义
- [ ] 订单状态机
- [ ] 幂等处理
- [ ] 演示订单（不真实扣款）

## 测试策略

### 单元测试 ✓
- [ ] 评分引擎边界测试
- [ ] 红牌规则测试
- [ ] 置信度计算测试
- [ ] 四档位逻辑测试

### 集成测试 ✓
- [ ] SQLite 数据库操作
- [ ] 事务并发测试
- [ ] 唯一约束测试

### API 测试 ✓
- [ ] 认证授权测试
- [ ] RBAC 权限测试
- [ ] 状态机测试

### 端到端测试 ✓
- [ ] 录入 → 数据 → 评分 → 分析师提交 → 复核签发 → 发布 → 公开详情

### 不可关开关测试 ✓
- [ ] C1/C2/C12 代码层拒绝关闭
- [ ] 防自签测试
- [ ] 签发快照不可改测试
- [ ] 撤回测试

## 部署说明

### 单机部署 ✓
- [ ] SQLite 文件位置配置
- [ ] 数据持久化卷
- [ ] 备份脚本
- [ ] 恢复演练

### 环境变量 ✓
```bash
ZENAIPA_DB_DRIVER=sqlite
ZENAIPA_SQLITE_PATH=/data/blockchain_rating.db
ZENAIPA_JWT_SECRET=<生产密钥>
# ... 其他配置
```

## 未实现项清单

### 不在 MVP 范围
1. ❌ 链上实时监控
2. ❌ 社区投票治理
3. ❌ 自动研报长文
4. ❌ 移动 App
5. ❌ 代币激励
6. ❌ 行情预测
7. ❌ 跟单/组合管理

### 简化实现
1. 🔶 社群 Bot - 接口框架，需外部平台配置
2. 🔶 数据采集 - Mock 源，需真实 API 密钥
3. 🔶 支付订阅 - 状态机，需支付商接入
4. 🔶 评级卡图片生成 - 基础实现，需设计美化

### W7+ 功能
1. ⏸️ 三源影子评分启用
2. ⏸️ 象强物弱降档
3. ⏸️ 六个月验证
4. ⏸️ 完整申诉门户
5. ⏸️ 高级 CAC/LTV 分析
6. ⏸️ 多平台内容编排

## 里程碑验收

### M1: 核心数据流通（第1-2周）
- ✅ 项目库可用
- ✅ 数据采集框架
- ✅ 六维引擎可运行
- ✅ 基础测试通过

### M2: 双人复核（第3周）
- ✅ 工作台可用
- ✅ 审批流程完整
- ✅ 审计可追溯
- ✅ 权限隔离生效

### M3: 公开展示（第4周）
- ✅ 榜单页面
- ✅ 详情页面
- ✅ 评级卡生成
- ✅ 三层分离展示

### M4: 合规门禁（第5周）
- ✅ 15个开关实现
- ✅ 强制开关生效
- ✅ 撤回机制可用

### M5: 最小闭环（第6周）
- ✅ 更正流程
- ✅ 基础归因
- ✅ 演示数据
- ✅ 完整测试

## 风险与对策

### 技术风险
1. **Zig 生态不熟悉**
   - 对策：参考现有模块，渐进开发
   
2. **SQLite 并发限制**
   - 对策：WAL模式 + busy_timeout + 队列化写入

3. **评分引擎复杂度**
   - 对策：先实现确定性核心，复杂规则可配置化

### 业务风险
1. **评级方法论未完全验证**
   - 对策：三源预埋不启用，标注实验性

2. **合规要求不明确**
   - 对策：保守实现15开关，留扩展空间

3. **外部服务依赖**
   - 对策：接口抽象 + Mock实现 + 清晰文档

## 下一步

1. 创建核心模块结构
2. 实现项目库和数据采集
3. 实现评分引擎
4. 实现复核工作台
5. 实现公开展示
6. 实现合规控制
7. 完善测试
8. 创建 PR

## 交付物清单

1. ✅ 实施计划文档（本文档）
2. 📝 PRD 需求映射文档
3. 📝 API 接口文档
4. 📝 数据库 Schema 文档
5. 📝 测试报告
6. 📝 部署说明
7. 📝 未实现功能清单
8. 📝 下一阶段建议
