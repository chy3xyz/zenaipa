const std = @import("std");
const repository = @import("repository.zig");
const ProjectRepository = repository.ProjectRepository;
const ProjectRow = repository.ProjectRow;
const ProjectListResult = repository.ProjectListResult;

pub const ProjectService = struct {
    repo: *ProjectRepository,

    pub fn init(repo: *ProjectRepository) ProjectService {
        return .{ .repo = repo };
    }

    pub fn createProject(
        self: *ProjectService,
        _: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        return try self.repo.create(
            data.name,
            data.slug,
            data.sector orelse "Other",
            data.status orelse "active",
            data.description,
            data.website,
        );
    }

    pub fn getProject(
        self: *ProjectService,
        _: std.mem.Allocator,
        id: i64,
    ) !ProjectRow {
        return try self.repo.getById(id) orelse error.NotFound;
    }

    pub fn listProjects(
        self: *ProjectService,
        _: std.mem.Allocator,
        limit: i32,
        offset: i32,
    ) !ProjectListResult {
        return try self.repo.list(limit, offset);
    }

    pub fn updateProject(
        self: *ProjectService,
        _: std.mem.Allocator,
        id: i64,
        name: ?[]const u8,
        slug: ?[]const u8,
        sector: ?[]const u8,
        status: ?[]const u8,
        description: ?[]const u8,
        website: ?[]const u8,
    ) !void {
        return try self.repo.update(id, name, slug, sector, status, description, website);
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
