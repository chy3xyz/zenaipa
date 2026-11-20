const std = @import("std");
const zmodu = @import("zmodu");
const http = zmodu.http;
const engine = @import("engine.zig");

pub fn RatingApi(comptime Service: type) type {
    return struct {
        service: *Service,

        const Self = @This();

        pub fn init(service: *Service) Self {
            return .{ .service = service };
        }

        pub fn registerRoutes(self: *Self, group: anytype) !void {
            try group.post("ratings", create, @ptrCast(@alignCast(self)));
            try group.post("ratings/:id/submit", submit, @ptrCast(@alignCast(self)));
            try group.post("ratings/:id/review", review, @ptrCast(@alignCast(self)));
            try group.post("ratings/:id/publish", publish, @ptrCast(@alignCast(self)));
            try group.get("projects/:project_id/rating", getProjectRating, @ptrCast(@alignCast(self)));
        }

        pub fn create(self: *Self, ctx: *http.Context) !void {
            // Admin or analyst only
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const user = ctx.user() orelse return ctx.unauthorized();

            const body = try ctx.bindJson(struct {
                project_id: i64,
                tech_score: i32,
                team_score: i32,
                tokenomics_score: i32,
                community_score: i32,
                liquidity_score: i32,
                compliance_score: i32,
                coverage: i32 = 100,
                redflags: ?[]const []const u8 = null,
            });

            const dimensions = engine.RatingEngine.SixDimensions{
                .tech = body.tech_score,
                .team = body.team_score,
                .tokenomics = body.tokenomics_score,
                .community = body.community_score,
                .liquidity = body.liquidity_score,
                .compliance = body.compliance_score,
            };

            // Parse redflags
            var redflags = std.ArrayList(engine.RatingEngine.RedFlag).init(alloc);
            if (body.redflags) |flags| {
                for (flags) |flag_str| {
                    if (std.mem.eql(u8, flag_str, "R1")) try redflags.append(.R1);
                    if (std.mem.eql(u8, flag_str, "R2")) try redflags.append(.R2);
                    if (std.mem.eql(u8, flag_str, "R3")) try redflags.append(.R3);
                    if (std.mem.eql(u8, flag_str, "R4")) try redflags.append(.R4);
                    if (std.mem.eql(u8, flag_str, "R5")) try redflags.append(.R5);
                    if (std.mem.eql(u8, flag_str, "R6")) try redflags.append(.R6);
                }
            }

            const rating_id = try self.service.createRating(
                alloc,
                body.project_id,
                dimensions,
                redflags.items,
                body.coverage,
                user.id,
            );

            try ctx.json(.{
                .code = 0,
                .msg = "Rating created",
                .data = .{ .id = rating_id },
            });
        }

        pub fn submit(self: *Self, ctx: *http.Context) !void {
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const id_str = ctx.param("id") orelse return error.MissingId;
            const id = try std.fmt.parseInt(i64, id_str, 10);

            try self.service.submitForReview(alloc, id);

            try ctx.json(.{
                .code = 0,
                .msg = "Rating submitted for review",
                .data = null,
            });
        }

        pub fn review(self: *Self, ctx: *http.Context) !void {
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const user = ctx.user() orelse return ctx.unauthorized();
            const id_str = ctx.param("id") orelse return error.MissingId;
            const id = try std.fmt.parseInt(i64, id_str, 10);

            const body = try ctx.bindJson(struct {
                decision: []const u8, // approved/rejected
                analyst_person_id: i64,
                reviewer_person_id: i64,
            });

            try self.service.reviewAndSign(
                alloc,
                id,
                user.id,
                body.analyst_person_id,
                body.reviewer_person_id,
                body.decision,
            );

            try ctx.json(.{
                .code = 0,
                .msg = "Review completed",
                .data = null,
            });
        }

        pub fn publish(self: *Self, ctx: *http.Context) !void {
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const id_str = ctx.param("id") orelse return error.MissingId;
            const id = try std.fmt.parseInt(i64, id_str, 10);

            try self.service.publishRating(alloc, id);

            try ctx.json(.{
                .code = 0,
                .msg = "Rating published",
                .data = null,
            });
        }

        pub fn getProjectRating(self: *Self, ctx: *http.Context) !void {
            const alloc = ctx.arena();
            const project_id_str = ctx.param("project_id") orelse return error.MissingId;
            const project_id = try std.fmt.parseInt(i64, project_id_str, 10);

            const rating = try self.service.getLatestRating(alloc, project_id);

            if (rating == null) {
                return ctx.json(.{
                    .code = 404,
                    .msg = "No rating found",
                    .data = null,
                });
            }

            try ctx.json(.{
                .code = 0,
                .msg = "success",
                .data = rating,
            });
        }
    };
}
