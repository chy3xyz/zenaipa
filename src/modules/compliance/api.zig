const std = @import("std");
const zmodu = @import("zmodu");
const http = zmodu.http;

pub fn ComplianceApi(comptime Service: type) type {
    return struct {
        service: *Service,

        const Self = @This();

        pub fn init(service: *Service) Self {
            return .{ .service = service };
        }

        pub fn registerRoutes(self: *Self, group: anytype) !void {
            try group.get("compliance/config", getConfig, @ptrCast(@alignCast(self)));
            try group.post("compliance/check", checkPublishable, @ptrCast(@alignCast(self)));
        }

        pub fn getConfig(_: *Self, ctx: *http.Context) !void {
            try ctx.json(.{
                .code = 0,
                .msg = "success",
                .data = .{
                    .gates = &[_]struct {
                        id: []const u8,
                        name: []const u8,
                        is_enabled: bool,
                        can_disable: bool,
                    }{
                        .{ .id = "C1", .name = "三段披露", .is_enabled = true, .can_disable = false },
                        .{ .id = "C2", .name = "非投资建议", .is_enabled = true, .can_disable = false },
                        .{ .id = "C12", .name = "Bot溯源", .is_enabled = true, .can_disable = false },
                    },
                },
            });
        }

        pub fn checkPublishable(_: *Self, ctx: *http.Context) !void {
            try ctx.json(.{
                .code = 0,
                .msg = "success",
                .data = .{ .passed = true, .violations = &[_][]const u8{} },
            });
        }
    };
}
