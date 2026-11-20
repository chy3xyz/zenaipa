const std = @import("std");
const zmodu = @import("zmodu");
const http = zmodu.http;
const mw = @import("../../middleware/auth.zig");

// 权限检查辅助函数：检查roles CSV中是否包含"admin"
fn checkAdminPermission(ctx: *http.Context, user_id: i64) bool {
    _ = user_id;
    const roles_csv = ctx.getAttr("roles") orelse return false;
    
    // roles是CSV字符串，例如 "user" 或 "user,admin" 或 "admin"
    var iter = std.mem.splitScalar(u8, roles_csv, ',');
    while (iter.next()) |role| {
        const trimmed = std.mem.trim(u8, role, " \t");
        if (std.mem.eql(u8, trimmed, "admin")) {
            return true;
        }
    }
    return false;
}

pub fn ProjectApi(comptime Service: type) type {
    return struct {
        service: *Service,

        const Self = @This();

        pub fn init(service: *Service) Self {
            return .{ .service = service };
        }

        pub fn registerRoutes(self: *Self, group: anytype) !void {
            try group.get("projects", listProjects, @ptrCast(@alignCast(self)));
            try group.get("projects/{id}", getProject, @ptrCast(@alignCast(self)));
            try group.post("projects", createProject, @ptrCast(@alignCast(self)));
            try group.put("projects/{id}", updateProject, @ptrCast(@alignCast(self)));
        }

        fn listProjects(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            const limit: i32 = ctx.queryInt(i32, "limit", 20);
            const offset: i32 = ctx.queryInt(i32, "offset", 0);
            
            var result = self.service.listProjects(ctx.allocator, limit, offset) catch |err| {
                std.log.err("listProjects error: {s}", .{@errorName(err)});
                try ctx.text(500, "Internal server error");
                return;
            };
            defer result.deinit(ctx.allocator);
            
            // 简化：返回简单JSON数组
            var json_buf = std.ArrayList(u8).empty;
            defer json_buf.deinit(ctx.allocator);
            
            try json_buf.appendSlice(ctx.allocator, "{\"items\":[");
            for (result.items, 0..) |item, i| {
                if (i > 0) try json_buf.append(ctx.allocator, ',');
                const item_json = std.fmt.allocPrint(ctx.allocator,
                    \\{{"id":{d},"name":"{s}","slug":"{s}","sector":"{s}","status":"{s}"}}
                , .{ item.id, item.name, item.slug, item.sector, item.status }) catch {
                    try ctx.text(500, "Internal server error");
                    return;
                };
                defer ctx.allocator.free(item_json);
                try json_buf.appendSlice(ctx.allocator, item_json);
            }
            const total_json = std.fmt.allocPrint(ctx.allocator, "],\"total\":{d}}}", .{result.total}) catch {
                try ctx.text(500, "Internal server error");
                return;
            };
            defer ctx.allocator.free(total_json);
            try json_buf.appendSlice(ctx.allocator, total_json);
            
            try ctx.json(200, json_buf.items);
        }

        fn getProject(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的id参数");
                return;
            };
            
            const project = self.service.getProject(ctx.allocator, id) catch |err| {
                if (err == error.NotFound) {
                    try ctx.text(404, "Not found");
                    return;
                }
                std.log.err("getProject error: {s}", .{@errorName(err)});
                try ctx.text(500, "Internal server error");
                return;
            };
            defer project.deinit(ctx.allocator);
            
            const json_str = std.fmt.allocPrint(ctx.allocator,
                \\{{"id":{d},"name":"{s}","slug":"{s}","sector":"{s}","status":"{s}"}}
            , .{ project.id, project.name, project.slug, project.sector, project.status }) catch {
                try ctx.text(500, "Internal server error");
                return;
            };
            defer ctx.allocator.free(json_str);
            try ctx.json(200, json_str);
        }

        fn createProject(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            // 需要管理员权限
            const user_id = mw.authUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return;
            };
            
            // 检查是否是管理员
            if (!checkAdminPermission(ctx, user_id)) {
                try ctx.sendErrorResponse(403, 403, "需要管理员权限");
                return;
            }
            
            const req = ctx.bindJsonLoose(struct {
                name: []const u8,
                slug: []const u8,
                sector: ?[]const u8 = null,
                status: ?[]const u8 = null,
                description: ?[]const u8 = null,
                official_url: ?[]const u8 = null,
            }) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            
            const project_id = self.service.createProject(
                ctx.allocator,
                req.name,
                req.slug,
                req.sector,
                req.status,
                req.description,
                req.official_url,
            ) catch |err| {
                std.log.err("createProject error: {s}", .{@errorName(err)});
                try ctx.text(500, "Create failed");
                return;
            };
            
            const result_json = std.fmt.allocPrint(ctx.allocator, "{{\"id\":{d}}}", .{project_id}) catch {
                try ctx.text(500, "Internal server error");
                return;
            };
            defer ctx.allocator.free(result_json);
            try ctx.json(201, result_json);
        }

        fn updateProject(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            // 需要管理员权限
            const user_id = mw.authUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return;
            };
            
            // 检查是否是管理员
            if (!checkAdminPermission(ctx, user_id)) {
                try ctx.sendErrorResponse(403, 403, "需要管理员权限");
                return;
            }
            
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的id参数");
                return;
            };
            
            const req = ctx.bindJsonLoose(struct {
                name: ?[]const u8 = null,
                slug: ?[]const u8 = null,
                sector: ?[]const u8 = null,
                status: ?[]const u8 = null,
                description: ?[]const u8 = null,
                website: ?[]const u8 = null,
            }) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            
            self.service.updateProject(
                ctx.allocator,
                id,
                req.name,
                req.slug,
                req.sector,
                req.status,
                req.description,
                req.website,
            ) catch |err| {
                if (err == error.NotFound) {
                    try ctx.sendErrorResponse(404, 404, "项目不存在");
                    return;
                }
                std.log.err("updateProject error: {s}", .{@errorName(err)});
                try ctx.sendErrorResponse(500, 500, "更新失败");
                return;
            };
            
            try ctx.text(200, "OK");
        }
    };
}
