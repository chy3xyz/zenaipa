const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 区块链项目主表
pub const Project = Schema("Project", .{
    .fields = &.{
        field.String("name"), // 项目名称
        field.String("slug").Unique(), // URL友好标识
        field.String("description").Optional().VarChar(2000), // 项目描述
        field.String("sector").Default("Other"), // 赛道: L1/L2/DeFi/RWA/AI-Agent/Meme/Infra
        field.String("status").Default("active"), // 状态: active/inactive/archived
        
        // 基础信息
        field.String("official_url").Optional(), // 官网
        field.String("twitter_url").Optional(), // Twitter
        field.String("github_url").Optional(), // GitHub
        field.String("docs_url").Optional(), // 文档
        field.String("discord_url").Optional(), // Discord
        field.String("telegram_url").Optional(), // Telegram
        
        // 法律实体
        field.String("legal_entity").Optional(), // 法律主体
        field.String("jurisdiction").Optional(), // 注册地
        
        // 时间
        field.Time("founded_at").Optional(), // 成立时间
        field.Time("mainnet_launched_at").Optional(), // 主网上线
        
        // 团队
        field.Bool("is_anonymous_team").Default(false), // 团队是否匿名
        
        // 元数据
        field.String("tags").Optional().VarChar(500), // 逗号分隔标签
        field.Int("data_completeness").Default(0), // 数据完整度 0-100
        
        // 多租户（如果需要）
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "sector", "status" }),
        zent.core.index.Fields(&.{"slug"}),
    },
});

/// 合约地址表（一个项目可能在多条链上）
pub const ProjectContract = Schema("project_contracts", .{
    .fields = &.{
        field.Int("project_id"), // 关联 blockchain_projects.id
        field.String("chain"), // 链名: ethereum/bsc/polygon/arbitrum/optimism等
        field.String("contract_address"), // 合约地址
        field.String("contract_type").Default("token"), // 类型: token/staking/governance等
        field.String("token_symbol").Optional(), // 代币符号
        field.Int("decimals").Default(18), // 小数位
        field.Bool("is_verified").Default(false), // 是否已验证
        field.Bool("is_primary").Default(false), // 是否主合约
        field.String("verified_source").Optional(), // 验证来源
        field.Time("valid_from").Optional(), // 生效日期
        field.Time("valid_to").Optional(), // 失效日期
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "chain" }),
        zent.core.index.Fields(&.{ "chain", "contract_address" }),
    },
});

/// 代币指标快照
pub const TokenMetric = Schema("token_metrics", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("snapshot_at"), // ISO8601 时间戳
        
        // 供应量（使用字符串存储大数，避免溢出）
        field.String("total_supply").Optional(), // 总供应量
        field.String("circulating_supply").Optional(), // 流通量
        field.Int("circulating_ratio").Default(0), // 流通率 0-10000 (表示0-100.00%)
        
        // 市值（使用整数存储美分，避免浮点误差）
        field.Int("price_usd_cents").Default(0), // 价格（美分）
        field.Int("market_cap_usd_cents").Default(0), // 市值（美分）
        field.Int("fdv_usd_cents").Default(0), // FDV（美分）
        
        // 其他指标
        field.String("currency").Default("USD"), // 计价币种
        field.Int("source_id").Optional(), // 数据源 ID
        field.String("data_quality").Default("unknown"), // 质量: good/medium/poor/unknown
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "snapshot_at" }),
    },
});

/// 团队成员
pub const TeamMember = Schema("team_members", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("name_or_alias"), // 姓名或别名
        field.String("role").Optional(), // 职位
        field.Bool("is_public_identity").Default(false), // 是否实名
        field.String("verifiable_profile").Optional().VarChar(1000), // 可验证履历
        field.String("proof_refs").Optional().VarChar(1000), // 证据链接
        field.Time("joined_at").Optional(), // 加入时间
        field.Time("left_at").Optional(), // 离职时间
        field.String("vesting_note").Optional().VarChar(500), // 锁仓安排
        field.String("conflict_disclosure").Optional().VarChar(1000), // 利益冲突披露
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"project_id"}),
    },
});

/// 融资轮次
pub const FundingRound = Schema("funding_rounds", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("round_name"), // 轮次: Seed/Series A/B/C/Strategic等
        field.Int("amount_cents").Default(0), // 金额（美分）
        field.String("currency").Default("USD"),
        field.Int("valuation_cents").Optional(), // 估值（美分）
        field.String("valuation_type").Optional(), // pre-money/post-money
        field.String("investors").Optional().VarChar(2000), // 投资方（逗号分隔）
        field.Time("announced_at").Optional(), // 公告时间
        field.Time("closed_at").Optional(), // 完成时间
        field.String("source_refs").Optional().VarChar(1000), // 来源链接
        field.String("verified_status").Default("unverified"), // verified/pending/unverified
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"project_id"}),
    },
});

/// 解锁事件
pub const UnlockEvent = Schema("unlock_events", .{
    .fields = &.{
        field.Int("project_id"),
        field.Int("token_contract_id").Optional(), // 关联 project_contracts.id
        field.Time("unlock_at"), // 解锁日期
        field.String("amount").Optional(), // 解锁数量
        field.Int("pct_of_circulating").Default(0), // 占流通量百分比 0-10000
        field.String("recipient_type").Optional(), // team/investor/foundation/ecosystem等
        field.Bool("is_cliff").Default(false), // 是否cliff
        field.String("vesting_terms").Optional().VarChar(500), // 锁仓条款
        field.String("source_ref").Optional(), // 来源
        field.String("status").Default("scheduled"), // scheduled/completed/cancelled
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "unlock_at" }),
    },
});

/// 项目标签
pub const ProjectTag = Schema("project_tags", .{
    .fields = &.{
        field.Int("project_id"),
        field.String("tag_type"), // sector/risk/controversy/three_source等
        field.String("tag_code"), // 标签代码
        field.String("tag_label").Optional(), // 显示标签
        field.String("fact_or_opinion").Default("fact"), // fact/opinion
        field.String("evidence_refs").Optional().VarChar(1000), // 证据
        field.Int("added_by").Optional(), // 添加人 user_id
        field.String("review_status").Default("pending"), // pending/approved/rejected
        field.Time("valid_from").Optional(),
        field.Time("valid_to").Optional(),
        field.String("access_level").Default("public"), // public/internal/shadow
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "tag_type" }),
    },
});
