const std = @import("std");
const persistence = @import("persistence.zig");
const engine = @import("engine.zig");
const RatingStore = persistence.RatingStore;
const RatingEngine = engine.RatingEngine;

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

    /// 复核签发
    pub fn reviewAndSign(
        self: *RatingService,
        alloc: std.mem.Allocator,
        rating_id: i64,
        reviewer_id: i64,
        analyst_person_id: i64,
        reviewer_person_id: i64,
        decision: []const u8,
    ) !void {
        // 1. 验证不同自然人
        if (analyst_person_id == reviewer_person_id) {
            return error.SelfReviewNotAllowed;
        }

        // 2. 创建复核记录
        _ = try self.store.createReview(alloc, .{
            .rating_id = rating_id,
            .analyst_person_id = analyst_person_id,
            .reviewer_person_id = reviewer_person_id,
            .decision = decision,
        });

        // 3. 更新评级状态
        if (std.mem.eql(u8, decision, "approved")) {
            _ = try self.store.updateRatingStatus(alloc, rating_id, "approved");
        } else {
            _ = try self.store.updateRatingStatus(alloc, rating_id, "draft");
        }
    }

    /// 发布评级
    pub fn publishRating(
        self: *RatingService,
        alloc: std.mem.Allocator,
        rating_id: i64,
    ) !void {
        // TODO: 检查合规开关（C1/C2/C12）

        // 更新状态和发布档位
        const rating = try self.store.getRatingById(alloc, rating_id) orelse {
            return error.RatingNotFound;
        };

        _ = try self.store.updateRatingStatus(alloc, rating_id, "published");
        // TODO: 更新 published_grade = redflag_grade
        _ = rating;
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
