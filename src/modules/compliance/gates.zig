const std = @import("std");
const persistence = @import("persistence.zig");

/// 发布门禁检查结果
pub const GateCheckResult = struct {
    passed: bool,
    violations: []const []const u8,

    pub fn deinit(self: GateCheckResult, alloc: std.mem.Allocator) void {
        for (self.violations) |v| {
            alloc.free(v);
        }
        alloc.free(self.violations);
    }
};

/// 发布门禁 - C1/C2/C12 强制检查
pub const PublishGate = struct {
    store: *persistence.ComplianceStore,

    pub fn init(store: *persistence.ComplianceStore) PublishGate {
        return .{ .store = store };
    }

    /// 检查评级是否可以发布
    pub fn checkPublishable(
        self: *PublishGate,
        alloc: std.mem.Allocator,
        _: anytype, // rating (unused in current implementation)
        report: anytype,
    ) !GateCheckResult {
        var violations = std.ArrayList([]const u8).init(alloc);
        errdefer {
            for (violations.items) |v| alloc.free(v);
            violations.deinit();
        }

        // C1: 三段披露（不可关闭）
        const c1_check = try self.checkC1ThreeLayer(alloc, report);
        if (!c1_check.passed) {
            for (c1_check.violations) |v| {
                try violations.append(try alloc.dupe(u8, v));
            }
        }

        // C2: 非投资建议（不可关闭）
        const c2_check = try self.checkC2NoInvestmentAdvice(alloc, report);
        if (!c2_check.passed) {
            for (c2_check.violations) |v| {
                try violations.append(try alloc.dupe(u8, v));
            }
        }

        // C12: Bot 溯源（不可关闭）
        const c12_check = try self.checkC12BotSource(alloc, report);
        if (!c12_check.passed) {
            for (c12_check.violations) |v| {
                try violations.append(try alloc.dupe(u8, v));
            }
        }

        // PRD: NR 可以发布，只需确保前端只展示事实层和数据不足原因
        // 不在此处禁止 NR 发布

        const passed = violations.items.len == 0;
        return GateCheckResult{
            .passed = passed,
            .violations = try violations.toOwnedSlice(),
        };
    }

    /// C1: 三段披露检查
    fn checkC1ThreeLayer(
        self: *PublishGate,
        alloc: std.mem.Allocator,
        report: anytype,
    ) !GateCheckResult {
        var violations = std.ArrayList([]const u8).init(alloc);
        errdefer {
            for (violations.items) |v| alloc.free(v);
            violations.deinit();
        }

        // C1 不可关闭
        const can_disable = try self.store.canBeDisabled(alloc, "C1");
        if (can_disable) {
            try violations.append(try alloc.dupe(u8, "C1 三段披露开关配置错误：不可关闭"));
        }

        // 检查是否开启
        const enabled = try self.store.isEnabled(alloc, "C1");
        if (!enabled) {
            try violations.append(try alloc.dupe(u8, "C1 三段披露未开启（代码层错误）"));
        }

        // 检查事实层
        if (report.fact_layer_md == null or report.fact_layer_md.?.len == 0) {
            try violations.append(try alloc.dupe(u8, "缺少事实层内容（fact_layer_md）"));
        }

        // 检查评分层
        if (report.score_layer_md == null or report.score_layer_md.?.len == 0) {
            try violations.append(try alloc.dupe(u8, "缺少评分层内容（score_layer_md）"));
        }

        // 检查观点层
        if (report.opinion_layer_md == null or report.opinion_layer_md.?.len == 0) {
            try violations.append(try alloc.dupe(u8, "缺少观点层内容（opinion_layer_md）"));
        }

        const passed = violations.items.len == 0;
        return GateCheckResult{
            .passed = passed,
            .violations = try violations.toOwnedSlice(),
        };
    }

    /// C2: 非投资建议检查
    fn checkC2NoInvestmentAdvice(
        self: *PublishGate,
        alloc: std.mem.Allocator,
        report: anytype,
    ) !GateCheckResult {
        var violations = std.ArrayList([]const u8).init(alloc);
        errdefer {
            for (violations.items) |v| alloc.free(v);
            violations.deinit();
        }

        // C2 不可关闭
        const can_disable = try self.store.canBeDisabled(alloc, "C2");
        if (can_disable) {
            try violations.append(try alloc.dupe(u8, "C2 非投资建议开关配置错误：不可关闭"));
        }

        // 检查是否开启
        const enabled = try self.store.isEnabled(alloc, "C2");
        if (!enabled) {
            try violations.append(try alloc.dupe(u8, "C2 非投资建议未开启（代码层错误）"));
        }

        // 检查是否包含结构化免责声明
        // PRD: 不能用简单字符串检查，应验证disclosure_json结构
        const disclosure = report.disclosure_json orelse "";
        if (disclosure.len == 0) {
            try violations.append(try alloc.dupe(u8, "缺少结构化披露信息（disclosure_json）"));
        } else {
            // TODO: 解析JSON并验证包含必需的免责声明字段
            // 当前简化检查：至少包含 disclaimer 相关内容
            if (std.mem.indexOf(u8, disclosure, "disclaimer") == null and
                std.mem.indexOf(u8, disclosure, "免责") == null)
            {
                try violations.append(try alloc.dupe(u8, "披露信息中缺少免责声明"));
            }
        }

        const passed = violations.items.len == 0;
        return GateCheckResult{
            .passed = passed,
            .violations = try violations.toOwnedSlice(),
        };
    }

    /// C12: Bot 溯源检查
    fn checkC12BotSource(
        self: *PublishGate,
        alloc: std.mem.Allocator,
        report: anytype,
    ) !GateCheckResult {
        var violations = std.ArrayList([]const u8).init(alloc);
        errdefer {
            for (violations.items) |v| alloc.free(v);
            violations.deinit();
        }

        // C12 不可关闭
        const can_disable = try self.store.canBeDisabled(alloc, "C12");
        if (can_disable) {
            try violations.append(try alloc.dupe(u8, "C12 Bot 溯源开关配置错误：不可关闭"));
        }

        // 检查是否开启
        const enabled = try self.store.isEnabled(alloc, "C12");
        if (!enabled) {
            try violations.append(try alloc.dupe(u8, "C12 Bot 溯源未开启（代码层错误）"));
        }

        // 检查是否有结构化的数据来源记录
        // PRD: 不能用简单字符串检查，应验证结构化来源记录
        // TODO: 关联 data_collection_log 表验证所有引用的数据源
        // 当前简化：检查 conflict_disclosure_refs 是否非空（作为来源引用的占位）
        const source_refs = report.conflict_disclosure_refs orelse "";
        if (source_refs.len == 0) {
            try violations.append(try alloc.dupe(u8, "缺少结构化数据来源记录（需关联 data_collection_log）"));
        }

        const passed = violations.items.len == 0;
        return GateCheckResult{
            .passed = passed,
            .violations = try violations.toOwnedSlice(),
        };
    }
};
