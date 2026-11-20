const std = @import("std");
const zmodu = @import("zmodu");
const http = zmodu.http;

pub fn ProjectApi(comptime Service: type) type {
    return struct {
        service: *Service,

        const Self = @This();

        pub fn init(service: *Service) Self {
            return .{ .service = service };
        }

        pub fn registerRoutes(self: *Self, group: anytype) !void {
            try group.get("projects", listProjects, @ptrCast(@alignCast(self)));
            try group.get("projects/:id", getProject, @ptrCast(@alignCast(self)));
            try group.post("projects", createProject, @ptrCast(@alignCast(self)));
            try group.put("projects/:id", updateProject, @ptrCast(@alignCast(self)));
        }

        fn listProjects(ctx: *http.Context) !void {
            _ = ctx;
            return error.NotImplemented;
        }
        
        fn listProjectsOld(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            const limit: i32 = ctx.queryInt(i32, "limit", 20);
            const offset: i32 = ctx.queryInt(i32, "offset", 0);
            const sector = ctx.queryParam("sector");
            const status = ctx.queryParam("status");
            const keyword = ctx.queryParam("keyword");
            
            const result = self.service.listProjects(ctx.allocator, .{
                .limit = limit,
                .offset = offset,
                .sector = sector,
                .status = status,
                .keyword = keyword,
            }) catch |err| {
                std.log.err("listProjects error: {s}", .{@errorName(err)});
                try ctx.sendErrorResponse(500, 500, "服务器内部错误");
                return;
            };
            
            var buf = std.ArrayList(u8).init(ctx.allocator);
            defer buf.deinit();
            const writer = buf.writer();
            
            try writer.writeAll("{\"code\":0,\"msg\":\"success\",\"data\":{\"items\":[");
            for (result.items, 0..) |item, i| {
                if (i > 0) try writer.writeAll(",");
                try std.json.stringify(.{
                    .id = item.id,
                    .name = item.name,
                    .slug = item.slug,
                    .sector = item.sector,
                    .status = item.status,
                }, .{}, writer);
            }
            try writer.print("],\"total\":{d}}}}}", .{result.total});
            
            try ctx.json(200, buf.items);
        }

        fn getProject(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            const id_str = ctx.pathParam("id") orelse {
                try ctx.sendErrorResponse(400, 400, "缺少id参数");
                return;
            };
            const id = std.fmt.parseInt(i64, id_str, 10) catch {
                try ctx.sendErrorResponse(400, 400, "无效的id格式");
                return;
            };
            
            const project = self.service.getProject(ctx.allocator, id) catch |err| {
                if (err == error.NotFound) {
                    try ctx.sendErrorResponse(404, 404, "项目不存在");
                    return;
                }
                std.log.err("getProject error: {s}", .{@errorName(err)});
                try ctx.sendErrorResponse(500, 500, "服务器内部错误");
                return;
            };
            
            try ctx.text(200, "OK");
        }

        fn createProject(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            // 简化：任何认证用户都可以创建（实际应检查admin权限）
            const req = ctx.bindJsonLoose(struct {
                name: []const u8,
                slug: []const u8,
                sector: []const u8,
                status: []const u8,
                description: ?[]const u8 = null,
                website: ?[]const u8 = null,
            }) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            
            const project_id = self.service.createProject(ctx.allocator, .{
                .name = req.name,
                .slug = req.slug,
                .sector = req.sector,
                .status = req.status,
                .description = req.description,
                .website = req.website,
            }) catch |err| {
                std.log.err("createProject error: {s}", .{@errorName(err)});
                try ctx.sendErrorResponse(500, 500, "创建失败");
                return;
            };
            
            var buf: [256]u8 = undefined;
            const json_str = try std.fmt.bufPrint(&buf, "{{\"code\":0,\"msg\":\"success\",\"data\":{{\"id\":{d}}}}}", .{project_id});
            try ctx.json(201, json_str);
        }

        fn updateProject(ctx: *http.Context) !void {
            const self: *Self = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            
            const id_str = ctx.pathParam("id") orelse {
                try ctx.sendErrorResponse(400, 400, "缺少id参数");
                return;
            };
            const id = std.fmt.parseInt(i64, id_str, 10) catch {
                try ctx.sendErrorResponse(400, 400, "无效的id格式");
                return;
            };
            
            const req = ctx.bindJsonLoose(struct {
                name: ?[]const u8 = null,
                status: ?[]const u8 = null,
                description: ?[]const u8 = null,
                website: ?[]const u8 = null,
            }) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            
            self.service.updateProject(ctx.allocator, id, .{
                .name = req.name,
                .status = req.status,
                .description = req.description,
                .website = req.website,
            }) catch |err| {
                if (err == error.NotFound) {
                    try ctx.sendErrorResponse(404, 404, "项目不存在");
                    return;
                }
                std.log.err("updateProject error: {s}", .{@errorName(err)});
                try ctx.sendErrorResponse(500, 500, "更新失败");
                return;
            };
            
            try ctx.json(200, "{\"code\":0,\"msg\":\"success\"}");
        }
    };
}
