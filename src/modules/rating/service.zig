const std = @import("std");
const zent = @import("zent");
const persistence = @import("persistence.zig");
const engine = @import("engine.zig");
const RatingStore = persistence.RatingStore;
const RatingEngine = engine.RatingEngine;

/// 评级服务错误
pub const RatingServiceError = error{
    SelfReviewNotAllowed,
    RatingNotFound,
    InvalidStatus,
    PublishGateFailed,
    MethodVersionNotFound,
    ReportNotFound,
};

pub const RatingService = struct {
    store: *RatingStore,

    pub fn init(store: *RatingStore) RatingService {
        return .{ .store = store };
    }

    /// 创建评级
    pub fn createRating(
        self: *RatingService,
        alloc: std.mem.Allocator,
        project_id: i64,
        dimensions: RatingEngine.SixDimensions,
        redflags: []const RatingEngine.RedFlag,
        coverage: i32,
        analyst_id: i64,
    ) !i64 {
        // 1. 获取默认方法论版本
        const method = try self.store.getDefaultMethodVersion(alloc) orelse {
            return error.NoMethodVersionFound;
        };

        // 2. 计算评级
        const weights = RatingEngine.DefaultWeights{};
        const thresholds = RatingEngine.GradeThresholds{};

        const result = try RatingEngine.calculateRating(
            alloc,
            dimensions,
            weights,
            thresholds,
            redflags,
            coverage,
        );

        // 3. 生成快照ID（简化版）
        const snapshot_id = try std.fmt.allocPrint(
            alloc,
            "snap_{d}_{d}",
            .{ project_id, std.time.timestamp() },
        );

        // 4. 保存评级
        const rating_id = try self.store.createRating(alloc, .{
            .project_id = project_id,
            .snapshot_id = snapshot_id,
            .tech_score = dimensions.tech,
            .team_score = dimensions.team,
            .tokenomics_score = dimensions.tokenomics,
            .community_score = dimensions.community,
            .liquidity_score = dimensions.liquidity,
            .compliance_score = dimensions.compliance,
            .base_score = result.base_score,
            .base_grade = result.base_grade,
            .redflag_grade = result.redflag_grade,
            .shadow_grade = result.shadow_grade,
            .published_grade = "", // 未发布
            .confidence_six = result.confidence_six,
            .method_version = method.method_version,
            .status = "draft",
            .analyst_id = analyst_id,
        });

        return rating_id;
    }

    /// 提交复核
    pub fn submitForReview(
        self: *RatingService,
        alloc: std.mem.Allocator,
        rating_id: i64,
    ) !void {
        const success = try self.store.updateRatingStatus(alloc, rating_id, "submitted");
        if (!success) {
            return error.RatingNotFound;
        }
    }

    /// 复核签发 - 强制双人校验
    pub fn reviewAndSign(
        self: *RatingService,
        alloc: std.mem.Allocator,
        rating_id: i64,
        reviewer_id: i64,
        analyst_id: i64, // 实际使用 user_id，不是 person_id
        decision: []const u8,
    ) !void {
        // 1. 获取评级
        const rating = try self.store.getRatingById(alloc, rating_id) orelse {
            return RatingServiceError.RatingNotFound;
        };
        defer alloc.free(rating);

        // 2. 验证状态
        if (!std.mem.eql(u8, rating.status, "submitted")) {
            return RatingServiceError.InvalidStatus;
        }

        // 3. 验证不是同一用户自签（简化版：只检查 user_id）
        if (analyst_id == reviewer_id) {
            return RatingServiceError.SelfReviewNotAllowed;
        }

        // 4. 记录当前时间
        const now = std.time.timestamp();
        const now_iso = try std.fmt.allocPrint(alloc, "{d}", .{now});
        defer alloc.free(now_iso);

        // 5. 创建复核记录
        _ = try self.store.createReview(alloc, .{
            .rating_id = rating_id,
            .analyst_person_id = analyst_id, // 简化：使用 user_id
            .reviewer_person_id = reviewer_id,
            .decision = decision,
            .reviewed_at = now_iso,
        });

        // 6. 更新评级状态和复核人
        if (std.mem.eql(u8, decision, "approved")) {
            _ = try zent.codegen.crud_helpers.updateById(
                self.store.client,
                alloc,
                persistence.RatingInfo,
                rating_id,
                .{
                    .status = "approved",
                    .reviewer_id = reviewer_id,
                },
            );
        } else if (std.mem.eql(u8, decision, "rejected")) {
            // 驳回回到 draft
            _ = try self.store.updateRatingStatus(alloc, rating_id, "draft");
        }
    }

    /// 发布评级 - 包含合规门禁检查
    pub fn publishRating(
        self: *RatingService,
        alloc: std.mem.Allocator,
        rating_id: i64,
        compliance_service: anytype, // *ComplianceService
        report: anytype, // RatingReport
    ) !void {
        // 1. 获取评级
        const rating = try self.store.getRatingById(alloc, rating_id) orelse {
            return RatingServiceError.RatingNotFound;
        };
        defer alloc.free(rating);

        // 2. 验证状态必须是 approved
        if (!std.mem.eql(u8, rating.status, "approved")) {
            return RatingServiceError.InvalidStatus;
        }

        // 3. 合规门禁检查（C1/C2/C12）
        const gate_result = try compliance_service.checkPublishable(alloc, rating, report);
        defer gate_result.deinit(alloc);

        if (!gate_result.passed) {
            std.log.err("发布门禁检查失败: {s}", .{gate_result.violations[0]});
            return RatingServiceError.PublishGateFailed;
        }

        // 4. NR 不应发布（置信度检查）
        if (std.mem.eql(u8, rating.base_grade, "NR")) {
            std.log.err("评级为 NR（数据不足），不应发布", .{});
            return RatingServiceError.PublishGateFailed;
        }

        // 5. 记录发布时间
        const now = std.time.timestamp();
        const now_iso = try std.fmt.allocPrint(alloc, "{d}", .{now});
        defer alloc.free(now_iso);

        // 6. 更新状态和发布档位
        _ = try zent.codegen.crud_helpers.updateById(
            self.store.client,
            alloc,
            persistence.RatingInfo,
            rating_id,
            .{
                .status = "published",
                .published_grade = rating.redflag_grade, // W1-W6: published = redflag
                .published_at = now_iso,
            },
        );
    }

    /// 获取项目最新评级
    pub fn getLatestRating(
        self: *RatingService,
        alloc: std.mem.Allocator,
        project_id: i64,
    ) !?persistence.RatingRow {
        return try self.store.getLatestRatingForProject(alloc, project_id);
    }
};
