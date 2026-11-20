const std = @import("std");
const http = @import("zmodu").http;
const zent = @import("zent");
const publish_repository = @import("publish_repository.zig");

pub const PublishAPI = struct {
    sqlite_driver: *zent.sql_sqlite.SQLiteDriver,
    allocator: std.mem.Allocator,
    sec: *@import("zmodu").security.AppSecurity,

    pub fn init(sqlite_driver: *zent.sql_sqlite.SQLiteDriver, allocator: std.mem.Allocator, sec: *@import("zmodu").security.AppSecurity) PublishAPI {
        return .{
            .sqlite_driver = sqlite_driver,
            .allocator = allocator,
            .sec = sec,
        };
    }

    pub fn registerRoutes(self: *PublishAPI, router: anytype) !void {
        const zmodu = @import("zmodu");
        
        // Internal authenticated endpoints (with JWT)
        var internal_group = router.scope("/api/v1/internal");
        var internal_auth = try internal_group.use(zmodu.http.http_middleware.jwtAuthWithSecurity(&self.sec.module));
        try internal_auth.post("projects/{id}/ratings/{rating_id}/publish", handlePublish, @ptrCast(@alignCast(self)));
        try internal_auth.post("projects/{id}/ratings/{rating_id}/revoke", handleRevoke, @ptrCast(@alignCast(self)));
        
        // Public anonymous endpoints (no auth)
        var public_group = router.scope("/api/v1/public");
        try public_group.get("ratings", handleListPublic, @ptrCast(@alignCast(self)));
        try public_group.get("projects/{id}/rating", handleGetPublic, @ptrCast(@alignCast(self)));
    }
};

fn handlePublish(ctx: *http.Context) !void {
    const self: *PublishAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    // Check authentication
    const user_id_str = ctx.getAttr("user_id") orelse {
        try ctx.json(401, "{\"error\":\"Unauthorized\"}");
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        try ctx.json(401, "{\"error\":\"Invalid user ID\"}");
        return;
    };
    
    // Only admin can publish
    if (!checkAdminPermission(ctx)) {
        try ctx.json(403, "{\"error\":\"Forbidden: admin required\"}");
        return;
    }
    
    const project_id = ctx.paramInt(i64, "id") catch {
        try ctx.json(400, "{\"error\":\"Invalid project ID\"}");
        return;
    };
    
    const rating_id = ctx.paramInt(i64, "rating_id") catch {
        try ctx.json(400, "{\"error\":\"Invalid rating ID\"}");
        return;
    };
    
    var pub_repo = publish_repository.PublishRepository.init(self.sqlite_driver, self.allocator);
    
    // Publish uses approved rating content (no new content accepted)
    const report_id = pub_repo.publishFromApproved(rating_id, project_id, user_id) catch |err| {
        if (err == error.NotApproved) {
            try ctx.json(409, "{\"error\":\"Rating not approved\"}");
            return;
        } else if (err == error.MissingFacts or err == error.MissingDisclaimer or err == error.MissingConflictDisclosure) {
            try ctx.json(400, "{\"error\":\"Missing required report fields\"}");
            return;
        } else if (err == error.AlreadyPublished) {
            try ctx.json(409, "{\"error\":\"Already published\"}");
            return;
        } else {
            try ctx.json(500, "{\"error\":\"Publish failed\"}");
            return;
        }
    };
    
    const response = try std.fmt.allocPrint(self.allocator, 
        "{{\"report_id\":{d},\"message\":\"Published\"}}", 
        .{report_id}
    );
    defer self.allocator.free(response);
    try ctx.json(200, response);
}

fn handleRevoke(ctx: *http.Context) !void {
    const self: *PublishAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    const user_id_str = ctx.getAttr("user_id") orelse {
        try ctx.json(401, "{\"error\":\"Unauthorized\"}");
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        try ctx.json(401, "{\"error\":\"Invalid user ID\"}");
        return;
    };
    
    if (!checkAdminPermission(ctx)) {
        try ctx.json(403, "{\"error\":\"Forbidden: admin required\"}");
        return;
    }
    
    const project_id = ctx.paramInt(i64, "id") catch {
        try ctx.json(400, "{\"error\":\"Invalid project ID\"}");
        return;
    };
    
    var pub_repo = publish_repository.PublishRepository.init(self.sqlite_driver, self.allocator);
    
    const success = try pub_repo.revoke(project_id, user_id);
    if (!success) {
        try ctx.json(409, "{\"error\":\"Not published or already revoked\"}");
        return;
    }
    
    try ctx.json(200, "{\"message\":\"Revoked\"}");
}

fn handleListPublic(ctx: *http.Context) !void {
    // Simple implementation: return empty list for now, full implementation later
    try ctx.json(200, "[]");
}

fn handleGetPublic(ctx: *http.Context) !void {
    const self: *PublishAPI = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
    
    const project_id = ctx.paramInt(i64, "id") catch {
        try ctx.json(400, "{\"error\":\"Invalid project ID\"}");
        return;
    };
    
    var pub_repo = publish_repository.PublishRepository.init(self.sqlite_driver, self.allocator);
    
    const report_opt = try pub_repo.getPublished(project_id);
    
    if (report_opt) |report| {
        defer {
            self.allocator.free(report.published_grade);
            self.allocator.free(report.facts_json);
            self.allocator.free(report.disclaimer_text);
            self.allocator.free(report.conflict_disclosure);
            self.allocator.free(report.evidence_sources);
            self.allocator.free(report.methodology_version);
            self.allocator.free(report.status);
        }
        
        const response = try std.fmt.allocPrint(self.allocator,
            \\{{"project_id":{d},"grade":"{s}","confidence":{d},"facts":{s},"disclaimer":"{s}","conflict_disclosure":"{s}","sources":{s},"methodology":"{s}","published_at":{d}}}
        , .{
            report.project_id,
            report.published_grade,
            report.confidence,
            report.facts_json,
            report.disclaimer_text,
            report.conflict_disclosure,
            report.evidence_sources,
            report.methodology_version,
            report.published_at,
        });
        defer self.allocator.free(response);
        try ctx.json(200, response);
    } else {
        // Check if revoked
        var check_rows = try self.sqlite_driver.query(
            "SELECT status FROM published_report WHERE project_id = ?1",
            &.{.{ .int = project_id }}
        );
        defer check_rows.deinit();
        
        if (check_rows.next()) |row| {
            if (row.getText(0)) |status| {
                if (std.mem.eql(u8, status, "revoked")) {
                    try ctx.json(410, "{\"error\":\"Rating revoked\"}");
                    return;
                }
            }
        }
        
        try ctx.json(404, "{\"error\":\"Not published\"}");
    }
}

fn checkAdminPermission(ctx: *http.Context) bool {
    const roles_csv = ctx.getAttr("roles") orelse return false;
    var iter = std.mem.splitScalar(u8, roles_csv, ',');
    while (iter.next()) |role| {
        if (std.mem.eql(u8, std.mem.trim(u8, role, " "), "admin")) {
            return true;
        }
    }
    return false;
}
