const std = @import("std");
const persistence = @import("persistence.zig");
const ProjectStore = persistence.ProjectStore;
const ProjectRow = persistence.ProjectRow;
const ProjectListResult = persistence.ProjectListResult;
const ListParams = persistence.ListParams;

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
        return try self.store.create(alloc, data);
    }

    pub fn getProject(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        id: i64,
    ) !ProjectRow {
        const project_opt = try self.store.getById(alloc, id);
        return project_opt orelse error.NotFound;
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
        params: ListParams,
    ) !ProjectListResult {
        return try self.store.list(alloc, params);
    }

    pub fn updateProject(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        id: i64,
        data: anytype,
    ) !void {
        // 验证项目存在
        const _proj = try self.getProject(alloc, id);
        _proj.free(alloc);
        
        // 更新
        return try self.store.updateById(alloc, id, data);
    }

    pub fn importFromCsv(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        csv_data: []const u8,
    ) !struct { success_count: usize, error_count: usize, errors: [][]const u8 } {
        _ = self;
        _ = alloc;
        _ = csv_data;
        return .{ .success_count = 0, .error_count = 0, .errors = &.{} };
    }
};
