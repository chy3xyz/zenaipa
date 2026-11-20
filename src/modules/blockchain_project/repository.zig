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
        const sql =
            \\SELECT id, name, slug, sector, status, description, official_url
            \\FROM project WHERE id = ?1
        ;
        
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
        
        var items: std.ArrayList(ProjectRow) = .init(self.allocator);
        defer items.deinit();
        
        while (try rows.next()) |row| {
            try items.append(ProjectRow{
                .id = try row.getInt(0),
                .name = try self.allocator.dupe(u8, try row.getString(1)),
                .slug = try self.allocator.dupe(u8, try row.getString(2)),
                .sector = try self.allocator.dupe(u8, try row.getString(3)),
                .status = try self.allocator.dupe(u8, try row.getString(4)),
                .description = if (try row.getStringOpt(5)) |d| try self.allocator.dupe(u8, d) else null,
                .official_url = if (try row.getStringOpt(6)) |u| try self.allocator.dupe(u8, u) else null,
            });
        }
        
        // 获取总数
        var count_rows = try self.driver.query("SELECT COUNT(*) FROM project", &.{});
        defer count_rows.deinit();
        
        const total: i64 = if (try count_rows.next()) |row| try row.getInt(0) else 0;
        
        return ProjectListResult{
            .items = try items.toOwnedSlice(),
            .total = total,
        };
    }
    
    pub fn update(self: *ProjectRepository, id: i64, name: ?[]const u8, slug: ?[]const u8, sector: ?[]const u8, status: ?[]const u8, description: ?[]const u8, official_url: ?[]const u8) !void {
        // 动态构建UPDATE语句
        var sql_buf: std.ArrayList(u8) = .init(self.allocator);
        defer sql_buf.deinit();
        const writer = sql_buf.writer();
        
        try writer.writeAll("UPDATE project SET updated_at = strftime('%s', 'now')");
        
        var args = std.ArrayList(zent.sql.Value).init(self.allocator);
        defer args.deinit();
        
        if (name) |n| {
            try writer.writeAll(", name = ?");
            try writer.print("{d}", .{args.items.len + 1});
            try args.append(.{ .string = n });
        }
        if (slug) |s| {
            try writer.writeAll(", slug = ?");
            try writer.print("{d}", .{args.items.len + 1});
            try args.append(.{ .string = s });
        }
        if (sector) |sec| {
            try writer.writeAll(", sector = ?");
            try writer.print("{d}", .{args.items.len + 1});
            try args.append(.{ .string = sec });
        }
        if (status) |st| {
            try writer.writeAll(", status = ?");
            try writer.print("{d}", .{args.items.len + 1});
            try args.append(.{ .string = st });
        }
        if (description) |d| {
            try writer.writeAll(", description = ?");
            try writer.print("{d}", .{args.items.len + 1});
            try args.append(.{ .string = d });
        }
        if (official_url) |u| {
            try writer.writeAll(", official_url = ?");
            try writer.print("{d}", .{args.items.len + 1});
            try args.append(.{ .string = u });
        }
        
        try writer.writeAll(" WHERE id = ?");
        try writer.print("{d}", .{args.items.len + 1});
        try args.append(.{ .int = id });
        
        const sql = sql_buf.items;
        _ = try self.driver.exec(sql, args.items);
    }
};
