const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 评级报告（三层内容）
pub const RatingReport = Schema("rating_reports", .{
    .fields = &.{
        field.Int("project_id"),
        field.Int("rating_id"), // 关联 ratings.id
        
        // 三层内容（Markdown格式）
        field.String("fact_layer_md").Optional().VarChar(8000), // 事实层
        field.String("score_layer_md").Optional().VarChar(8000), // 评分层
        field.String("opinion_layer_md").Optional().VarChar(8000), // 观点层
        
        // 状态
        field.String("status").Default("draft"), // draft/published/superseded/withdrawn
        
        // 签发信息
        field.Int("analyst_id").Optional(), // 分析师
        field.Int("reviewer_id").Optional(), // 复核人
        field.Time("issued_at").Optional(), // 签发时间
        field.Time("published_at").Optional(), // 发布时间
        
        // 存证
        field.String("content_hash"), // 内容哈希（三层内容+元数据）
        field.String("chain_anchor_tx").Optional(), // 链上锚定交易（可选）
        field.Time("anchored_at").Optional(),
        
        // 披露
        field.String("disclosure_json").Optional().VarChar(2000), // 披露信息JSON
        field.String("conflict_disclosure_refs").Optional().VarChar(1000), // 利益冲突披露引用
        
        // 版本
        field.Int("supersedes_id").Optional(), // 替代的旧报告ID
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "status" }),
        zent.core.index.Fields(&.{"rating_id"}),
    },
});

/// 内容资产（评级卡）
pub const ContentAsset = Schema("content_assets", .{
    .fields = &.{
        field.String("asset_id").Unique(), // UUID
        field.String("asset_type").Default("rating_card"), // rating_card/report_pdf/infographic
        
        // 关联
        field.Int("project_id").Optional(),
        field.Int("rating_id").Optional(),
        field.Int("rating_report_id").Optional(),
        
        // 变体（多尺寸）
        field.String("variants_json").Optional().VarChar(4000), // {"1:1": "path1", "9:16": "path2", "16:9": "path3"}
        
        // 发布渠道
        field.String("published_channels").Optional().VarChar(1000), // 逗号分隔: twitter,telegram,wechat
        field.String("tracking_shortlink").Optional(), // 追踪短链
        
        // 内容
        field.String("card_title").Optional(),
        field.String("card_subtitle").Optional(),
        field.String("card_data_json").Optional().VarChar(4000), // 卡片数据JSON
        
        // 哈希
        field.String("card_hash").Optional(), // 卡片内容哈希
        
        // 渠道链接记录
        field.String("distribution_refs").Optional().VarChar(2000), // 分发记录引用（逗号分隔ID）
        
        // 撤回状态
        field.Bool("is_withdrawn").Default(false),
        field.Time("withdrawn_at").Optional(),
        field.String("withdrawal_reason").Optional().VarChar(1000),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"asset_id"}),
        zent.core.index.Fields(&.{"project_id"}),
        zent.core.index.Fields(&.{"rating_id"}),
    },
});

/// 分发记录
pub const DistributionRecord = Schema("distribution_records", .{
    .fields = &.{
        field.String("distribution_id").Unique(), // UUID
        field.Int("rating_id"),
        field.String("asset_id").Optional(), // 关联 content_assets.asset_id
        field.String("card_asset_hash").Optional(), // 卡片哈希快照
        
        // 渠道
        field.String("platform"), // twitter/telegram/wechat/linkedin/discord/website
        field.String("published_url").Optional().VarChar(1000), // 发布URL
        field.String("platform_post_id").Optional(), // 平台帖子ID
        
        // 操作
        field.Int("operator_id"), // 操作人 user_id
        field.Time("published_at").Optional(),
        
        // 撤回
        field.Bool("retract_requested").Default(false),
        field.Time("retract_requested_at").Optional(),
        field.Bool("retract_completed").Default(false),
        field.Time("retract_completed_at").Optional(),
        field.String("retract_method").Optional(), // delete/edit/watermark
        
        // 状态
        field.String("status").Default("published"), // published/retracted/failed
        field.String("failure_reason").Optional().VarChar(1000),
        
        // 补偿通知任务
        field.String("compensation_task_id").Optional(), // 补偿通知任务ID
        
        // 动态核验URL
        field.String("verification_url").Optional().VarChar(500),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"distribution_id"}),
        zent.core.index.Fields(&.{ "rating_id", "platform" }),
        zent.core.index.Fields(&.{"asset_id"}),
    },
});

/// 评级存证（可选链上锚定）
pub const RatingAttestation = Schema("rating_attestations", .{
    .fields = &.{
        field.Int("rating_id"),
        
        // 哈希与内容
        field.String("payload_hash"), // 内容哈希
        field.String("hash_algorithm").Default("SHA256"), // 哈希算法
        field.String("canonicalization_version").Default("v1.0"), // 规范化版本
        
        // 存证方式
        field.String("attestation_method"), // onchain/ipfs/centralized_registry
        
        // 链上信息（如适用）
        field.String("chain_name").Optional(), // ethereum/polygon等
        field.String("contract_address").Optional(), // 存证合约地址
        field.String("transaction_hash").Optional(), // 交易哈希
        field.Int("block_number").Optional(), // 区块号
        field.Time("anchored_at").Optional(), // 上链时间
        
        // IPFS（如适用）
        field.String("ipfs_cid").Optional(), // IPFS CID
        
        // 核验状态
        field.String("verification_status").Default("pending"), // pending/confirmed/failed
        field.String("verification_url").Optional().VarChar(500), // 核验链接
        
        // 元数据
        field.String("attestation_metadata").Optional().VarChar(2000), // 额外元数据JSON
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"rating_id"}),
        zent.core.index.Fields(&.{"transaction_hash"}),
    },
});

/// 渠道与短链
pub const Channel = Schema("channels", .{
    .fields = &.{
        field.String("channel_id").Unique(), // UUID
        field.String("channel_name"), // 渠道名称
        field.String("channel_type"), // social/web/bot/email/sms
        field.String("platform").Optional(), // twitter/telegram/wechat等
        
        // 短链
        field.String("short_code").Optional().Unique(), // 短链代码
        field.String("target_url").Optional().VarChar(1000), // 目标URL
        
        // UTM参数
        field.String("utm_source").Optional(),
        field.String("utm_medium").Optional(),
        field.String("utm_campaign").Optional(),
        field.String("utm_content").Optional(),
        field.String("utm_term").Optional(),
        
        // 关联
        field.Int("rating_id").Optional(),
        field.Int("content_id").Optional(),
        
        // 统计
        field.Int("click_count").Default(0),
        field.Int("unique_visitor_count").Default(0),
        
        // 状态
        field.Bool("is_active").Default(true),
        field.Time("expires_at").Optional(),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"channel_id"}),
        zent.core.index.Fields(&.{"short_code"}),
        zent.core.index.Fields(&.{"rating_id"}),
    },
});

/// 归因事件
pub const AttributionEvent = Schema("attribution_events", .{
    .fields = &.{
        field.String("event_id").Unique(), // UUID
        field.String("event_type"), // page_view/bot_start/join/pay/message等
        
        // 会话
        field.String("anonymous_session_id").Optional(), // 匿名会话ID
        field.Int("member_id").Optional(), // 关联会员（已同意）
        
        // 渠道
        field.String("channel_id").Optional(),
        field.String("utm_source").Optional(),
        field.String("utm_medium").Optional(),
        field.String("utm_campaign").Optional(),
        field.String("utm_content").Optional(),
        
        // 时间
        field.String("event_time"), // 事件时间 ISO8601
        field.String("received_at"), // 接收时间
        
        // 去重
        field.String("dedupe_key").Optional(),
        
        // 归因模型
        field.String("attribution_model").Default("last_touch"), // last_touch/first_touch
        field.String("attribution_version").Default("v1.0"),
        
        // 不可归因原因
        field.String("unknown_reason").Optional(), // cross_device/no_tracking/opt_out
        
        // 属性
        field.String("event_properties").Optional().VarChar(2000), // 事件属性JSON
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"event_id"}),
        zent.core.index.Fields(&.{ "event_type", "event_time" }),
        zent.core.index.Fields(&.{"member_id"}),
        zent.core.index.Fields(&.{"dedupe_key"}),
    },
});
