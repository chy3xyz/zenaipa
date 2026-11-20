const std = @import("std");
const zent = @import("zent");

pub const ProjectRow = struct {
    id: i64,
    name: []const u8,
    slug: []const u8,
    sector: []const u8,
    status: []const u8,
    description: ?[]const u8,
    official_url: ?[]const u8,
    
    pub fn deinit(self: ProjectRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.slug);
        allocator.free(self.sector);
        allocator.free(self.status);
        if (self.description) |d| allocator.free(d);
        if (self.official_url) |u| allocator.free(u);
    }
};

pub const ProjectListResult = struct {
    items: []ProjectRow,
    total: i64,
    
    pub fn deinit(self: *ProjectListResult, allocator: std.mem.Allocator) void {
        for (self.items) |item| item.deinit(allocator);
        allocator.free(self.items);
    }
};

pub const ProjectRepository = struct {
    allocator: std.mem.Allocator,
    driver: *zent.sql_sqlite.SQLiteDriver,
    
    pub fn init(allocator: std.mem.Allocator, driver: *zent.sql_sqlite.SQLiteDriver) ProjectRepository {
        return .{
            .allocator = allocator,
            .driver = driver,
        };
    }
    
    pub fn create(self: *ProjectRepository, name: []const u8, slug: []const u8, sector: []const u8, status: []const u8, description: ?[]const u8, official_url: ?[]const u8) !i64 {
        const sql =
            \\INSERT INTO project (name, slug, sector, status, description, official_url)
            \\VALUES (?1, ?2, ?3, ?4, ?5, ?6)
        ;
        
        const desc_val: zent.sql.Value = if (description) |d| .{ .string = d } else .null;
        const url_val: zent.sql.Value = if (official_url) |u| .{ .string = u } else .null;
        
        _ = try self.driver.exec(sql, &.{
            .{ .string = name },
            .{ .string = slug },
            .{ .string = sector },
            .{ .string = status },
            desc_val,
            url_val,
        });
        
        // 获取最后插入的ID
        var rows = try self.driver.query("SELECT last_insert_rowid()", &.{});
        defer rows.deinit();
        
        if (rows.next()) |row| {
            if (row.getInt(0)) |id| {
                return id;
            }
        }
        return error.InsertFailed;
    }
    
    pub fn getById(self: *ProjectRepository, id: i64) !?ProjectRow {
        const sql = "SELECT id, name, slug, sector, status, description, official_url FROM project WHERE id = ?1";
        
        var rows = try self.driver.query(sql, &.{.{ .int = id }});
        defer rows.deinit();
        
        if (rows.next()) |row| {
            const proj_id = row.getInt(0) orelse return null;
            const name = row.getText(1) orelse "";
            const slug = row.getText(2) orelse "";
            const sector = row.getText(3) orelse "Other";
            const status = row.getText(4) orelse "active";
            const description = row.getText(5);
            const official_url = row.getText(6);
            
            return ProjectRow{
                .id = proj_id,
                .name = try self.allocator.dupe(u8, name),
                .slug = try self.allocator.dupe(u8, slug),
                .sector = try self.allocator.dupe(u8, sector),
                .status = try self.allocator.dupe(u8, status),
                .description = if (description) |d| try self.allocator.dupe(u8, d) else null,
                .official_url = if (official_url) |u| try self.allocator.dupe(u8, u) else null,
            };
        }
        return null;
    }
    
    pub fn list(self: *ProjectRepository, limit: i32, offset: i32) !ProjectListResult {
        const sql =
            \\SELECT id, name, slug, sector, status, description, official_url
            \\FROM project
            \\ORDER BY id DESC
            \\LIMIT ?1 OFFSET ?2
        ;
        
        var rows = try self.driver.query(sql, &.{
            .{ .int = limit },
            .{ .int = offset },
        });
        defer rows.deinit();
        
        var items: std.ArrayList(ProjectRow) = .empty;
        defer items.deinit(self.allocator);
        
        while (rows.next()) |row| {
            const row_id = row.getInt(0) orelse continue;
            const name = row.getText(1) orelse "";
            const slug = row.getText(2) orelse "";
            const sector = row.getText(3) orelse "Other";
            const status = row.getText(4) orelse "active";
            const description = row.getText(5);
            const official_url = row.getText(6);
            
            try items.append(self.allocator, ProjectRow{
                .id = row_id,
                .name = try self.allocator.dupe(u8, name),
                .slug = try self.allocator.dupe(u8, slug),
                .sector = try self.allocator.dupe(u8, sector),
                .status = try self.allocator.dupe(u8, status),
                .description = if (description) |d| try self.allocator.dupe(u8, d) else null,
                .official_url = if (official_url) |u| try self.allocator.dupe(u8, u) else null,
            });
        }
        
        // 获取总数
        var count_rows = try self.driver.query("SELECT COUNT(*) FROM project", &.{});
        defer count_rows.deinit();
        
        const total: i64 = if (count_rows.next()) |row| row.getInt(0) orelse 0 else 0;
        
        return ProjectListResult{
            .items = try items.toOwnedSlice(self.allocator),
            .total = total,
        };
    }
    
    pub fn update(self: *ProjectRepository, id: i64, name: ?[]const u8, slug: ?[]const u8, sector: ?[]const u8, status: ?[]const u8, description: ?[]const u8, official_url: ?[]const u8) !void {
        // 检查项目是否存在
        const exists_sql = "SELECT 1 FROM project WHERE id = ?1";
        var check_rows = try self.driver.query(exists_sql, &.{.{ .int = id }});
        defer check_rows.deinit();
        if (check_rows.next() == null) {
            return error.NotFound;
        }
        
        // 如果没有任何更新字段，直接返回
        if (name == null and slug == null and sector == null and status == null and description == null and official_url == null) {
            return;
        }
        
        // 构建动态UPDATE
        var sql_parts = std.ArrayList(u8).empty;
        defer sql_parts.deinit(self.allocator);
        
        try sql_parts.appendSlice(self.allocator, "UPDATE project SET updated_at = strftime('%s', 'now')");
        
        var args = std.ArrayList(zent.sql.Value).empty;
        defer args.deinit(self.allocator);
        
        var param_idx: i32 = 1;
        
        if (name) |n| {
            const part = std.fmt.allocPrint(self.allocator, ", name = ?{d}", .{param_idx}) catch unreachable;
            defer self.allocator.free(part);
            try sql_parts.appendSlice(self.allocator, part);
            try args.append(self.allocator, .{ .string = n });
            param_idx += 1;
        }
        if (slug) |s| {
            const part = std.fmt.allocPrint(self.allocator, ", slug = ?{d}", .{param_idx}) catch unreachable;
            defer self.allocator.free(part);
            try sql_parts.appendSlice(self.allocator, part);
            try args.append(self.allocator, .{ .string = s });
            param_idx += 1;
        }
        if (sector) |sec| {
            const part = std.fmt.allocPrint(self.allocator, ", sector = ?{d}", .{param_idx}) catch unreachable;
            defer self.allocator.free(part);
            try sql_parts.appendSlice(self.allocator, part);
            try args.append(self.allocator, .{ .string = sec });
            param_idx += 1;
        }
        if (status) |st| {
            const part = std.fmt.allocPrint(self.allocator, ", status = ?{d}", .{param_idx}) catch unreachable;
            defer self.allocator.free(part);
            try sql_parts.appendSlice(self.allocator, part);
            try args.append(self.allocator, .{ .string = st });
            param_idx += 1;
        }
        if (description) |d| {
            const part = std.fmt.allocPrint(self.allocator, ", description = ?{d}", .{param_idx}) catch unreachable;
            defer self.allocator.free(part);
            try sql_parts.appendSlice(self.allocator, part);
            try args.append(self.allocator, .{ .string = d });
            param_idx += 1;
        }
        if (official_url) |u| {
            const part = std.fmt.allocPrint(self.allocator, ", official_url = ?{d}", .{param_idx}) catch unreachable;
            defer self.allocator.free(part);
            try sql_parts.appendSlice(self.allocator, part);
            try args.append(self.allocator, .{ .string = u });
            param_idx += 1;
        }
        
        const where_part = std.fmt.allocPrint(self.allocator, " WHERE id = ?{d}", .{param_idx}) catch unreachable;
        defer self.allocator.free(where_part);
        try sql_parts.appendSlice(self.allocator, where_part);
        try args.append(self.allocator, .{ .int = id });
        
        const sql = sql_parts.items;
        _ = self.driver.exec(sql, args.items) catch |err| {
            // SQLite UNIQUE constraint violation
            if (err == error.Constraint) {
                return error.DuplicateSlug;
            }
            return err;
        };
    }
};
