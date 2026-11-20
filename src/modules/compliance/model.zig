const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 合规配置（C1-C15开关）
pub const ComplianceConfig = Schema("compliance_configs", .{
    .fields = &.{
        field.String("switch_id").Unique(), // C1/C2/.../C15
        field.String("switch_name"), // 开关名称
        field.String("description").Optional().VarChar(1000), // 描述
        
        // 配置值
        field.Bool("is_enabled").Default(true), // 是否启用
        field.Bool("can_be_disabled").Default(true), // 是否可以关闭
        field.String("config_json").Optional().VarChar(4000), // 额外配置JSON
        
        // 适用范围
        field.String("apply_to_regions").Optional().VarChar(500), // 适用地域（逗号分隔）
        field.String("apply_to_channels").Optional().VarChar(500), // 适用渠道
        
        // 审批
        field.String("change_reason").Optional().VarChar(1000), // 变更理由
        field.Int("approved_by").Optional(), // 批准人 user_id
        field.Time("approved_at").Optional(),
        field.Time("effective_at").Optional(), // 生效时间
        
        // 版本
        field.Int("config_version").Default(1), // 配置版本号
        field.Int("supersedes_id").Optional(), // 替代的旧配置ID
        
        // 审计
        field.String("audit_log_ref").Optional().VarChar(500), // 审计日志引用
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"switch_id"}),
        zent.core.index.Fields(&.{"config_version"}),
    },
});

/// 合规决策记录
pub const ComplianceDecision = Schema("compliance_decisions", .{
    .fields = &.{
        field.Int("decision_id"), // 决策ID
        field.String("decision_type"), // 类型: review/approve/reject/revoke/exception
        
        // 关联对象
        field.String("target_type"), // 目标类型: rating/report/distribution/member
        field.Int("target_id"), // 目标ID
        
        // 决策者
        field.Int("decider_id"), // 决策人 user_id
        field.String("decider_role"), // 角色: compliance_officer/admin/reviewer
        
        // 决策内容
        field.String("decision").Default("pending"), // pending/approved/rejected/revoked
        field.String("decision_reason").Optional().VarChar(2000), // 理由
        field.String("applicable_switches").Optional().VarChar(500), // 适用的开关（逗号分隔）
        
        // 强制门禁检查结果
        field.Bool("c1_check_passed").Default(false), // C1 三段披露
        field.Bool("c2_check_passed").Default(false), // C2 非投资建议
        field.Bool("c12_check_passed").Default(false), // C12 Bot溯源
        field.String("gate_check_details").Optional().VarChar(2000), // 门禁检查详情
        
        // 时间
        field.Time("decided_at").Optional(),
        field.Time("effective_until").Optional(), // 有效期至
        
        // 异常请求
        field.Bool("is_exception_request").Default(false), // 是否异常请求
        field.String("exception_justification").Optional().VarChar(2000),
        
        // 审计
        field.String("audit_trail").Optional().VarChar(2000), // 审计轨迹
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "target_type", "target_id" }),
        zent.core.index.Fields(&.{"decider_id"}),
    },
});

/// 事实更正申请
pub const CorrectionCase = Schema("correction_cases", .{
    .fields = &.{
        field.String("case_id").Unique(), // 案件编号
        field.Int("project_id").Optional(),
        field.Int("rating_id").Optional(),
        
        // 申请信息
        field.String("submitter_contact").Optional().VarChar(500), // 联系方式（脱敏存储）
        field.String("submitter_role").Optional(), // 项目方/第三方/内部
        
        // 更正内容
        field.String("field_name"), // 要更正的字段
        field.String("current_value").Optional().VarChar(2000), // 当前值
        field.String("suggested_value").Optional().VarChar(2000), // 建议值
        field.String("correction_reason").VarChar(4000), // 更正理由
        
        // 证据
        field.String("evidence_files").Optional().VarChar(2000), // 证据文件引用（逗号分隔）
        field.String("evidence_urls").Optional().VarChar(2000), // 证据链接
        
        // 处理
        field.String("status").Default("received"), // received/under_review/approved/rejected/completed
        field.Int("reviewer_id").Optional(), // 复核人 user_id
        field.String("review_note").Optional().VarChar(2000), // 复核意见
        field.String("resolution").Optional().VarChar(2000), // 处理结果
        
        // 时间
        field.Time("received_at").Optional(),
        field.Time("reviewed_at").Optional(),
        field.Time("resolved_at").Optional(),
        
        // 公开变更引用
        field.Int("public_change_ref").Optional(), // 关联 rating_changes.id
        
        // 敏感信息处理标记
        field.Bool("contains_sensitive_info").Default(false),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"case_id"}),
        zent.core.index.Fields(&.{ "status", "received_at" }),
    },
});

/// 利益冲突披露
pub const ConflictDisclosure = Schema("conflict_disclosures", .{
    .fields = &.{
        field.Int("user_id"), // 关联 users.id
        field.Int("project_id"), // 关联项目
        
        // 冲突类型
        field.String("conflict_type"), // holding/investment/advisor/sponsorship/employment/other
        field.String("conflict_detail").VarChar(2000), // 详细说明
        
        // 持仓情况（如适用）
        field.String("holding_amount").Optional(), // 持仓数量
        field.String("acquisition_date").Optional(), // 获取日期
        field.Bool("is_significant_holding").Default(false), // 是否重大持仓
        
        // 回避规则
        field.Bool("requires_recusal").Default(false), // 是否需要回避
        field.String("recusal_scope").Optional().VarChar(500), // 回避范围
        
        // 状态
        field.String("disclosure_status").Default("active"), // active/resolved/expired
        field.Time("disclosed_at").Optional(),
        field.Time("expires_at").Optional(),
        
        // 冻结（随签发冻结）
        field.Bool("is_frozen").Default(false), // 是否已冻结
        field.Int("frozen_by_rating_id").Optional(), // 被哪个评级冻结
        
        // 审批
        field.Int("approved_by").Optional(), // 批准人
        field.Time("approved_at").Optional(),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "user_id", "project_id" }),
        zent.core.index.Fields(&.{"disclosure_status"}),
    },
});
