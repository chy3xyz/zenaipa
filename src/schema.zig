//! Shared zent schema graph for the whole application.
//!
//! Every module registers its schemas here so a single `StoreEnv` can
//! migrate the full schema and expose one type-safe client to all stores
//! (zmodu + zent best practice: one client, schema-as-code in one place).

const zent = @import("zent");

const user_model = @import("modules/user/model.zig");
const task_model = @import("modules/task/model.zig");
const file_model = @import("modules/file/model.zig");
const notify_model = @import("modules/notify/model.zig");
const tenant_model = @import("modules/tenant/model.zig");
const audit_model = @import("modules/audit/model.zig");
const mail_template_model = @import("modules/mail_template/model.zig");
const ai_model = @import("modules/ai/model.zig");

// Blockchain rating system modules
const blockchain_project_model = @import("modules/blockchain_project/model.zig");
const rating_model = @import("modules/rating/model.zig");
const data_collection_model = @import("modules/data_collection/model.zig");
const compliance_model = @import("modules/compliance/model.zig");
const three_source_model = @import("modules/three_source/model.zig");
const report_model = @import("modules/report/model.zig");

// One graph for every table (zent v0.29.4+ raises the comptime branch quota
// to 1M — measured to fit 400 tables per buildGraph, see zent docs/UPGRADING.md
// §7a). Splitting graphs is stale guidance and blocks cross-graph WithEdge.
const graph = zent.codegen.graph.buildGraph(&.{
    tenant_model.Tenant,
    user_model.User,
    user_model.PasswordToken,
    user_model.EmailVerification,
    task_model.Task,
    file_model.File,
    notify_model.Notification,
    audit_model.AuditLog,
    mail_template_model.EmailTemplate,
    ai_model.AiProvider,
    ai_model.AiSession,
    ai_model.AiMessage,
    ai_model.AiApproval,
    ai_model.AiRun,

    // Blockchain rating system tables
    // Project management
    blockchain_project_model.Project,
    blockchain_project_model.ProjectContract,
    blockchain_project_model.TokenMetric,
    blockchain_project_model.TeamMember,
    blockchain_project_model.FundingRound,
    blockchain_project_model.UnlockEvent,
    blockchain_project_model.ProjectTag,

    // Rating engine
    rating_model.MethodVersion,
    rating_model.RatingInputSnapshot,
    rating_model.Rating,
    rating_model.DimensionEvidence,
    rating_model.RatingReview,
    rating_model.RatingChange,

    // Data collection
    data_collection_model.DataSource,
    data_collection_model.RawObservation,
    data_collection_model.MetricValue,
    data_collection_model.CollectionJob,

    // Compliance
    compliance_model.ComplianceConfig,
    compliance_model.ComplianceDecision,
    compliance_model.CorrectionCase,
    compliance_model.ConflictDisclosure,

    // Three source (shadow, W7+ activation)
    three_source_model.Claim,
    three_source_model.ClaimVerification,
    three_source_model.RoadmapCommitment,
    three_source_model.GovernanceProposal,
    three_source_model.RevenueBreakdown,
    three_source_model.Principle,
    three_source_model.TccConflict,
    three_source_model.ProjectStage,
    three_source_model.ThreeSourceAssessment,
    three_source_model.CoherenceAssessment,

    // Report & distribution
    report_model.RatingReport,
    report_model.ContentAsset,
    report_model.DistributionRecord,
    report_model.RatingAttestation,
    report_model.Channel,
    report_model.AttributionEvent,
});

pub const infos = graph.types;
pub const Client = zent.codegen.client.Client(infos);
