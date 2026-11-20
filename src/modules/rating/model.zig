const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 方法论版本
pub const MethodVersion = Schema("method_versions", .{
    .fields = &.{
        field.String("method_version").Unique(), // 版本号 v1.0.0
        field.String("sector_template").Default("default"), // default/RWA/Meme等
        
        // 六维权重（千分比：0-1000 表示 0-100%）
        field.Int("weight_tech").Default(200), // 技术 20%
        field.Int("weight_team").Default(180), // 团队 18%
        field.Int("weight_tokenomics").Default(200), // 代币经济 20%
        field.Int("weight_community").Default(150), // 社区 15%
        field.Int("weight_liquidity").Default(150), // 流动性 15%
        field.Int("weight_compliance").Default(120), // 合规 12%
        
        // 档位阈值（0-100）
        field.Int("grade_s_threshold").Default(85), // S ≥ 85
        field.Int("grade_a_threshold").Default(75), // A ≥ 75
        field.Int("grade_b_threshold").Default(60), // B ≥ 60
        field.Int("grade_c_threshold").Default(45), // C ≥ 45
        // D < 45
        
        // 置信度阈值（千分比）
        field.Int("confidence_normal").Default(850), // ≥85% 正常
        field.Int("confidence_medium").Default(600), // ≥60% 中置信
        // <60% NR
        
        // 红牌规则启用
        field.Bool("enable_r1").Default(true), // 匿名+无审计
        field.Bool("enable_r2").Default(true), // 前10持仓>60%
        field.Bool("enable_r3").Default(true), // 90日解锁>30%
        field.Bool("enable_r4").Default(true), // 立案/处罚/下架
        field.Bool("enable_r5").Default(true), // 分叉抄袭
        field.Bool("enable_r6").Default(true), // 深度<5万
        
        // 规则参数
        field.String("redflag_rules_json").Optional().VarChar(4000), // 红牌规则JSON
        field.String("indicator_weights_json").Optional().VarChar(4000), // 指标权重JSON
        field.String("normalization_json").Optional().VarChar(4000), // 归一化规则JSON
        field.String("applicability_json").Optional().VarChar(2000), // 适用性规则JSON
        
        // 审批
        field.Time("effective_at").Optional(), // 生效日期
        field.String("approval_refs").Optional().VarChar(1000), // 审批引用
        field.String("canonical_hash").Optional(), // 规范哈希
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"method_version"}),
    },
});

/// 评级输入快照（不可变）
pub const RatingInputSnapshot = Schema("rating_input_snapshots", .{
    .fields = &.{
        field.String("snapshot_id").Unique(), // UUID
        field.Int("project_id"),
        field.String("as_of"), // 评估时点 ISO8601
        
        // 输入数据引用（JSON或逗号分隔ID）
        field.String("metric_value_refs").Optional().VarChar(4000),
        field.String("override_refs").Optional().VarChar(2000),
        field.String("source_hashes").Optional().VarChar(2000),
        
        // 适用性与缺失
        field.String("applicability_json").Optional().VarChar(2000),
        field.String("missing_list").Optional().VarChar(2000),
        
        // 生命周期
        field.String("stage_ref").Optional(), // 生命周期阶段引用
        
        // 方法论
        field.String("method_version"), // 关联 method_versions.method_version
        field.String("code_version").Optional(), // 代码版本/Git SHA
        
        // 哈希
        field.String("canonical_input_hash"), // 输入规范哈希
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"snapshot_id"}),
        zent.core.index.Fields(&.{ "project_id", "as_of" }),
    },
});

/// 评级输出
pub const Rating = Schema("ratings", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("snapshot_id"), // 关联 rating_input_snapshots.snapshot_id
        
        // 六维分数 (0-100)
        field.Int("tech_score").Default(0),
        field.Int("team_score").Default(0),
        field.Int("tokenomics_score").Default(0),
        field.Int("community_score").Default(0),
        field.Int("liquidity_score").Default(0),
        field.Int("compliance_score").Default(0),
        
        // 基础分数
        field.Int("base_score").Default(0), // 加权总分 0-100
        field.String("base_grade").Default("NR"), // S/A/B/C/D/NR
        
        // 四档位字段
        field.String("redflag_grade").Default("NR"), // base_grade + 红牌
        field.String("shadow_grade").Default("NR"), // 预留三源（W7启用）
        field.String("published_grade").Default(""), // 实际发布档位（空表示未发布）
        
        // 置信度
        field.Int("confidence_six").Default(0), // 六维置信度 0-1000 (千分比)
        field.Int("confidence_three").Default(0), // 三源置信度（预留）
        
        // 红牌
        field.String("redflags").Optional().VarChar(1000), // JSON数组: ["R1","R3"]
        field.Bool("compound_warning").Default(false), // 复合预警
        
        // 三源状态（预留）
        field.String("shadow_evaluability").Default("pending"), // pending/ok/insufficient
        
        // 方法论
        field.String("method_version"),
        
        // 状态
        field.String("status").Default("draft"), // draft/submitted/in_review/approved/published/superseded/withdrawn
        
        // 审批
        field.Int("analyst_id").Optional(), // 分析师 user_id
        field.Int("reviewer_id").Optional(), // 复核人 user_id
        field.Time("submitted_at").Optional(),
        field.Time("issued_at").Optional(), // 签发时间
        field.Time("published_at").Optional(), // 发布时间
        
        // 存证
        field.String("content_hash").Optional(), // 内容哈希
        field.String("report_hash").Optional(), // 报告哈希
        
        // 版本链
        field.Int("supersedes_id").Optional(), // 替代的旧评级ID
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "status" }),
        zent.core.index.Fields(&.{"snapshot_id"}),
        zent.core.index.Fields(&.{ "status", "published_at" }),
    },
});

/// 维度证据
pub const DimensionEvidence = Schema("dimension_evidence", .{
    .fields = &.{
        field.Int("rating_id"), // 关联 ratings.id
        field.String("dimension"), // tech/team/tokenomics/community/liquidity/compliance
        field.String("metric_key"), // 指标键
        field.String("metric_value").Optional(), // 原始值
        field.String("normalized_value").Optional(), // 归一化值
        field.Int("weight_in_dimension").Default(0), // 维度内权重 0-1000
        field.String("rationale").Optional().VarChar(1000), // 理由
        field.Int("metric_snapshot_id").Optional(), // 关联数据快照ID
        field.String("evidence_refs").Optional().VarChar(1000), // 证据链接
        field.String("method_version"), // 方法论版本
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "rating_id", "dimension" }),
    },
});

/// 评级复核
pub const RatingReview = Schema("rating_reviews", .{
    .fields = &.{
        field.Int("rating_id"),
        field.Int("analyst_person_id"), // 分析师自然人ID
        field.Int("reviewer_person_id"), // 复核人自然人ID
        
        // 逐维评论
        field.String("tech_comment").Optional().VarChar(1000),
        field.String("team_comment").Optional().VarChar(1000),
        field.String("tokenomics_comment").Optional().VarChar(1000),
        field.String("community_comment").Optional().VarChar(1000),
        field.String("liquidity_comment").Optional().VarChar(1000),
        field.String("compliance_comment").Optional().VarChar(1000),
        field.String("overall_comment").Optional().VarChar(2000),
        
        // 决策
        field.String("decision").Default("pending"), // pending/approved/rejected
        field.String("rejection_reason").Optional().VarChar(1000),
        
        // 时间戳
        field.Time("submitted_at").Optional(),
        field.Time("reviewed_at").Optional(),
        
        // 审计
        field.String("reviewer_ip").Optional(),
        field.String("evidence_refs").Optional().VarChar(1000),
        field.String("conflict_disclosure_ref").Optional().VarChar(1000),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"rating_id"}),
    },
});

/// 评级变更
pub const RatingChange = Schema("rating_changes", .{
    .fields = &.{
        field.Int("project_id"),
        field.Int("old_rating_id").Optional(),
        field.Int("new_rating_id"),
        
        // 档位变更
        field.String("from_grade").Optional(),
        field.String("to_grade"),
        
        // 分数变更
        field.Int("from_score").Optional(),
        field.Int("to_score"),
        
        // 逐维差异（JSON）
        field.String("diff_by_dimension").Optional().VarChar(2000),
        
        // 原因
        field.String("reason").Optional().VarChar(2000),
        field.String("change_type").Default("normal"), // normal/redflag/shadow/correction
        
        // 公告
        field.Time("announced_at").Optional(),
        field.Int("announced_by").Optional(), // user_id
        
        // 审批
        field.String("approval_refs").Optional().VarChar(1000),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "announced_at" }),
    },
});
