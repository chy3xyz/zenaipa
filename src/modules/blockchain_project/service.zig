const std = @import("std");
const persistence = @import("persistence.zig");
const ProjectStore = persistence.ProjectStore;
const ProjectRow = persistence.ProjectRow;

pub const ProjectService = struct {
    store: *ProjectStore,

    pub fn init(store: *ProjectStore) ProjectService {
        return .{ .store = store };
    }

    pub fn createProject(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        // Validate slug uniqueness
        if (data.slug) |slug| {
            const existing = try self.store.getBySlug(alloc, slug);
            if (existing != null) {
                return error.SlugAlreadyExists;
            }
        }

        // Create project
        return try self.store.create(alloc, data);
    }

    pub fn getProject(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        id: i64,
    ) !?ProjectRow {
        return try self.store.getById(alloc, id);
    }

    pub fn getProjectBySlug(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        slug: []const u8,
    ) !?ProjectRow {
        return try self.store.getBySlug(alloc, slug);
    }

    pub fn listProjects(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        opts: anytype,
    ) !persistence.ProjectListResult {
        return try self.store.list(alloc, opts);
    }

    pub fn updateProject(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        id: i64,
        data: anytype,
    ) !bool {
        return try self.store.update(alloc, id, data);
    }

    pub fn deleteProject(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        id: i64,
    ) !bool {
        return try self.store.delete(alloc, id);
    }

    /// 从 CSV 导入项目
    /// CSV 格式: name,slug,sector,official_url,twitter_url,github_url
    pub fn importFromCsv(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        csv_data: []const u8,
    ) !struct { success_count: usize, error_count: usize, errors: [][]const u8 } {
        var success_count: usize = 0;
        var error_count: usize = 0;
        var errors = std.ArrayList([]const u8).init(alloc);
        errdefer {
            for (errors.items) |e| alloc.free(e);
            errors.deinit();
        }

        // 按行分割
        var line_iter = std.mem.splitScalar(u8, csv_data, '\n');
        var line_num: usize = 0;

        // 跳过表头
        if (line_iter.next()) |_| {
            line_num += 1;
        }

        while (line_iter.next()) |line| {
            line_num += 1;

            // 跳过空行
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;

            // 解析 CSV 行
            var fields = std.mem.splitScalar(u8, trimmed, ',');
            var field_count: usize = 0;
            var name: ?[]const u8 = null;
            var slug: ?[]const u8 = null;
            var sector: ?[]const u8 = null;
            var official_url: ?[]const u8 = null;
            var twitter_url: ?[]const u8 = null;
            var github_url: ?[]const u8 = null;

            while (fields.next()) |field| {
                const trimmed_field = std.mem.trim(u8, field, " \t\r\"");
                switch (field_count) {
                    0 => name = if (trimmed_field.len > 0) trimmed_field else null,
                    1 => slug = if (trimmed_field.len > 0) trimmed_field else null,
                    2 => sector = if (trimmed_field.len > 0) trimmed_field else null,
                    3 => official_url = if (trimmed_field.len > 0) trimmed_field else null,
                    4 => twitter_url = if (trimmed_field.len > 0) trimmed_field else null,
                    5 => github_url = if (trimmed_field.len > 0) trimmed_field else null,
                    else => {},
                }
                field_count += 1;
            }

            // 验证必填字段
            if (name == null or name.?.len == 0) {
                const err = try std.fmt.allocPrint(alloc, "第 {d} 行: 缺少项目名称", .{line_num});
                try errors.append(err);
                error_count += 1;
                continue;
            }

            if (slug == null or slug.?.len == 0) {
                const err = try std.fmt.allocPrint(alloc, "第 {d} 行: 缺少 slug", .{line_num});
                try errors.append(err);
                error_count += 1;
                continue;
            }

            // 检查 slug 重复
            const existing = self.store.getBySlug(alloc, slug.?) catch null;
            if (existing != null) {
                const err = try std.fmt.allocPrint(
                    alloc,
                    "第 {d} 行: slug '{s}' 已存在",
                    .{ line_num, slug.? },
                );
                try errors.append(err);
                error_count += 1;
                continue;
            }

            // 创建项目
            _ = self.store.create(alloc, .{
                .name = name.?,
                .slug = slug.?,
                .sector = sector orelse "Other",
                .official_url = official_url,
                .twitter_url = twitter_url,
                .github_url = github_url,
            }) catch |err| {
                const err_msg = try std.fmt.allocPrint(
                    alloc,
                    "第 {d} 行: 创建失败 - {s}",
                    .{ line_num, @errorName(err) },
                );
                try errors.append(err_msg);
                error_count += 1;
                continue;
            };

            success_count += 1;
        }

        return .{
            .success_count = success_count,
            .error_count = error_count,
            .errors = try errors.toOwnedSlice(),
        };
    }
};
