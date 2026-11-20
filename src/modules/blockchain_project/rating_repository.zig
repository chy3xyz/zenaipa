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

pub const AuditInput = struct {
    rating_id: i64,
    actor_id: i64,
    action: []const u8,
    from_status: ?[]const u8,
    to_status: []const u8,
    revision: i64,
    comment: ?[]const u8,
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
            // Copy strings before rows.deinit() invalidates them
            const model_version = try self.allocator.dupe(u8, row.getText(2) orelse return null);
            const input_json = try self.allocator.dupe(u8, row.getText(3) orelse return null);
            const red_flags = if (row.getText(11)) |rf| try self.allocator.dupe(u8, rf) else null;
            const base_grade = try self.allocator.dupe(u8, row.getText(12) orelse return null);
            const redflag_grade = try self.allocator.dupe(u8, row.getText(13) orelse return null);
            const shadow_grade = try self.allocator.dupe(u8, row.getText(14) orelse return null);
            const published_grade = try self.allocator.dupe(u8, row.getText(15) orelse return null);
            const status = try self.allocator.dupe(u8, row.getText(18) orelse return null);
            
            return RatingDraftRow{
                .id = row.getInt(0) orelse return null,
                .project_id = row.getInt(1) orelse return null,
                .model_version = model_version,
                .input_json = input_json,
                .c1_tech = row.getInt(4),
                .c2_team = row.getInt(5),
                .c3_token = row.getInt(6),
                .c4_product = row.getInt(7),
                .c5_community = row.getInt(8),
                .c6_governance = row.getInt(9),
                .confidence = row.getInt(10) orelse return null,
                .red_flags = red_flags,
                .base_grade = base_grade,
                .redflag_grade = redflag_grade,
                .shadow_grade = shadow_grade,
                .published_grade = published_grade,
                .analyst_id = row.getInt(16) orelse return null,
                .reviewer_id = row.getInt(17),
                .status = status,
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

    pub const SubmitInput = struct {
        rating_id: i64,
        analyst_id: i64,
        report_facts_json: []const u8,
        report_disclaimer: []const u8,
        report_conflict: []const u8,
    };
    
    // Compute content hash for submission
    fn computeSubmitHash(self: *RatingRepository, input: SubmitInput, revision: i64) ![]const u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        
        hasher.update(std.mem.asBytes(&input.rating_id));
        hasher.update(std.mem.asBytes(&revision));
        hasher.update(input.report_facts_json);
        hasher.update(input.report_disclaimer);
        hasher.update(input.report_conflict);
        
        var digest: [32]u8 = undefined;
        hasher.final(&digest);
        
        const hex_chars = "0123456789abcdef";
        var hex = try self.allocator.alloc(u8, 64);
        for (digest, 0..) |b, i| {
            hex[i * 2] = hex_chars[b >> 4];
            hex[i * 2 + 1] = hex_chars[b & 0x0F];
        }
        return hex;
    }

    // Submit rating: draft -> submitted (with atomic CAS transaction)
    pub fn submit(self: *RatingRepository, input: SubmitInput) !bool {
        // Validate required report fields
        if (input.report_facts_json.len == 0) return error.MissingFacts;
        if (input.report_disclaimer.len == 0) return error.MissingDisclaimer;
        if (input.report_conflict.len == 0) return error.MissingConflictDisclosure;
        
        // BEGIN IMMEDIATE for write lock
        _ = try self.driver.exec("BEGIN IMMEDIATE", &.{});
        errdefer {
            _ = self.driver.exec("ROLLBACK", &.{}) catch {};
        }
        
        // Get current revision
        var rev_rows = try self.driver.query(
            "SELECT revision FROM rating_draft WHERE id = ?1",
            &.{.{ .int = input.rating_id }}
        );
        defer rev_rows.deinit();
        
        const revision = if (rev_rows.next()) |row| row.getInt(0) orelse 1 else 1;
        
        // Compute content hash
        const content_hash = try self.computeSubmitHash(input, revision);
        defer self.allocator.free(content_hash);
        
        // CAS UPDATE: freeze report content and hash at submission
        const update_sql =
            \\UPDATE rating_draft 
            \\SET status = 'submitted', submitted_at = strftime('%s', 'now'),
            \\    report_facts_json = ?3, report_disclaimer = ?4, report_conflict = ?5, content_hash = ?6
            \\WHERE id = ?1 AND analyst_id = ?2 AND status = 'draft'
        ;
        
        const result = try self.driver.exec(update_sql, &.{
            .{ .int = input.rating_id },
            .{ .int = input.analyst_id },
            .{ .string = input.report_facts_json },
            .{ .string = input.report_disclaimer },
            .{ .string = input.report_conflict },
            .{ .string = content_hash },
        });
        
        // Check affected rows (CAS success = exactly 1 row)
        if (!result.rows_affected_known or result.rows_affected != 1) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return false;
        }
        
        // Add audit in same transaction
        try self.addAuditInTx(.{
            .rating_id = input.rating_id,
            .actor_id = input.analyst_id,
            .action = "submit",
            .from_status = "draft",
            .to_status = "submitted",
            .revision = revision,
            .comment = null,
        });
        
        // Commit transaction
        _ = try self.driver.exec("COMMIT", &.{});
        return true;
    }
    
    // Approve rating: submitted -> approved (with atomic CAS transaction)
    pub fn approve(self: *RatingRepository, rating_id: i64, reviewer_id: i64) !bool {
        // BEGIN IMMEDIATE for write lock
        _ = try self.driver.exec("BEGIN IMMEDIATE", &.{});
        errdefer {
            _ = self.driver.exec("ROLLBACK", &.{}) catch {};
        }
        
        // CAS UPDATE: only if submitted status and not yet reviewed
        const update_sql =
            \\UPDATE rating_draft 
            \\SET status = 'approved', reviewer_id = ?2, reviewed_at = strftime('%s', 'now')
            \\WHERE id = ?1 AND status = 'submitted' AND reviewer_id IS NULL
        ;
        
        const result = try self.driver.exec(update_sql, &.{
            .{ .int = rating_id },
            .{ .int = reviewer_id },
        });
        
        // Check affected rows (CAS success = exactly 1 row)
        if (!result.rows_affected_known or result.rows_affected != 1) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return false;
        }
        
        // Add audit in same transaction
        try self.addAuditInTx(.{
            .rating_id = rating_id,
            .actor_id = reviewer_id,
            .action = "approve",
            .from_status = "submitted",
            .to_status = "approved",
            .revision = 1,
            .comment = null,
        });
        
        // Commit transaction
        _ = try self.driver.exec("COMMIT", &.{});
        return true;
    }
    
    // Reject rating: submitted -> rejected (with atomic CAS transaction)
    pub fn reject(self: *RatingRepository, rating_id: i64, reviewer_id: i64) !bool {
        // BEGIN IMMEDIATE for write lock
        _ = try self.driver.exec("BEGIN IMMEDIATE", &.{});
        errdefer {
            _ = self.driver.exec("ROLLBACK", &.{}) catch {};
        }
        
        // CAS UPDATE: only if submitted status and not yet reviewed
        const update_sql =
            \\UPDATE rating_draft 
            \\SET status = 'rejected', reviewer_id = ?2, reviewed_at = strftime('%s', 'now')
            \\WHERE id = ?1 AND status = 'submitted' AND reviewer_id IS NULL
        ;
        
        const result = try self.driver.exec(update_sql, &.{
            .{ .int = rating_id },
            .{ .int = reviewer_id },
        });
        
        // Check affected rows (CAS success = exactly 1 row)
        if (!result.rows_affected_known or result.rows_affected != 1) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return false;
        }
        
        // Add audit in same transaction
        try self.addAuditInTx(.{
            .rating_id = rating_id,
            .actor_id = reviewer_id,
            .action = "reject",
            .from_status = "submitted",
            .to_status = "rejected",
            .revision = 1,
            .comment = null,
        });
        
        // Commit transaction
        _ = try self.driver.exec("COMMIT", &.{});
        return true;
    }
    
    // Add audit entry within existing transaction (no BEGIN/COMMIT)
    fn addAuditInTx(self: *RatingRepository, input: AuditInput) !void {
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
    
    // Add audit entry (standalone with own transaction for create)
    pub fn addAudit(self: *RatingRepository, input: AuditInput) !void {
        try self.addAuditInTx(input);
    }
};
