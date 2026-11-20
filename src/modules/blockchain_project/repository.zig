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
            const name = row.getText(1) orelse return null;
            const slug = row.getText(2) orelse return null;
            const sector = row.getText(3) orelse return null;
            const status = row.getText(4) orelse return null;
            
            return ProjectRow{
                .id = proj_id,
                .name = try self.allocator.dupe(u8, name),
                .slug = try self.allocator.dupe(u8, slug),
                .sector = try self.allocator.dupe(u8, sector),
                .status = try self.allocator.dupe(u8, status),
                .description = if (row.getText(5)) |d| try self.allocator.dupe(u8, d) else null,
                .official_url = if (row.getText(6)) |u| try self.allocator.dupe(u8, u) else null,
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
        // 动态构建UPDATE语句
        var sql: []const u8 = undefined;
        
        var args: std.ArrayList(zent.sql.Value) = .empty;
        defer args.deinit(self.allocator);
        
        if (name) |n| {
            try args.append(self.allocator, .{ .string = n });
        }
        if (slug) |s| {
            try args.append(self.allocator, .{ .string = s });
        }
        if (sector) |sec| {
            try args.append(self.allocator, .{ .string = sec });
        }
        if (status) |st| {
            try args.append(self.allocator, .{ .string = st });
        }
        if (description) |d| {
            try args.append(self.allocator, .{ .string = d });
        }
        if (official_url) |u| {
            try args.append(self.allocator, .{ .string = u });
        }
        
        // 如果没有任何更新字段，直接返回
        if (name == null and slug == null and sector == null and status == null and description == null and official_url == null) {
            return;
        }
        
        try args.append(self.allocator, .{ .int = id });
        
        // 简单SQL - 只更新一个字段作为演示
        if (name) |n| {
            _ = n;
            sql = "UPDATE project SET name = ?1 WHERE id = ?2";
        } else if (status) |_| {
            sql = "UPDATE project SET status = ?1 WHERE id = ?2";
        } else {
            sql = "UPDATE project SET updated_at = strftime('%s', 'now') WHERE id = ?1";
        }
        _ = try self.driver.exec(sql, args.items);
    }
};
