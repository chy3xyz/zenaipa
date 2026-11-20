const std = @import("std");
const zent = @import("zent");
const model = @import("model.zig");

const schema = @import("../../schema.zig");
pub const Client = schema.Client;

pub const infos = zent.codegen.graph.buildGraph(&.{
    model.MethodVersion,
    model.RatingInputSnapshot,
    model.Rating,
    model.DimensionEvidence,
    model.RatingReview,
    model.RatingChange,
}).types;

pub const MethodVersionInfo = infos[0];
pub const RatingInputSnapshotInfo = infos[1];
pub const RatingInfo = infos[2];
pub const DimensionEvidenceInfo = infos[3];
pub const RatingReviewInfo = infos[4];
pub const RatingChangeInfo = infos[5];

pub const MethodVersionRow = zent.codegen.crud_helpers.makeDtoStruct(MethodVersionInfo, .{});
pub const RatingRow = zent.codegen.crud_helpers.makeDtoStruct(RatingInfo, .{});
pub const RatingReviewRow = zent.codegen.crud_helpers.makeDtoStruct(RatingReviewInfo, .{});

pub const RatingStore = struct {
    client: *Client,

    pub fn init(client: *Client) RatingStore {
        return .{ .client = client };
    }

    pub fn createRating(
        self: *RatingStore,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        return try zent.codegen.crud_helpers.create(
            self.client,
            alloc,
            RatingInfo,
            data,
        );
    }

    pub fn getRatingById(
        self: *RatingStore,
        alloc: std.mem.Allocator,
        id: i64,
    ) !?RatingRow {
        return try zent.codegen.crud_helpers.getById(
            self.client,
            alloc,
            RatingInfo,
            RatingRow,
            id,
        );
    }

    pub fn getLatestRatingForProject(
        self: *RatingStore,
        alloc: std.mem.Allocator,
        project_id: i64,
    ) !?RatingRow {
        const builder = try self.client.select().from(RatingInfo);
        defer builder.deinit();

        try builder.where(.{
            .project_id = project_id,
            .status = "published",
        });
        try builder.orderBy("published_at", .Desc);
        try builder.limit(1);

        const rows = try builder.queryRows(alloc, RatingRow);
        defer alloc.free(rows);

        if (rows.len == 0) return null;
        return try rows[0].clone(alloc);
    }

    pub fn updateRatingStatus(
        self: *RatingStore,
        alloc: std.mem.Allocator,
        id: i64,
        status: []const u8,
    ) !bool {
        return try zent.codegen.crud_helpers.updateById(
            self.client,
            alloc,
            RatingInfo,
            id,
            .{ .status = status },
        );
    }

    pub fn createReview(
        self: *RatingStore,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        return try zent.codegen.crud_helpers.create(
            self.client,
            alloc,
            RatingReviewInfo,
            data,
        );
    }

    pub fn getDefaultMethodVersion(
        self: *RatingStore,
        alloc: std.mem.Allocator,
    ) !?MethodVersionRow {
        const builder = try self.client.select().from(MethodVersionInfo);
        defer builder.deinit();

        try builder.orderBy("created_at", .Desc);
        try builder.limit(1);

        const rows = try builder.queryRows(alloc, MethodVersionRow);
        defer alloc.free(rows);

        if (rows.len == 0) return null;
        return try rows[0].clone(alloc);
    }
};
