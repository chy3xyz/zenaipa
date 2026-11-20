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

    // Import from CSV (simplified placeholder)
    pub fn importFromCsv(
        self: *ProjectService,
        alloc: std.mem.Allocator,
        csv_data: []const u8,
    ) !struct { success_count: usize, error_count: usize, errors: []const []const u8 } {
        _ = self;
        _ = alloc;
        _ = csv_data;
        // TODO: Implement CSV parsing and validation
        return .{
            .success_count = 0,
            .error_count = 0,
            .errors = &[_][]const u8{},
        };
    }
};
