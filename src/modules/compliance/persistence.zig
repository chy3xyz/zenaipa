const std = @import("std");
const zent = @import("zent");
const model = @import("model.zig");

const schema = @import("../../schema.zig");
pub const Client = schema.Client;

pub const infos = zent.codegen.graph.buildGraph(&.{
    model.ComplianceConfig,
    model.ComplianceDecision,
    model.CorrectionCase,
    model.ConflictDisclosure,
}).types;

pub const ComplianceConfigInfo = infos[0];
pub const ComplianceDecisionInfo = infos[1];
pub const CorrectionCaseInfo = infos[2];
pub const ConflictDisclosureInfo = infos[3];

pub const ComplianceConfigRow = zent.codegen.crud_helpers.makeDtoStruct(ComplianceConfigInfo, .{});

pub const ComplianceStore = struct {
    client: *Client,

    pub fn init(client: *Client) ComplianceStore {
        return .{ .client = client };
    }

    pub fn getConfig(
        self: *ComplianceStore,
        alloc: std.mem.Allocator,
        switch_id: []const u8,
    ) !?ComplianceConfigRow {
        const builder = try self.client.select().from(ComplianceConfigInfo);
        defer builder.deinit();

        try builder.where(.{ .switch_id = switch_id });
        try builder.orderBy("config_version", .Desc);
        try builder.limit(1);

        const rows = try builder.queryRows(alloc, ComplianceConfigRow);
        defer alloc.free(rows);

        if (rows.len == 0) return null;
        return try rows[0].clone(alloc);
    }

    pub fn isEnabled(
        self: *ComplianceStore,
        alloc: std.mem.Allocator,
        switch_id: []const u8,
    ) !bool {
        const config = try self.getConfig(alloc, switch_id);
        if (config == null) return true; // 默认开启
        return config.?.is_enabled;
    }

    pub fn canBeDisabled(
        self: *ComplianceStore,
        alloc: std.mem.Allocator,
        switch_id: []const u8,
    ) !bool {
        const config = try self.getConfig(alloc, switch_id);
        if (config == null) return true;
        return config.?.can_be_disabled;
    }
};
