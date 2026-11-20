const std = @import("std");
const zent = @import("zent");
const persistence = @import("persistence.zig");
const gates = @import("gates.zig");
const ComplianceStore = persistence.ComplianceStore;
const PublishGate = gates.PublishGate;

pub const ComplianceService = struct {
    store: *ComplianceStore,
    gate: PublishGate,

    pub fn init(store: *ComplianceStore) ComplianceService {
        return .{
            .store = store,
            .gate = PublishGate.init(store),
        };
    }

    /// 检查是否可以发布
    pub fn checkPublishable(
        self: *ComplianceService,
        alloc: std.mem.Allocator,
        rating: anytype,
        report: anytype,
    ) !gates.GateCheckResult {
        return try self.gate.checkPublishable(alloc, rating, report);
    }

    /// 初始化合规配置（应在系统启动时调用）
    pub fn initializeConfigs(
        self: *ComplianceService,
        alloc: std.mem.Allocator,
    ) !void {
        // 确保 C1/C2/C12 配置存在且不可关闭
        const mandatory_switches = [_]struct {
            id: []const u8,
            name: []const u8,
            can_disable: bool,
        }{
            .{ .id = "C1", .name = "三段披露", .can_disable = false },
            .{ .id = "C2", .name = "非投资建议", .can_disable = false },
            .{ .id = "C12", .name = "Bot溯源", .can_disable = false },
        };

        for (mandatory_switches) |sw| {
            const existing = try self.store.getConfig(alloc, sw.id);
            if (existing == null) {
                // 创建默认配置
                _ = try zent.codegen.crud_helpers.create(
                    self.store.client,
                    alloc,
                    persistence.ComplianceConfigInfo,
                    .{
                        .switch_id = sw.id,
                        .switch_name = sw.name,
                        .is_enabled = true,
                        .can_be_disabled = sw.can_disable,
                    },
                );
            }
        }
    }
};
