const std = @import("std");
const zent = @import("zent");

pub const PublishInput = struct {
    rating_id: i64,
    project_id: i64,
    facts_json: []const u8,
    disclaimer_text: []const u8,
    conflict_disclosure: []const u8,
    evidence_sources: []const u8,
};

pub const PublishedReport = struct {
    id: i64,
    project_id: i64,
    published_grade: []const u8,
    confidence: i64,
    facts_json: []const u8,
    disclaimer_text: []const u8,
    conflict_disclosure: []const u8,
    evidence_sources: []const u8,
    methodology_version: []const u8,
    published_at: i64,
    status: []const u8,
};

pub const PublishRepository = struct {
    driver: *zent.sql_sqlite.SQLiteDriver,
    allocator: std.mem.Allocator,

    pub fn init(driver: *zent.sql_sqlite.SQLiteDriver, allocator: std.mem.Allocator) PublishRepository {
        return .{
            .driver = driver,
            .allocator = allocator,
        };
    }

    // Validate required fields are non-empty
    fn validateContent(input: PublishInput) !void {
        if (input.facts_json.len == 0) return error.MissingFacts;
        if (input.disclaimer_text.len == 0) return error.MissingDisclaimer;
        if (input.conflict_disclosure.len == 0) return error.MissingConflictDisclosure;
        if (input.evidence_sources.len == 0) return error.MissingEvidenceSources;
    }

    // Compute content hash
    fn computeHash(self: *PublishRepository, input: PublishInput, rating_id: i64, revision: i64) ![]const u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        
        // Hash all immutable content
        hasher.update(std.mem.asBytes(&rating_id));
        hasher.update(std.mem.asBytes(&revision));
        hasher.update(input.facts_json);
        hasher.update(input.disclaimer_text);
        hasher.update(input.conflict_disclosure);
        hasher.update(input.evidence_sources);
        
        var digest: [32]u8 = undefined;
        hasher.final(&digest);
        
        // Convert to hex string
        const hex_chars = "0123456789abcdef";
        var hex = try self.allocator.alloc(u8, 64);
        for (digest, 0..) |b, i| {
            hex[i * 2] = hex_chars[b >> 4];
            hex[i * 2 + 1] = hex_chars[b & 0x0F];
        }
        return hex;
    }

    // Publish from approved rating (no new content accepted)
    pub fn publishFromApproved(self: *PublishRepository, rating_id: i64, project_id: i64, publisher_id: i64) !i64 {
        // BEGIN IMMEDIATE transaction
        _ = try self.driver.exec("BEGIN IMMEDIATE", &.{});
        errdefer {
            _ = self.driver.exec("ROLLBACK", &.{}) catch {};
        }
        
        // Read approved rating with frozen content
        var check_rows = try self.driver.query(
            \\SELECT status, revision, published_grade, confidence, analyst_id, reviewer_id, reviewed_at,
            \\  report_facts_json, report_disclaimer, report_conflict, content_hash
            \\FROM rating_draft WHERE id = ?1 AND project_id = ?2
        , &.{
            .{ .int = rating_id },
            .{ .int = project_id },
        });
        defer check_rows.deinit();
        
        const row = check_rows.next() orelse {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.RatingNotFound;
        };
        
        const status = row.getText(0) orelse return error.InvalidStatus;
        if (!std.mem.eql(u8, status, "approved")) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.NotApproved;
        }
        
        const revision = row.getInt(1) orelse return error.MissingRevision;
        const published_grade = row.getText(2) orelse return error.MissingGrade;
        const confidence = row.getInt(3) orelse return error.MissingConfidence;
        const analyst_id = row.getInt(4) orelse return error.MissingAnalyst;
        const reviewer_id = row.getInt(5) orelse return error.MissingReviewer;
        const approved_at = row.getInt(6) orelse return error.MissingApprovedAt;
        
        // Validate required report fields frozen at submission
        const facts_json = row.getText(7) orelse {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.MissingFacts;
        };
        const disclaimer = row.getText(8) orelse {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.MissingDisclaimer;
        };
        const conflict = row.getText(9) orelse {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.MissingConflictDisclosure;
        };
        const content_hash = row.getText(10) orelse {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.MissingContentHash;
        };
        
        if (facts_json.len == 0 or disclaimer.len == 0 or conflict.len == 0) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.MissingRequiredFields;
        }
        
        // Check for duplicate publish (same hash)
        var dup_check = try self.driver.query(
            "SELECT id FROM published_report WHERE content_hash = ?1",
            &.{.{ .string = content_hash }}
        );
        defer dup_check.deinit();
        
        if (dup_check.next()) |_| {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.AlreadyPublished;
        }
        
        // Build scores_json
        const scores_json = try std.fmt.allocPrint(self.allocator,
            "{{\"grade\":\"{s}\",\"confidence\":{d}}}",
            .{ published_grade, confidence }
        );
        defer self.allocator.free(scores_json);
        
        // Insert published report
        const insert_sql =
            \\INSERT INTO published_report (
            \\  rating_id, project_id, revision, published_grade, confidence,
            \\  facts_json, scores_json, disclaimer_text, conflict_disclosure,
            \\  evidence_sources, methodology_version, content_hash,
            \\  analyst_id, reviewer_id, approved_at, published_at, publisher_id, status
            \\) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, strftime('%s','now'), ?16, 'published')
        ;
        
        const result = try self.driver.exec(insert_sql, &.{
            .{ .int = rating_id },
            .{ .int = project_id },
            .{ .int = revision },
            .{ .string = published_grade },
            .{ .int = confidence },
            .{ .string = facts_json },
            .{ .string = scores_json },
            .{ .string = disclaimer },
            .{ .string = conflict },
            .{ .string = "[]" }, // evidence_sources placeholder
            .{ .string = "v1.0" },
            .{ .string = content_hash },
            .{ .int = analyst_id },
            .{ .int = reviewer_id },
            .{ .int = approved_at },
            .{ .int = publisher_id },
        });
        
        if (!result.rows_affected_known or result.rows_affected != 1) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.PublishFailed;
        }
        
        const report_id = result.last_insert_id orelse return error.NoInsertId;
        
        // Add audit entry
        _ = try self.driver.exec(
            \\INSERT INTO rating_audit (rating_id, actor_id, action, from_status, to_status, revision)
            \\VALUES (?1, ?2, 'publish', 'approved', 'published', ?3)
        , &.{
            .{ .int = rating_id },
            .{ .int = publisher_id },
            .{ .int = revision },
        });
        
        // Commit transaction
        _ = try self.driver.exec("COMMIT", &.{});
        
        return report_id;
    }

    // Publish approved rating (atomic transaction) - OLD METHOD
    pub fn publish(self: *PublishRepository, input: PublishInput, publisher_id: i64) !i64 {
        // Validate content requirements
        try validateContent(input);
        
        // BEGIN IMMEDIATE transaction
        _ = try self.driver.exec("BEGIN IMMEDIATE", &.{});
        errdefer {
            _ = self.driver.exec("ROLLBACK", &.{}) catch {};
        }
        
        // Verify rating is approved
        var check_rows = try self.driver.query(
            \\SELECT status, revision, published_grade, confidence, analyst_id, reviewer_id, reviewed_at
            \\FROM rating_draft WHERE id = ?1 AND project_id = ?2
        , &.{
            .{ .int = input.rating_id },
            .{ .int = input.project_id },
        });
        defer check_rows.deinit();
        
        const row = check_rows.next() orelse {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.RatingNotFound;
        };
        
        const status = row.getText(0) orelse {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.InvalidStatus;
        };
        
        if (!std.mem.eql(u8, status, "approved")) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.NotApproved;
        }
        
        const revision = row.getInt(1) orelse return error.MissingRevision;
        const published_grade = row.getText(2) orelse return error.MissingGrade;
        const confidence = row.getInt(3) orelse return error.MissingConfidence;
        const analyst_id = row.getInt(4) orelse return error.MissingAnalyst;
        const reviewer_id = row.getInt(5) orelse return error.MissingReviewer;
        const approved_at = row.getInt(6) orelse return error.MissingApprovedAt;
        
        // Compute content hash
        const content_hash = try self.computeHash(input, input.rating_id, revision);
        defer self.allocator.free(content_hash);
        
        // Check for duplicate publish (same hash)
        var dup_check = try self.driver.query(
            "SELECT id FROM published_report WHERE content_hash = ?1",
            &.{.{ .string = content_hash }}
        );
        defer dup_check.deinit();
        
        if (dup_check.next()) |_| {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.AlreadyPublished;
        }
        
        // Insert published report
        const insert_sql =
            \\INSERT INTO published_report (
            \\  rating_id, project_id, revision, published_grade, confidence,
            \\  facts_json, scores_json, disclaimer_text, conflict_disclosure,
            \\  evidence_sources, methodology_version, content_hash,
            \\  analyst_id, reviewer_id, approved_at, published_at, publisher_id, status
            \\) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, strftime('%s','now'), ?16, 'published')
        ;
        
        // scores_json: simplified as grade-only for now
        const scores_json = try std.fmt.allocPrint(self.allocator,
            "{{\"grade\":\"{s}\",\"confidence\":{d}}}",
            .{ published_grade, confidence }
        );
        defer self.allocator.free(scores_json);
        
        const result = try self.driver.exec(insert_sql, &.{
            .{ .int = input.rating_id },
            .{ .int = input.project_id },
            .{ .int = revision },
            .{ .string = published_grade },
            .{ .int = confidence },
            .{ .string = input.facts_json },
            .{ .string = scores_json },
            .{ .string = input.disclaimer_text },
            .{ .string = input.conflict_disclosure },
            .{ .string = input.evidence_sources },
            .{ .string = "v1.0" }, // methodology_version
            .{ .string = content_hash },
            .{ .int = analyst_id },
            .{ .int = reviewer_id },
            .{ .int = approved_at },
            .{ .int = publisher_id },
        });
        
        if (!result.rows_affected_known or result.rows_affected != 1) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return error.PublishFailed;
        }
        
        const report_id = result.last_insert_id orelse return error.NoInsertId;
        
        // Add audit entry
        _ = try self.driver.exec(
            \\INSERT INTO rating_audit (rating_id, actor_id, action, from_status, to_status, revision)
            \\VALUES (?1, ?2, 'publish', 'approved', 'published', ?3)
        , &.{
            .{ .int = input.rating_id },
            .{ .int = publisher_id },
            .{ .int = revision },
        });
        
        // Commit transaction
        _ = try self.driver.exec("COMMIT", &.{});
        
        return report_id;
    }

    // Revoke published report (atomic)
    pub fn revoke(self: *PublishRepository, project_id: i64, revoker_id: i64) !bool {
        _ = try self.driver.exec("BEGIN IMMEDIATE", &.{});
        errdefer {
            _ = self.driver.exec("ROLLBACK", &.{}) catch {};
        }
        
        // CAS UPDATE: only if published
        const update_sql =
            \\UPDATE published_report 
            \\SET status = 'revoked', revoked_at = strftime('%s','now'), revoker_id = ?2
            \\WHERE project_id = ?1 AND status = 'published'
        ;
        
        const result = try self.driver.exec(update_sql, &.{
            .{ .int = project_id },
            .{ .int = revoker_id },
        });
        
        if (!result.rows_affected_known or result.rows_affected != 1) {
            _ = try self.driver.exec("ROLLBACK", &.{});
            return false;
        }
        
        // Add audit
        _ = try self.driver.exec(
            \\INSERT INTO rating_audit (rating_id, actor_id, action, from_status, to_status, revision)
            \\SELECT rating_id, ?2, 'revoke', 'published', 'revoked', revision
            \\FROM published_report WHERE project_id = ?1 AND status = 'revoked'
        , &.{
            .{ .int = project_id },
            .{ .int = revoker_id },
        });
        
        _ = try self.driver.exec("COMMIT", &.{});
        return true;
    }

    // Get published report for public access
    pub fn getPublished(self: *PublishRepository, project_id: i64) !?PublishedReport {
        const sql =
            \\SELECT id, project_id, published_grade, confidence, facts_json,
            \\  disclaimer_text, conflict_disclosure, evidence_sources,
            \\  methodology_version, published_at, status
            \\FROM published_report 
            \\WHERE project_id = ?1 AND status = 'published'
        ;
        
        var rows = try self.driver.query(sql, &.{.{ .int = project_id }});
        defer rows.deinit();
        
        if (rows.next()) |row| {
            const facts_json = try self.allocator.dupe(u8, row.getText(4) orelse return null);
            const disclaimer = try self.allocator.dupe(u8, row.getText(5) orelse return null);
            const conflict = try self.allocator.dupe(u8, row.getText(6) orelse return null);
            const sources = try self.allocator.dupe(u8, row.getText(7) orelse return null);
            const method_ver = try self.allocator.dupe(u8, row.getText(8) orelse return null);
            const grade = try self.allocator.dupe(u8, row.getText(2) orelse return null);
            const status_str = try self.allocator.dupe(u8, row.getText(10) orelse return null);
            
            return PublishedReport{
                .id = row.getInt(0) orelse return null,
                .project_id = row.getInt(1) orelse return null,
                .published_grade = grade,
                .confidence = row.getInt(3) orelse return null,
                .facts_json = facts_json,
                .disclaimer_text = disclaimer,
                .conflict_disclosure = conflict,
                .evidence_sources = sources,
                .methodology_version = method_ver,
                .published_at = row.getInt(9) orelse return null,
                .status = status_str,
            };
        }
        return null;
    }

    // List all published reports
    pub fn listPublished(self: *PublishRepository) !std.ArrayList(PublishedReport) {
        const ListType = std.ArrayList(PublishedReport);
        var list = ListType.init(self.allocator);
        errdefer list.deinit();
        
        const sql =
            \\SELECT id, project_id, published_grade, confidence, facts_json,
            \\  disclaimer_text, conflict_disclosure, evidence_sources,
            \\  methodology_version, published_at, status
            \\FROM published_report 
            \\WHERE status = 'published'
            \\ORDER BY published_at DESC
        ;
        
        var rows = try self.driver.query(sql, &.{});
        defer rows.deinit();
        
        while (rows.next()) |row| {
            const facts_json = try self.allocator.dupe(u8, row.getText(4) orelse continue);
            const disclaimer = try self.allocator.dupe(u8, row.getText(5) orelse continue);
            const conflict = try self.allocator.dupe(u8, row.getText(6) orelse continue);
            const sources = try self.allocator.dupe(u8, row.getText(7) orelse continue);
            const method_ver = try self.allocator.dupe(u8, row.getText(8) orelse continue);
            const grade = try self.allocator.dupe(u8, row.getText(2) orelse continue);
            const status_str = try self.allocator.dupe(u8, row.getText(10) orelse continue);
            
            try list.append(PublishedReport{
                .id = row.getInt(0) orelse continue,
                .project_id = row.getInt(1) orelse continue,
                .published_grade = grade,
                .confidence = row.getInt(3) orelse continue,
                .facts_json = facts_json,
                .disclaimer_text = disclaimer,
                .conflict_disclosure = conflict,
                .evidence_sources = sources,
                .methodology_version = method_ver,
                .published_at = row.getInt(9) orelse continue,
                .status = status_str,
            });
        }
        
        return list;
    }
};
