const std = @import("std");
const zent = @import("zent");
const model = @import("model.zig");

const schema = @import("../../schema.zig");
pub const infos = zent.codegen.graph.buildGraph(&.{
    model.Project,
    model.ProjectContract,
    model.TokenMetric,
    model.TeamMember,
    model.FundingRound,
    model.UnlockEvent,
    model.ProjectTag,
}).types;

pub const Client = schema.Client;

// Type aliases for convenience
pub const ProjectInfo = infos[0];
pub const ProjectContractInfo = infos[1];
pub const TokenMetricInfo = infos[2];
pub const TeamMemberInfo = infos[3];
pub const FundingRoundInfo = infos[4];
pub const UnlockEventInfo = infos[5];
pub const ProjectTagInfo = infos[6];

pub const ProjectRow = zent.crud_helpers.makeDtoStruct(ProjectInfo, .{});
pub const ProjectContractRow = zent.crud_helpers.makeDtoStruct(ProjectContractInfo, .{});
pub const TokenMetricRow = zent.crud_helpers.makeDtoStruct(TokenMetricInfo, .{});
pub const TeamMemberRow = zent.crud_helpers.makeDtoStruct(TeamMemberInfo, .{});

pub const ProjectListResult = struct {
    items: []const ProjectRow,
    total: usize,
};

/// Project Store
pub const ProjectStore = struct {
    client: *Client,

    pub fn init(client: *Client) ProjectStore {
        return .{ .client = client };
    }

    pub fn create(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        return try zent.crud_helpers.create(
            self.client,
            alloc,
            ProjectInfo,
            data,
        );
    }

    pub fn getById(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        id: i64,
    ) !?ProjectRow {
        return try zent.crud_helpers.getById(
            self.client,
            alloc,
            ProjectInfo,
            ProjectRow,
            id,
        );
    }

    pub fn getBySlug(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        slug: []const u8,
    ) !?ProjectRow {
        const builder = try self.client.select().from(ProjectInfo);
        defer builder.deinit();

        try builder.where(.{ .slug = slug });

        const rows = try builder.queryRows(alloc, ProjectRow);
        defer alloc.free(rows);

        if (rows.len == 0) return null;
        return try rows[0].clone(alloc);
    }

    pub fn list(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        opts: struct {
            limit: usize = 20,
            offset: usize = 0,
            sector: ?[]const u8 = null,
            status: ?[]const u8 = null,
            keyword: ?[]const u8 = null,
        },
    ) !ProjectListResult {
        const builder = try self.client.select().from(ProjectInfo);
        defer builder.deinit();

        if (opts.sector) |sector| {
            try builder.where(.{ .sector = sector });
        }
        if (opts.status) |status| {
            try builder.where(.{ .status = status });
        }
        if (opts.keyword) |kw| {
            // Simple LIKE search on name
            try builder.whereRaw("name LIKE ?", .{try std.fmt.allocPrint(alloc, "%{s}%", .{kw})});
        }

        try builder.orderBy("created_at", .Desc);
        try builder.limit(opts.limit);
        try builder.offset(opts.offset);

        const items = try builder.queryRows(alloc, ProjectRow);

        // Count total (simplified - would need a separate count query in production)
        const total = items.len; // TODO: implement proper count query

        return ProjectListResult{
            .items = items,
            .total = total,
        };
    }

    pub fn update(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        id: i64,
        data: anytype,
    ) !bool {
        return try zent.crud_helpers.updateById(
            self.client,
            alloc,
            ProjectInfo,
            id,
            data,
        );
    }

    pub fn delete(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        id: i64,
    ) !bool {
        return try zent.crud_helpers.deleteById(
            self.client,
            alloc,
            ProjectInfo,
            id,
        );
    }

    // Contract operations
    pub fn addContract(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        return try zent.crud_helpers.create(
            self.client,
            alloc,
            ProjectContractInfo,
            data,
        );
    }

    pub fn getContracts(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        project_id: i64,
    ) ![]const ProjectContractRow {
        const builder = try self.client.select().from(ProjectContractInfo);
        defer builder.deinit();

        try builder.where(.{ .project_id = project_id });
        try builder.orderBy("is_primary", .Desc);

        return try builder.queryRows(alloc, ProjectContractRow);
    }

    // Token metrics operations
    pub fn addTokenMetric(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        return try zent.crud_helpers.create(
            self.client,
            alloc,
            TokenMetricInfo,
            data,
        );
    }

    pub fn getLatestMetric(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        project_id: i64,
    ) !?TokenMetricRow {
        const builder = try self.client.select().from(TokenMetricInfo);
        defer builder.deinit();

        try builder.where(.{ .project_id = project_id });
        try builder.orderBy("snapshot_at", .Desc);
        try builder.limit(1);

        const rows = try builder.queryRows(alloc, TokenMetricRow);
        defer alloc.free(rows);

        if (rows.len == 0) return null;
        return try rows[0].clone(alloc);
    }

    // Team members operations
    pub fn addTeamMember(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        return try zent.crud_helpers.create(
            self.client,
            alloc,
            TeamMemberInfo,
            data,
        );
    }

    pub fn getTeamMembers(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        project_id: i64,
    ) ![]const TeamMemberRow {
        const builder = try self.client.select().from(TeamMemberInfo);
        defer builder.deinit();

        try builder.where(.{ .project_id = project_id });

        return try builder.queryRows(alloc, TeamMemberRow);
    }
};
