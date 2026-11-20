const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 项目宣称
pub const Claim = Schema("claims", .{
    .fields = &.{
        field.String("claim_id").Unique(), // UUID
        field.Int("project_id"),
        
        // 宣称内容
        field.String("claim_text").Size(4000), // 原文
        field.String("claim_archive_url").Optional().Size(500), // 存档链接
        field.String("claimed_by"), // 发布主体
        field.Date("claimed_at").Optional(), // 宣称时间
        
        // 宣称指标
        field.String("claimed_metric").Optional(), // 宣称的指标
        field.String("claimed_value").Optional(), // 宣称的值
        field.String("claimed_unit").Optional(), // 单位
        field.String("claimed_scope").Optional().Size(500), // 范围
        field.String("claimed_time_period").Optional(), // 时间周期
        
        // 核验状态
        field.String("verification_status").Default("pending"), // pending/verified/disputed/unverifiable
        field.Int("verified_by").Optional(), // 核验人 user_id
        field.Date("verified_at").Optional(),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"claim_id"}),
        zent.core.index.Fields(&.{"project_id"}),
    },
});

/// 宣称核验
pub const ClaimVerification = Schema("claim_verifications", .{
    .fields = &.{
        field.String("claim_id"), // 关联 claims.claim_id
        field.String("observed_value_ref").Optional(), // 观测值引用
        
        // 对齐口径
        field.String("alignment_notes").Optional().Size(2000), // 口径对齐说明
        field.String("metric_alignment").Optional(), // 指标对齐情况
        field.String("scope_alignment").Optional(), // 范围对齐情况
        field.String("time_alignment").Optional(), // 时间对齐情况
        
        // 差异计算
        field.String("difference_value").Optional(), // 差异值
        field.Int("difference_percentage").Default(0), // 差异百分比（千分比）
        field.String("difference_calculation").Optional().Size(1000), // 差异计算说明
        
        // 证据覆盖
        field.Int("evidence_coverage").Default(0), // 证据覆盖度 0-100
        field.String("coverage_gaps").Optional().Size(1000), // 覆盖缺口
        
        // 核验结论
        field.String("verification_result"), // consistent/minor_deviation/major_deviation/contradictory/insufficient
        field.String("conclusion_notes").Optional().Size(2000),
        
        // 审批
        field.Int("verifier_id").Optional(), // 核验人
        field.Int("reviewer_id").Optional(), // 复核人
        field.Date("verified_at").Optional(),
        
        // 版本
        field.Int("version").Default(1),
        field.String("method_version").Optional(), // 核验方法版本
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"claim_id"}),
    },
});

/// 路线图承诺
pub const RoadmapCommitment = Schema("roadmap_commitments", .{
    .fields = &.{
        field.String("commitment_id").Unique(), // UUID
        field.Int("project_id"),
        
        // 承诺内容
        field.String("commitment_text").Size(4000), // 原文
        field.String("evidence_url").Optional().Size(500), // 证据链接
        field.Date("announced_at").Optional(), // 公告时间
        field.Date("original_due_at").Optional(), // 原定期限
        field.Date("revised_due_at").Optional(), // 修订期限
        
        // 验收定义
        field.String("acceptance_criteria").Optional().Size(2000), // 验收标准
        field.String("verifiability").Default("unknown"), // verifiable/partially/unverifiable
        
        // 分母冻结
        field.String("denominator_freeze_id").Optional(), // 分母冻结记录ID
        
        // 状态
        field.String("status").Default("pending"), // pending/in_progress/delivered/delayed/cancelled/partially_delivered
        field.Date("delivered_at").Optional(), // 交付时间
        field.String("delivery_evidence").Optional().Size(2000), // 交付证据
        field.String("delay_reason").Optional().Size(1000), // 延期原因
        field.String("partial_completion_note").Optional().Size(1000), // 部分完成说明
        
        // 版本链
        field.Int("supersedes_id").Optional(),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"commitment_id"}),
        zent.core.index.Fields(&.{ "project_id", "status" }),
    },
});

/// 治理提案
pub const GovernanceProposal = Schema("governance_proposals", .{
    .fields = &.{
        field.String("proposal_id").Unique(), // UUID或链上ID
        field.Int("project_id"),
        
        // 提案信息
        field.String("proposal_text").Size(4000), // 提案内容
        field.String("proposal_category").Optional(), // 类别
        field.Date("passed_at").Optional(), // 通过时间
        
        // 执行
        field.Date("execution_due_at").Optional(), // 应执行日期
        field.String("execution_conditions").Optional().Size(1000), // 执行条件
        field.Bool("is_executable").Default(true), // 是否可执行
        field.Bool("is_applicable").Default(true), // 是否适用（纯意见提案可能不适用）
        
        // 执行状态
        field.String("execution_status").Default("pending"), // pending/executed/cancelled/delayed
        field.Date("executed_at").Optional(),
        field.String("execution_tx_ref").Optional().Size(500), // 执行交易引用
        field.String("delivery_refs").Optional().Size(2000), // 交付证据
        
        // 核验
        field.String("verification_status").Default("unverified"), // verified/pending/unverified
        
        // 分母冻结
        field.String("denominator_freeze_ref").Optional(),
        field.String("revision_history").Optional().Size(2000), // 修订历史
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"proposal_id"}),
        zent.core.index.Fields(&.{"project_id"}),
    },
});

/// 收入拆分
pub const RevenueBreakdown = Schema("revenue_breakdowns", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("period"), // 周期: 2024-Q1 或 2024-01等
        
        // 收入口径
        field.String("entity_scope").Optional(), // 实体范围
        field.String("accounting_basis").Optional(), // 会计基准: accrual/cash
        field.String("currency").Default("USD"),
        
        // 总收入
        field.BigInt("gross_revenue_cents").Default(0), // 总收入（美分）
        
        // 拆分明细
        field.String("line_item_id").Optional(), // 明细行ID
        field.String("revenue_category").Optional(), // 收入类别: fee/subscription/yield/other
        field.BigInt("line_amount_cents").Default(0), // 明细金额
        
        // 激励与关联方
        field.BigInt("incentive_included_amount_cents").Default(0), // 包含的激励金额
        field.BigInt("related_party_amount_cents").Default(0), // 关联方金额
        field.Bool("incentive_related_party_overlap").Default(false), // 两类是否重叠
        
        // 真实需求（RDS计算）
        field.BigInt("qualified_demand_amount_cents").Default(0), // 合格需求金额
        field.BigInt("unidentified_amount_cents").Default(0), // 未识别金额
        
        // 来源与复核
        field.String("source_refs").Optional().Size(1000),
        field.Int("reviewed_by").Optional(),
        field.Date("reviewed_at").Optional(),
        field.String("review_notes").Optional().Size(1000),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "period" }),
    },
});

/// 核心主张
pub const Principle = Schema("principles", .{
    .fields = &.{
        field.String("principle_id").Unique(), // UUID
        field.Int("project_id"),
        
        // 主张内容
        field.String("principle_text").Size(4000), // 核心主张原文
        field.Int("principle_version").Default(1), // 版本
        field.Date("principle_frozen_at").Optional(), // 冻结日期
        
        // 来源
        field.String("source_document").Optional().Size(500), // 来源文档
        field.String("source_url").Optional().Size(500),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"principle_id"}),
        zent.core.index.Fields(&.{"project_id"}),
    },
});

/// TCC 冲突事件
pub const TccConflict = Schema("tcc_conflicts", .{
    .fields = &.{
        field.String("principle_id"), // 关联 principles.principle_id
        field.String("conflict_event_id").Unique(), // 冲突事件ID
        
        // 决策信息
        field.String("decision_id").Optional(), // 决策ID
        field.Date("occurred_at").Optional(), // 发生时间
        field.String("conflict_evidence").Size(4000), // 冲突证据
        
        // 严重性
        field.String("severity").Default("medium"), // low/medium/high/critical
        field.Int("severity_score").Default(0), // 严重性分数（待定义）
        
        // 项目回应
        field.String("project_response").Optional().Size(2000),
        
        // 分析结论
        field.String("analysis_conclusion").Optional().Size(2000),
        field.Int("analyst_id").Optional(),
        field.Int("reviewer_id").Optional(),
        field.Date("analyzed_at").Optional(),
        
        // 去重
        field.String("dedupe_key").Optional(),
        
        // 解决
        field.Bool("is_resolved").Default(false),
        field.Date("resolved_at").Optional(),
        field.String("resolution_note").Optional().Size(1000),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"conflict_event_id"}),
        zent.core.index.Fields(&.{"principle_id"}),
        zent.core.index.Fields(&.{"dedupe_key"}),
    },
});

/// 项目生命周期阶段
pub const ProjectStage = Schema("project_stages", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("stage"), // stage1/stage2/stage3/unknown
        field.String("stage_version").Default("v1.0"), // 阶段定义版本
        
        // 判断依据
        field.String("sector_applicability").Optional(), // 适用赛道
        field.Int("launch_age_days").Optional(), // 上线天数
        field.BigInt("tvl_value_cents").Optional(), // TVL值（美分）
        field.String("tvl_currency").Optional(),
        field.Date("tvl_as_of").Optional(),
        field.Bool("tvl_applicable").Default(false), // TVL是否适用该赛道
        
        // 评估记录
        field.String("assessment_basis").Optional().Size(1000), // 判断依据
        field.Int("assessed_by").Optional(),
        field.Int("approved_by").Optional(),
        field.Date("assessed_at").Optional(),
        
        // 有效期
        field.Date("valid_from").Optional(),
        field.Date("valid_to").Optional(),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"project_id"}),
    },
});

/// 三源评估（影子计算）
pub const ThreeSourceAssessment = Schema("three_source_assessments", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("snapshot_id"), // 关联评级输入快照
        field.String("three_method_version"), // 三源方法版本
        
        // 三源原值（物/象/义）
        field.Int("material_score").Default(0), // 物分 0-100
        field.Int("symbol_score").Default(0), // 象分 0-100
        field.Int("meaning_score").Default(0), // 义分 0-100
        
        // RDR/GER/RDS/TCC 原值与状态
        field.Int("rdr_value").Optional(), // 千分比
        field.String("rdr_status").Default("pending"),
        field.Int("ger_value").Optional(),
        field.String("ger_status").Default("pending"),
        field.Int("rds_value").Optional(),
        field.String("rds_status").Default("pending"),
        field.Int("tcc_score").Optional(),
        field.String("tcc_status").Default("pending"),
        
        // 置信度
        field.Int("confidence_three").Default(0), // 三源置信度 0-1000
        
        // 整体状态
        field.String("overall_status").Default("pending"), // pending/complete/insufficient/nr
        field.Int("coverage_percentage").Default(0), // 覆盖率 0-100
        
        // 生命周期
        field.String("stage_ref").Optional(),
        
        // 影子模式标记
        field.Bool("shadow_mode").Default(true), // 是否影子模式
        field.String("access_level").Default("internal"), // internal/authorized_only
        
        // 评审
        field.Int("assessor_id").Optional(),
        field.Date("assessed_at").Optional(),
        field.String("work_hours_note").Optional(), // 额外工时记录
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"project_id"}),
        zent.core.index.Fields(&.{"snapshot_id"}),
    },
});

/// 合恰度评估
pub const CoherenceAssessment = Schema("coherence_assessments", .{
    .fields = &.{
        field.Int("three_assessment_id"), // 关联 three_source_assessments.id
        
        // 三对偏离
        field.Int("d_material_symbol").Optional(), // 物象偏离 0-1000
        field.Int("d_symbol_meaning").Optional(), // 象义偏离 0-1000
        field.Int("d_meaning_material").Optional(), // 义物偏离 0-1000
        
        // 每对证据与适用性
        field.String("d_ms_evidence").Optional().Size(2000),
        field.Bool("d_ms_applicable").Default(false),
        field.String("d_sm_evidence").Optional().Size(2000),
        field.Bool("d_sm_applicable").Default(false),
        field.String("d_mm_evidence").Optional().Size(2000),
        field.Bool("d_mm_applicable").Default(false),
        
        // 合恰度
        field.Int("d_max").Optional(), // 最大偏离 0-1000
        field.Int("coherence_score").Optional(), // C = 100×(1−d_max) 0-100
        field.String("coherence_status").Default("pending"), // ok/nr/insufficient
        
        // 断裂类型（六类结构）
        field.String("fracture_type").Optional(), // balanced/material_strong_symbol_weak/etc
        field.String("fracture_label").Optional(), // 结构标签
        
        // 单向降档触发（象强物弱）
        field.Bool("directional_trigger").Default(false), // 是否触发单向降档
        field.String("threshold_version").Optional(), // 阈值版本
        field.Bool("lifecycle_exemption").Default(false), // 生命周期豁免
        
        // 影子档位
        field.String("shadow_grade").Default("NR"), // 影子档位
        
        // 计算版本
        field.String("calculation_version").Optional(),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"three_assessment_id"}),
    },
});
