const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 数据源配置
pub const DataSource = Schema("data_sources", .{
    .fields = &.{
        field.String("source_id").Unique(), // 源标识: coingecko/defillama/github等
        field.String("provider_name"), // 提供商名称
        field.String("source_type").Default("api"), // api/scraper/manual/csv
        
        // 连接信息
        field.String("endpoint_url").Optional().VarChar(500),
        field.String("api_key_encrypted").Optional().VarChar(500), // 加密的API密钥
        
        // 授权与限制
        field.String("license_type").Optional(), // 许可类型
        field.Bool("allow_commercial").Default(false), // 是否允许商用
        field.Bool("allow_redistribution").Default(false), // 是否允许再分发
        field.String("usage_limit").Optional(), // 使用限制描述
        
        // 可靠性
        field.String("reliability_tier").Default("unverified"), // verified/trusted/unverified
        field.String("supported_fields").Optional().VarChar(1000), // 支持的字段（逗号分隔）
        
        // 更新频率
        field.String("update_frequency").Default("daily"), // realtime/hourly/daily/weekly/manual
        field.Int("rate_limit_per_minute").Default(60),
        
        // 失效策略
        field.String("failure_strategy").Default("retry"), // retry/skip/alert/manual
        field.Int("max_retries").Default(3),
        field.Int("retry_delay_seconds").Default(60),
        
        // 状态
        field.String("status").Default("active"), // active/inactive/deprecated
        field.Time("last_checked_at").Optional(),
        field.String("last_error").Optional().VarChar(1000),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"source_id"}),
        zent.core.index.Fields(&.{"status"}),
    },
});

/// 原始观测数据（只追加，不修改）
pub const RawObservation = Schema("raw_observations", .{
    .fields = &.{
        field.String("observation_id").Unique(), // UUID
        field.String("source_id"), // 关联 data_sources.source_id
        field.Int("project_id").Optional(),
        
        // 时间戳（三个时间点）
        field.String("observed_at"), // 事实时点 ISO8601
        field.String("ingested_at"), // 系统接收时点
        field.String("fetched_at"), // 实际抓取时点
        
        // 原始数据
        field.String("raw_payload_ref").Optional().VarChar(1000), // 大payload存储引用
        field.String("payload_hash"), // payload哈希
        field.String("raw_json").Optional().VarChar(8000), // 小payload可直接存
        
        // HTTP状态
        field.Int("http_status").Optional(),
        field.String("http_error").Optional().VarChar(500),
        
        // 数据元信息
        field.String("unit").Optional(), // 单位
        field.String("currency").Optional(), // 币种
        field.String("period_start").Optional(), // 统计周期开始
        field.String("period_end").Optional(), // 统计周期结束
        field.String("chain_block").Optional(), // 链上区块高度
        
        // 质量
        field.String("data_quality").Default("unknown"), // good/medium/poor/unknown
        field.String("quality_notes").Optional().VarChar(500),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{"observation_id"}),
        zent.core.index.Fields(&.{ "project_id", "observed_at" }),
        zent.core.index.Fields(&.{"source_id"}),
    },
});

/// 指标值（自动+人工覆盖双值记录）
pub const MetricValue = Schema("metric_values", .{
    .fields = &.{
        field.String("metric_code"), // 指标代码: market_cap/tvl/github_commits等
        field.Int("project_id"),
        field.String("observation_id").Optional(), // 关联 raw_observations.observation_id
        
        // 自动值
        field.String("auto_value").Optional(), // 自动采集的值
        field.String("auto_unit").Optional(),
        field.String("auto_quality").Default("unknown"),
        
        // 人工覆盖
        field.Int("manual_override_id").Optional(), // 人工覆盖记录ID
        field.String("manual_value").Optional(), // 人工设置的值
        field.String("manual_reason").Optional().VarChar(1000), // 覆盖原因
        field.Int("approved_by").Optional(), // 批准人 user_id
        field.Time("approved_at").Optional(),
        
        // 有效值引用
        field.String("effective_value_ref"), // 指向实际使用的值（auto或manual）
        field.String("effective_value"), // 实际使用的值
        
        // 有效期
        field.Time("valid_from").Optional(),
        field.Time("valid_to").Optional(),
        
        // 版本链
        field.Int("supersedes_id").Optional(), // 替代的旧记录ID
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "project_id", "metric_code" }),
        zent.core.index.Fields(&.{"observation_id"}),
    },
});

/// 采集任务
pub const CollectionJob = Schema("collection_jobs", .{
    .fields = &.{
        field.String("job_id").Unique(), // UUID
        field.Int("project_id").Optional(),
        field.String("source_id"), // 关联 data_sources.source_id
        
        // 任务范围
        field.String("metric_scope").Optional().VarChar(500), // 要采集的指标（逗号分隔）
        field.String("schedule_tier").Default("daily"), // realtime/hourly/daily/weekly/manual
        
        // 调度
        field.String("scheduled_at").Optional(), // 计划执行时间
        field.String("started_at").Optional(), // 实际开始时间
        field.String("completed_at").Optional(), // 完成时间
        
        // 状态
        field.String("status").Default("pending"), // pending/running/completed/failed/cancelled
        field.Int("attempt").Default(1), // 第几次尝试
        field.String("dedupe_key").Optional(), // 去重键
        
        // 结果
        field.Int("success_count").Default(0), // 成功条数
        field.Int("expected_count").Optional(), // 预期条数
        field.String("error_code").Optional(),
        field.String("error_message").Optional().VarChar(2000),
        
        // 异常处理
        field.Bool("needs_manual_review").Default(false), // 需要人工复核
        field.String("review_note").Optional().VarChar(1000),
        
        field.Int("tenant_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
    .indexes = &.{
        zent.core.index.Fields(&.{ "status", "scheduled_at" }),
        zent.core.index.Fields(&.{"project_id"}),
        zent.core.index.Fields(&.{"dedupe_key"}),
    },
});
