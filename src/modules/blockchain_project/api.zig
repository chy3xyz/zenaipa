const std = @import("std");
const zmodu = @import("zmodu");
const http = zmodu.http;

pub fn BlockchainProjectApi(comptime Service: type) type {
    return struct {
        service: *Service,

        const Self = @This();

        pub fn init(service: *Service) Self {
            return .{ .service = service };
        }

        pub fn registerRoutes(self: *Self, router: anytype) !void {
            try router.get("/api/v1/blockchain/projects", http.handler(Self, "list", self));
            try router.get("/api/v1/blockchain/projects/:id", http.handler(Self, "get", self));
            try router.post("/api/v1/blockchain/projects", http.handler(Self, "create", self));
            try router.put("/api/v1/blockchain/projects/:id", http.handler(Self, "update", self));
            try router.delete("/api/v1/blockchain/projects/:id", http.handler(Self, "delete", self));
            try router.post("/api/v1/blockchain/projects/import/csv", http.handler(Self, "importCsv", self));
        }

        pub fn list(self: *Self, ctx: *http.Context) !void {
            const alloc = ctx.arena();

            const limit = ctx.queryInt("limit", 20) catch 20;
            const offset = ctx.queryInt("offset", 0) catch 0;
            const sector = ctx.query("sector");
            const status = ctx.query("status");
            const keyword = ctx.query("keyword");

            const result = try self.service.listProjects(alloc, .{
                .limit = limit,
                .offset = offset,
                .sector = sector,
                .status = status,
                .keyword = keyword,
            });

            try ctx.json(.{
                .code = 0,
                .msg = "success",
                .data = .{
                    .items = result.items,
                    .total = result.total,
                },
            });
        }

        pub fn get(self: *Self, ctx: *http.Context) !void {
            const alloc = ctx.arena();
            const id_str = ctx.param("id") orelse return error.MissingId;
            const id = try std.fmt.parseInt(i64, id_str, 10);

            const project = try self.service.getProject(alloc, id);
            if (project == null) {
                return ctx.json(.{
                    .code = 404,
                    .msg = "Project not found",
                    .data = null,
                });
            }

            try ctx.json(.{
                .code = 0,
                .msg = "success",
                .data = project,
            });
        }

        pub fn create(self: *Self, ctx: *http.Context) !void {
            // Admin only
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const body = try ctx.bindJson(struct {
                name: []const u8,
                slug: []const u8,
                description: ?[]const u8 = null,
                sector: []const u8 = "Other",
                official_url: ?[]const u8 = null,
                twitter_url: ?[]const u8 = null,
            });

            const id = try self.service.createProject(alloc, body);

            try ctx.json(.{
                .code = 0,
                .msg = "Project created",
                .data = .{ .id = id },
            });
        }

        pub fn update(self: *Self, ctx: *http.Context) !void {
            // Admin only
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const id_str = ctx.param("id") orelse return error.MissingId;
            const id = try std.fmt.parseInt(i64, id_str, 10);

            const body = try ctx.bindJsonLoose();
            const success = try self.service.updateProject(alloc, id, body);

            if (!success) {
                return ctx.json(.{
                    .code = 404,
                    .msg = "Project not found",
                    .data = null,
                });
            }

            try ctx.json(.{
                .code = 0,
                .msg = "Project updated",
                .data = null,
            });
        }

        pub fn delete(self: *Self, ctx: *http.Context) !void {
            // Admin only
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const id_str = ctx.param("id") orelse return error.MissingId;
            const id = try std.fmt.parseInt(i64, id_str, 10);

            const success = try self.service.deleteProject(alloc, id);

            if (!success) {
                return ctx.json(.{
                    .code = 404,
                    .msg = "Project not found",
                    .data = null,
                });
            }

            try ctx.json(.{
                .code = 0,
                .msg = "Project deleted",
                .data = null,
            });
        }

        pub fn importCsv(self: *Self, ctx: *http.Context) !void {
            // Admin only
            if (!ctx.isAdmin()) {
                return ctx.unauthorized();
            }

            const alloc = ctx.arena();
            const body = try ctx.bindJson(struct {
                csv_data: []const u8,
            });

            const result = try self.service.importFromCsv(alloc, body.csv_data);

            try ctx.json(.{
                .code = 0,
                .msg = "Import completed",
                .data = result,
            });
        }
    };
}
