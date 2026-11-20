const std = @import("std");
const zmodu = @import("zmodu");
const zent = @import("zent");
const http = zmodu.http;
const rating_engine_mod = @import("../rating/engine.zig");
const RatingEngine = rating_engine_mod.RatingEngine;
const RedFlag = RatingEngine.RedFlag;
const rating_repository = @import("rating_repository.zig");
const proj_repository = @import("repository.zig");

pub const RatingAPI = struct {
    allocator: std.mem.Allocator,
    sqlite_driver: *zent.sql_sqlite.SQLiteDriver,
    sec: *zmodu.security.AppSecurity,

    pub fn init(allocator: std.mem.Allocator, sqlite_driver: *zent.sql_sqlite.SQLiteDriver, sec: *zmodu.security.AppSecurity) RatingAPI {
        return .{
            .allocator = allocator,
            .sqlite_driver = sqlite_driver,
            .sec = sec,
        };
    }

    pub fn registerRoutes(self: *RatingAPI, router: anytype) !void {
        // 挂载JWT中间件
        var g = try router.use(zmodu.http.http_middleware.jwtAuthWithSecurity(&self.sec.module));
        
        try g.post("projects/{id}/ratings", handleCreateDraft, @ptrCast(@alignCast(self)));
        try g.get("projects/{id}/ratings/{rating_id}", handleGetDraft, @ptrCast(@alignCast(self)));
        try g.post("projects/{id}/ratings/{rating_id}/submit", handleSubmit, @ptrCast(@alignCast(self)));
        try g.post("projects/{id}/ratings/{rating_id}/approve", handleApprove, @ptrCast(@alignCast(self)));
        try g.post("projects/{id}/ratings/{rating_id}/reject", handleReject, @ptrCast(@alignCast(self)));
    }
};

fn handleCreateDraft(ctx: *http.Context) !void {
    const self: *RatingAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    // 鉴权：必须管理员
    const user_id_str = ctx.getAttr("user_id") orelse {
        try ctx.json(401, "{\"error\":\"Unauthorized\"}");
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        try ctx.json(401, "{\"error\":\"Invalid user ID\"}");
        return;
    };

    if (!checkAdminPermission(ctx, user_id)) {
        try ctx.json(403, "{\"error\":\"Forbidden: admin required\"}");
        return;
    }

    // 读项目ID
    const project_id = ctx.paramInt(i64, "id") catch {
        try ctx.json(400, "{\"error\":\"Invalid project ID\"}");
        return;
    };

    // 验证项目存在
    var proj_repo = proj_repository.ProjectRepository.init(self.allocator, self.sqlite_driver);
    const project_opt = try proj_repo.getById(project_id);
    if (project_opt == null) {
        try ctx.json(404, "{\"error\":\"Project not found\"}");
        return;
    }

    // 解析输入JSON
    const body = ctx.body orelse {
        try ctx.json(400, "{\"error\":\"Missing body\"}");
        return;
    };
    const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        try ctx.json(400, "{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) {
        try ctx.json(400, "{\"error\":\"Expected JSON object\"}");
        return;
    }

    const obj = root.object;
    
    // 读取输入维度
    var c1_tech: ?i64 = null;
    var c2_team: ?i64 = null;
    var c3_token: ?i64 = null;
    var c4_product: ?i64 = null;
    var c5_community: ?i64 = null;
    var c6_governance: ?i64 = null;

    if (obj.get("c1_tech")) |v| {
        if (v == .integer) c1_tech = @intCast(v.integer);
    }
    if (obj.get("c2_team")) |v| {
        if (v == .integer) c2_team = @intCast(v.integer);
    }
    if (obj.get("c3_token")) |v| {
        if (v == .integer) c3_token = @intCast(v.integer);
    }
    if (obj.get("c4_product")) |v| {
        if (v == .integer) c4_product = @intCast(v.integer);
    }
    if (obj.get("c5_community")) |v| {
        if (v == .integer) c5_community = @intCast(v.integer);
    }
    if (obj.get("c6_governance")) |v| {
        if (v == .integer) c6_governance = @intCast(v.integer);
    }

    // 解析red_flags数组 - 简化为直接从输入读取字符串
    const red_flags_str_input = if (obj.get("red_flags")) |rf| blk: {
        if (rf == .string) {
            break :blk rf.string;
        } else {
            break :blk "";
        }
    } else "";
    
    // 假设red_flags为空（MVP简化）
    const red_flags_list: []const RatingEngine.RedFlag = &[_]RatingEngine.RedFlag{};

    // 构建六维分数
    const dimensions = RatingEngine.SixDimensions{
        .tech = @intCast(c1_tech orelse 0),
        .team = @intCast(c2_team orelse 0),
        .tokenomics = @intCast(c3_token orelse 0),
        .community = @intCast(c5_community orelse 0),
        .liquidity = @intCast(c4_product orelse 0),
        .compliance = @intCast(c6_governance orelse 0),
    };
    
    // 调用引擎计算基础分
    const base_score = RatingEngine.calculateBaseScore(dimensions, RatingEngine.DefaultWeights{});
    const base_grade_str = RatingEngine.scoreToGrade(base_score, RatingEngine.GradeThresholds{});
    const redflag_grade_str = RatingEngine.applyRedFlags(base_grade_str, red_flags_list);
    
    // 计算覆盖率和置信度
    var coverage_count: i32 = 0;
    if (c1_tech != null) coverage_count += 1;
    if (c2_team != null) coverage_count += 1;
    if (c3_token != null) coverage_count += 1;
    if (c4_product != null) coverage_count += 1;
    if (c5_community != null) coverage_count += 1;
    if (c6_governance != null) coverage_count += 1;
    
    const coverage_pct = @divTrunc(coverage_count * 100, 6);
    const confidence: i32 = if (coverage_pct >= 60) coverage_pct else 0;

    // 序列化red_flags为字符串 (MVP: 简化为空数组或从输入读取)
    const red_flags_str: ?[]const u8 = if (red_flags_str_input.len > 0) red_flags_str_input else null;

    // 序列化input_json
    const input_json = try std.fmt.allocPrint(self.allocator,
        \\{{"c1_tech":{?d},"c2_team":{?d},"c3_token":{?d},"c4_product":{?d},"c5_community":{?d},"c6_governance":{?d},"red_flags":{s}}}
    , .{
        c1_tech,
        c2_team,
        c3_token,
        c4_product,
        c5_community,
        c6_governance,
        red_flags_str orelse "[]",
    });
    defer self.allocator.free(input_json);

    // 保存到数据库
    var rating_repo = rating_repository.RatingRepository.init(self.sqlite_driver, self.allocator);
    
    const rating_id = try rating_repo.create(.{
        .project_id = project_id,
        .model_version = "v1.0",
        .input_json = input_json,
        .c1_tech = c1_tech,
        .c2_team = c2_team,
        .c3_token = c3_token,
        .c4_product = c4_product,
        .c5_community = c5_community,
        .c6_governance = c6_governance,
        .confidence = @intCast(confidence),
        .red_flags = red_flags_str,
        .base_grade = base_grade_str,
        .redflag_grade = redflag_grade_str,
        .shadow_grade = redflag_grade_str,
        .published_grade = if (confidence >= 60) redflag_grade_str else "NR",
        .analyst_id = user_id,
    });
    
    // Add create audit
    try rating_repo.addAudit(.{
        .rating_id = rating_id,
        .actor_id = user_id,
        .action = "create",
        .from_status = null,
        .to_status = "draft",
        .revision = 1,
        .comment = null,
    });

    // 返回结果
    const published = if (confidence >= 60) redflag_grade_str else "NR";
    const response_json = try std.fmt.allocPrint(self.allocator,
        \\{{"id":{d},"project_id":{d},"confidence":{d},"base_grade":"{s}","redflag_grade":"{s}","shadow_grade":"{s}","published_grade":"{s}","is_draft":true}}
    , .{
        rating_id,
        project_id,
        confidence,
        base_grade_str,
        redflag_grade_str,
        redflag_grade_str,
        published,
    });
    defer self.allocator.free(response_json);

    try ctx.json(201, response_json);
}

fn handleGetDraft(ctx: *http.Context) !void {
    const self: *RatingAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    const user_id_str = ctx.getAttr("user_id") orelse {
        try ctx.json(401, "{\"error\":\"Unauthorized\"}");
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        try ctx.json(401, "{\"error\":\"Invalid user ID\"}");
        return;
    };

    if (!checkAdminPermission(ctx, user_id)) {
        try ctx.json(403, "{\"error\":\"Forbidden: admin required\"}");
        return;
    }

    const project_id = ctx.paramInt(i64, "id") catch {
        try ctx.json(400, "{\"error\":\"Invalid project ID\"}");
        return;
    };
    
    const rating_id = ctx.paramInt(i64, "rating_id") catch {
        try ctx.json(400, "{\"error\":\"Invalid rating ID\"}");
        return;
    };

    var rating_repo = rating_repository.RatingRepository.init(self.sqlite_driver, self.allocator);
    const rating_opt = try rating_repo.getByIdAndProject(rating_id, project_id);
    
    if (rating_opt) |rating| {
        const rf_str = rating.red_flags orelse "null";
        const response_json = try std.fmt.allocPrint(self.allocator,
            \\{{"id":{d},"project_id":{d},"model_version":"{s}","c1_tech":{?d},"c2_team":{?d},"c3_token":{?d},"c4_product":{?d},"c5_community":{?d},"c6_governance":{?d},"confidence":{d},"red_flags":{s},"base_grade":"{s}","redflag_grade":"{s}","shadow_grade":"{s}","published_grade":"{s}","analyst_id":{d},"reviewer_id":{?d},"status":"{s}","revision":{d},"created_at":{d}}}
        , .{
            rating.id,
            rating.project_id,
            rating.model_version,
            rating.c1_tech,
            rating.c2_team,
            rating.c3_token,
            rating.c4_product,
            rating.c5_community,
            rating.c6_governance,
            rating.confidence,
            rf_str,
            rating.base_grade,
            rating.redflag_grade,
            rating.shadow_grade,
            rating.published_grade,
            rating.analyst_id,
            rating.reviewer_id,
            rating.status,
            rating.revision,
            rating.created_at,
        });
        defer self.allocator.free(response_json);
        try ctx.json(200, response_json);
    } else {
        try ctx.json(404, "{\"error\":\"Rating not found for this project\"}");
    }
}

fn checkAdminPermission(ctx: *http.Context, user_id: i64) bool {
    _ = user_id;
    const roles_csv = ctx.getAttr("roles") orelse return false;
    
    // roles是CSV字符串，必须exact match "admin"，不能是substring如"notadmin"
    var iter = std.mem.splitScalar(u8, roles_csv, ',');
    while (iter.next()) |role| {
        const trimmed = std.mem.trim(u8, role, " \t\r\n");
        // Exact match only - "admin" != "notadmin"
        if (trimmed.len == 5 and std.mem.eql(u8, trimmed, "admin")) {
            return true;
        }
    }
    return false;
}

fn handleSubmit(ctx: *http.Context) !void {
    const self: *RatingAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    // Get authenticated user
    const user_id_str = ctx.getAttr("user_id") orelse {
        try ctx.json(401, "{\"error\":\"Unauthorized\"}");
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        try ctx.json(401, "{\"error\":\"Invalid user ID\"}");
        return;
    };
    
    // Only admin or analyst can submit
    if (!checkAdminPermission(ctx, user_id)) {
        try ctx.json(403, "{\"error\":\"Forbidden: admin required\"}");
        return;
    }
    
    const rating_id = ctx.paramInt(i64, "rating_id") catch {
        try ctx.json(400, "{\"error\":\"Invalid rating ID\"}");
        return;
    };
    
    var rating_repo = rating_repository.RatingRepository.init(self.sqlite_driver, self.allocator);
    
    // Submit with CAS (only analyst can submit their own draft)
    const success = try rating_repo.submit(rating_id, user_id);
    if (!success) {
        try ctx.json(409, "{\"error\":\"Cannot submit: not draft status or not analyst\"}");
        return;
    }
    
    // Add audit
    try rating_repo.addAudit(.{
        .rating_id = rating_id,
        .actor_id = user_id,
        .action = "submit",
        .from_status = "draft",
        .to_status = "submitted",
        .revision = 1,
        .comment = null,
    });
    
    try ctx.json(200, "{\"message\":\"Rating submitted\"}");
}

fn handleApprove(ctx: *http.Context) !void {
    const self: *RatingAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    const user_id_str = ctx.getAttr("user_id") orelse {
        try ctx.json(401, "{\"error\":\"Unauthorized\"}");
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        try ctx.json(401, "{\"error\":\"Invalid user ID\"}");
        return;
    };
    
    // Only admin can review
    if (!checkAdminPermission(ctx, user_id)) {
        try ctx.json(403, "{\"error\":\"Forbidden: reviewer permission required\"}");
        return;
    }
    
    const rating_id = ctx.paramInt(i64, "rating_id") catch {
        try ctx.json(400, "{\"error\":\"Invalid rating ID\"}");
        return;
    };
    
    var rating_repo = rating_repository.RatingRepository.init(self.sqlite_driver, self.allocator);
    
    // First check self-review explicitly (403 Forbidden)
    const is_self_review = try rating_repo.isSelfReview(rating_id, user_id);
    if (is_self_review) {
        try ctx.json(403, "{\"error\":\"Forbidden: cannot review own rating\"}");
        return;
    }
    
    // Approve with CAS (prevents invalid state transition and duplicates)
    const success = try rating_repo.approve(rating_id, user_id);
    if (!success) {
        try ctx.json(409, "{\"error\":\"Cannot approve: not submitted or already reviewed\"}");
        return;
    }
    
    // Add audit (TODO: in same transaction)
    try rating_repo.addAudit(.{
        .rating_id = rating_id,
        .actor_id = user_id,
        .action = "approve",
        .from_status = "submitted",
        .to_status = "approved",
        .revision = 1,
        .comment = null,
    });
    
    try ctx.json(200, "{\"message\":\"Rating approved\"}");
}

fn handleReject(ctx: *http.Context) !void {
    const self: *RatingAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    const user_id_str = ctx.getAttr("user_id") orelse {
        try ctx.json(401, "{\"error\":\"Unauthorized\"}");
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        try ctx.json(401, "{\"error\":\"Invalid user ID\"}");
        return;
    };
    
    // Only admin can review
    if (!checkAdminPermission(ctx, user_id)) {
        try ctx.json(403, "{\"error\":\"Forbidden: reviewer permission required\"}");
        return;
    }
    
    const rating_id = ctx.paramInt(i64, "rating_id") catch {
        try ctx.json(400, "{\"error\":\"Invalid rating ID\"}");
        return;
    };
    
    var rating_repo = rating_repository.RatingRepository.init(self.sqlite_driver, self.allocator);
    
    // First check self-review explicitly (403 Forbidden)
    const is_self_review = try rating_repo.isSelfReview(rating_id, user_id);
    if (is_self_review) {
        try ctx.json(403, "{\"error\":\"Forbidden: cannot review own rating\"}");
        return;
    }
    
    // Reject with CAS (prevents invalid state transition and duplicates)
    const success = try rating_repo.reject(rating_id, user_id);
    if (!success) {
        try ctx.json(409, "{\"error\":\"Cannot reject: not submitted or already reviewed\"}");
        return;
    }
    
    // Add audit (TODO: in same transaction)
    try rating_repo.addAudit(.{
        .rating_id = rating_id,
        .actor_id = user_id,
        .action = "reject",
        .from_status = "submitted",
        .to_status = "rejected",
        .revision = 1,
        .comment = null,
    });
    
    try ctx.json(200, "{\"message\":\"Rating rejected\"}");
}
