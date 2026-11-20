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
    analyst_id: i64,
    reviewer_id: ?i64,
    status: []const u8,
    revision: i64,
    created_at: i64,
    submitted_at: ?i64,
    reviewed_at: ?i64,
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
        analyst_id: i64,
    }) !i64 {
        const sql =
            \\INSERT INTO rating_draft (project_id, model_version, input_json, 
            \\  c1_tech, c2_team, c3_token, c4_product, c5_community, c6_governance,
            \\  confidence, red_flags, base_grade, redflag_grade, shadow_grade, 
            \\  published_grade, analyst_id, status, revision)
            \\VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, 'draft', 1)
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
            .{ .int = input.analyst_id },
        });

        var id_rows = try self.driver.query("SELECT last_insert_rowid()", &.{});
        defer id_rows.deinit();
        
        if (id_rows.next()) |row| {
            if (row.getInt(0)) |id| return id;
        }
        
        return error.NoInsertId;
    }
    
    pub fn getByIdAndProject(self: *RatingRepository, rating_id: i64, project_id: i64) !?RatingDraftRow {
        const sql =
            \\SELECT id, project_id, model_version, input_json, c1_tech, c2_team, 
            \\  c3_token, c4_product, c5_community, c6_governance, confidence, 
            \\  red_flags, base_grade, redflag_grade, shadow_grade, published_grade,
            \\  analyst_id, reviewer_id, status, revision, created_at, submitted_at, reviewed_at
            \\FROM rating_draft 
            \\WHERE id = ?1 AND project_id = ?2
        ;
        
        var rows = try self.driver.query(sql, &.{
            .{ .int = rating_id },
            .{ .int = project_id },
        });
        defer rows.deinit();
        
        if (rows.next()) |row| {
            return RatingDraftRow{
                .id = row.getInt(0) orelse return null,
                .project_id = row.getInt(1) orelse return null,
                .model_version = row.getText(2) orelse return null,
                .input_json = row.getText(3) orelse return null,
                .c1_tech = row.getInt(4),
                .c2_team = row.getInt(5),
                .c3_token = row.getInt(6),
                .c4_product = row.getInt(7),
                .c5_community = row.getInt(8),
                .c6_governance = row.getInt(9),
                .confidence = row.getInt(10) orelse return null,
                .red_flags = row.getText(11),
                .base_grade = row.getText(12) orelse return null,
                .redflag_grade = row.getText(13) orelse return null,
                .shadow_grade = row.getText(14) orelse return null,
                .published_grade = row.getText(15) orelse return null,
                .analyst_id = row.getInt(16) orelse return null,
                .reviewer_id = row.getInt(17),
                .status = row.getText(18) orelse return null,
                .revision = row.getInt(19) orelse return null,
                .created_at = row.getInt(20) orelse return null,
                .submitted_at = row.getInt(21),
                .reviewed_at = row.getInt(22),
            };
        }
        return null;
    }

    pub fn isSelfReview(self: *RatingRepository, rating_id: i64, reviewer_id: i64) !bool {
        const sql = "SELECT analyst_id FROM rating_draft WHERE id = ?1";
        var rows = try self.driver.query(sql, &.{.{ .int = rating_id }});
        defer rows.deinit();
        
        if (rows.next()) |row| {
            if (row.getInt(0)) |analyst_id| {
                return analyst_id == reviewer_id;
            }
        }
        return false;
    }

    // Submit rating: draft -> submitted (with CAS)
    pub fn submit(self: *RatingRepository, rating_id: i64, analyst_id: i64) !bool {
        const sql =
            \\UPDATE rating_draft 
            \\SET status = 'submitted', submitted_at = strftime('%s', 'now')
            \\WHERE id = ?1 AND analyst_id = ?2 AND status = 'draft'
        ;
        
        _ = try self.driver.exec(sql, &.{
            .{ .int = rating_id },
            .{ .int = analyst_id },
        });
        
        // Verify state changed
        var verify_rows = try self.driver.query("SELECT status FROM rating_draft WHERE id = ?1", &.{.{ .int = rating_id }});
        defer verify_rows.deinit();
        
        if (verify_rows.next()) |row| {
            if (row.getText(0)) |status| {
                return std.mem.eql(u8, status, "submitted");
            }
        }
        
        return false;
    }
    
    // Approve rating: submitted -> approved (with CAS to prevent duplicates)
    pub fn approve(self: *RatingRepository, rating_id: i64, reviewer_id: i64) !bool {
        // Pre-check: if already reviewed, fail immediately
        var pre_check = try self.driver.query(
            "SELECT reviewer_id, reviewed_at FROM rating_draft WHERE id = ?1",
            &.{.{ .int = rating_id }}
        );
        defer pre_check.deinit();
        
        var old_reviewed_at: ?i64 = null;
        if (pre_check.next()) |row| {
            if (row.getInt(0)) |_| {
                // reviewer_id is already set - this is a duplicate
                return false;
            }
            old_reviewed_at = row.getInt(1);
        } else {
            return false; // Rating doesn't exist
        }
        
        // Execute UPDATE with CAS conditions
        const sql =
            \\UPDATE rating_draft 
            \\SET status = 'approved', reviewer_id = ?2, reviewed_at = strftime('%s', 'now')
            \\WHERE id = ?1 AND status = 'submitted' AND reviewer_id IS NULL
        ;
        
        _ = try self.driver.exec(sql, &.{
            .{ .int = rating_id },
            .{ .int = reviewer_id },
        });
        
        // Verify reviewed_at changed (proves UPDATE succeeded)
        var post_check = try self.driver.query(
            "SELECT reviewed_at FROM rating_draft WHERE id = ?1",
            &.{.{ .int = rating_id }}
        );
        defer post_check.deinit();
        
        if (post_check.next()) |row| {
            const new_reviewed_at = row.getInt(0);
            // If reviewed_at changed from NULL or previous value, UPDATE succeeded
            if (old_reviewed_at == null and new_reviewed_at != null) {
                return true;
            }
            if (old_reviewed_at) |old| {
                if (new_reviewed_at) |new| {
                    return new != old;
                }
            }
        }
        
        return false;
    }
    
    // Reject rating: submitted -> rejected (with CAS to prevent duplicates)
    pub fn reject(self: *RatingRepository, rating_id: i64, reviewer_id: i64) !bool {
        // Pre-check: if already reviewed, fail immediately
        var pre_check = try self.driver.query(
            "SELECT reviewer_id, reviewed_at FROM rating_draft WHERE id = ?1",
            &.{.{ .int = rating_id }}
        );
        defer pre_check.deinit();
        
        var old_reviewed_at: ?i64 = null;
        if (pre_check.next()) |row| {
            if (row.getInt(0)) |_| {
                // reviewer_id is already set - this is a duplicate
                return false;
            }
            old_reviewed_at = row.getInt(1);
        } else {
            return false; // Rating doesn't exist
        }
        
        // Execute UPDATE with CAS conditions
        const sql =
            \\UPDATE rating_draft 
            \\SET status = 'rejected', reviewer_id = ?2, reviewed_at = strftime('%s', 'now')
            \\WHERE id = ?1 AND status = 'submitted' AND reviewer_id IS NULL
        ;
        
        _ = try self.driver.exec(sql, &.{
            .{ .int = rating_id },
            .{ .int = reviewer_id },
        });
        
        // Verify reviewed_at changed (proves UPDATE succeeded)
        var post_check = try self.driver.query(
            "SELECT reviewed_at FROM rating_draft WHERE id = ?1",
            &.{.{ .int = rating_id }}
        );
        defer post_check.deinit();
        
        if (post_check.next()) |row| {
            const new_reviewed_at = row.getInt(0);
            // If reviewed_at changed from NULL or previous value, UPDATE succeeded
            if (old_reviewed_at == null and new_reviewed_at != null) {
                return true;
            }
            if (old_reviewed_at) |old| {
                if (new_reviewed_at) |new| {
                    return new != old;
                }
            }
        }
        
        return false;
    }
    
    // Add audit entry
    pub fn addAudit(self: *RatingRepository, input: struct {
        rating_id: i64,
        actor_id: i64,
        action: []const u8,
        from_status: ?[]const u8,
        to_status: []const u8,
        revision: i64,
        comment: ?[]const u8,
    }) !void {
        const sql =
            \\INSERT INTO rating_audit (rating_id, actor_id, action, from_status, to_status, revision, comment)
            \\VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
        ;
        
        const from_val = if (input.from_status) |fs| zent.sql.Value{ .string = fs } else zent.sql.Value{ .null = {} };
        const comment_val = if (input.comment) |c| zent.sql.Value{ .string = c } else zent.sql.Value{ .null = {} };
        
        _ = try self.driver.exec(sql, &.{
            .{ .int = input.rating_id },
            .{ .int = input.actor_id },
            .{ .string = input.action },
            from_val,
            .{ .string = input.to_status },
            .{ .int = input.revision },
            comment_val,
        });
    }
};
