const std = @import("std");
const zent = @import("zent");

pub const RatingDraftRow = struct {
    id: i64,
    project_id: i64,
    model_version: []const u8,
    input_json: []const u8,
    c1_tech: ?i64,
    c2_team: ?i64,
    c3_token: ?i64,
    c4_product: ?i64,
    c5_community: ?i64,
    c6_governance: ?i64,
    confidence: i64,
    red_flags: ?[]const u8,
    base_grade: []const u8,
    redflag_grade: []const u8,
    shadow_grade: []const u8,
    published_grade: []const u8,
    created_by: i64,
    is_draft: i64,
    created_at: i64,
};

pub const RatingRepository = struct {
    driver: *zent.sql_sqlite.SQLiteDriver,
    allocator: std.mem.Allocator,

    pub fn init(driver: *zent.sql_sqlite.SQLiteDriver, allocator: std.mem.Allocator) RatingRepository {
        return .{
            .driver = driver,
            .allocator = allocator,
        };
    }

    pub fn create(self: *RatingRepository, input: struct {
        project_id: i64,
        model_version: []const u8,
        input_json: []const u8,
        c1_tech: ?i64,
        c2_team: ?i64,
        c3_token: ?i64,
        c4_product: ?i64,
        c5_community: ?i64,
        c6_governance: ?i64,
        confidence: i64,
        red_flags: ?[]const u8,
        base_grade: []const u8,
        redflag_grade: []const u8,
        shadow_grade: []const u8,
        published_grade: []const u8,
        created_by: i64,
    }) !i64 {
        const sql =
            \\INSERT INTO rating_draft (project_id, model_version, input_json, 
            \\  c1_tech, c2_team, c3_token, c4_product, c5_community, c6_governance,
            \\  confidence, red_flags, base_grade, redflag_grade, shadow_grade, 
            \\  published_grade, created_by, is_draft)
            \\VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, 1)
        ;

        const red_flags_value = if (input.red_flags) |rf| zent.sql.Value{ .string = rf } else zent.sql.Value{ .null = {} };

        _ = try self.driver.exec(sql, &.{
            .{ .int = input.project_id },
            .{ .string = input.model_version },
            .{ .string = input.input_json },
            if (input.c1_tech) |v| zent.sql.Value{ .int = v } else zent.sql.Value{ .null = {} },
            if (input.c2_team) |v| zent.sql.Value{ .int = v } else zent.sql.Value{ .null = {} },
            if (input.c3_token) |v| zent.sql.Value{ .int = v } else zent.sql.Value{ .null = {} },
            if (input.c4_product) |v| zent.sql.Value{ .int = v } else zent.sql.Value{ .null = {} },
            if (input.c5_community) |v| zent.sql.Value{ .int = v } else zent.sql.Value{ .null = {} },
            if (input.c6_governance) |v| zent.sql.Value{ .int = v } else zent.sql.Value{ .null = {} },
            .{ .int = input.confidence },
            red_flags_value,
            .{ .string = input.base_grade },
            .{ .string = input.redflag_grade },
            .{ .string = input.shadow_grade },
            .{ .string = input.published_grade },
            .{ .int = input.created_by },
        });

        // 获取最后插入的ID
        var rows = try self.driver.query("SELECT last_insert_rowid()", &.{});
        defer rows.deinit();
        
        if (rows.next()) |row| {
            if (row.getInt(0)) |id| {
                return id;
            }
        }
        
        return error.NoInsertId;
    }

    pub fn getById(self: *RatingRepository, id: i64) !?RatingDraftRow {
        const sql =
            \\SELECT id, project_id, model_version, input_json, c1_tech, c2_team, 
            \\  c3_token, c4_product, c5_community, c6_governance, confidence, 
            \\  red_flags, base_grade, redflag_grade, shadow_grade, published_grade,
            \\  created_by, is_draft, created_at
            \\FROM rating_draft WHERE id = ?1
        ;
        
        var rows = try self.driver.query(sql, &.{.{ .int = id }});
        defer rows.deinit();
        
        if (rows.next()) |row| {
            const rating_id = row.getInt(0) orelse return null;
            const project_id = row.getInt(1) orelse return null;
            const model_version = row.getText(2) orelse "";
            const input_json = row.getText(3) orelse "";
            const c1_tech = row.getInt(4);
            const c2_team = row.getInt(5);
            const c3_token = row.getInt(6);
            const c4_product = row.getInt(7);
            const c5_community = row.getInt(8);
            const c6_governance = row.getInt(9);
            const confidence = row.getInt(10) orelse 0;
            const red_flags = row.getText(11);
            const base_grade = row.getText(12) orelse "";
            const redflag_grade = row.getText(13) orelse "";
            const shadow_grade = row.getText(14) orelse "";
            const published_grade = row.getText(15) orelse "";
            const created_by = row.getInt(16) orelse return null;
            const is_draft = row.getInt(17) orelse 1;
            const created_at = row.getInt(18) orelse 0;

            return RatingDraftRow{
                .id = rating_id,
                .project_id = project_id,
                .model_version = model_version,
                .input_json = input_json,
                .c1_tech = c1_tech,
                .c2_team = c2_team,
                .c3_token = c3_token,
                .c4_product = c4_product,
                .c5_community = c5_community,
                .c6_governance = c6_governance,
                .confidence = confidence,
                .red_flags = red_flags,
                .base_grade = base_grade,
                .redflag_grade = redflag_grade,
                .shadow_grade = shadow_grade,
                .published_grade = published_grade,
                .created_by = created_by,
                .is_draft = is_draft,
                .created_at = created_at,
            };
        }
        
        return null;
    }

    pub fn getByProjectId(self: *RatingRepository, project_id: i64) !?RatingDraftRow {
        const sql =
            \\SELECT id, project_id, model_version, input_json, c1_tech, c2_team, 
            \\  c3_token, c4_product, c5_community, c6_governance, confidence, 
            \\  red_flags, base_grade, redflag_grade, shadow_grade, published_grade,
            \\  created_by, is_draft, created_at
            \\FROM rating_draft WHERE project_id = ?1 ORDER BY created_at DESC LIMIT 1
        ;
        
        var rows = try self.driver.query(sql, &.{.{ .int = project_id }});
        defer rows.deinit();
        
        if (rows.next()) |row| {
            const rating_id = row.getInt(0) orelse return null;
            const proj_id = row.getInt(1) orelse return null;
            const model_version = row.getText(2) orelse "";
            const input_json = row.getText(3) orelse "";
            const c1_tech = row.getInt(4);
            const c2_team = row.getInt(5);
            const c3_token = row.getInt(6);
            const c4_product = row.getInt(7);
            const c5_community = row.getInt(8);
            const c6_governance = row.getInt(9);
            const confidence = row.getInt(10) orelse 0;
            const red_flags = row.getText(11);
            const base_grade = row.getText(12) orelse "";
            const redflag_grade = row.getText(13) orelse "";
            const shadow_grade = row.getText(14) orelse "";
            const published_grade = row.getText(15) orelse "";
            const created_by = row.getInt(16) orelse return null;
            const is_draft = row.getInt(17) orelse 1;
            const created_at = row.getInt(18) orelse 0;

            return RatingDraftRow{
                .id = rating_id,
                .project_id = proj_id,
                .model_version = model_version,
                .input_json = input_json,
                .c1_tech = c1_tech,
                .c2_team = c2_team,
                .c3_token = c3_token,
                .c4_product = c4_product,
                .c5_community = c5_community,
                .c6_governance = c6_governance,
                .confidence = confidence,
                .red_flags = red_flags,
                .base_grade = base_grade,
                .redflag_grade = redflag_grade,
                .shadow_grade = shadow_grade,
                .published_grade = published_grade,
                .created_by = created_by,
                .is_draft = is_draft,
                .created_at = created_at,
            };
        }
        
        return null;
    }
};
