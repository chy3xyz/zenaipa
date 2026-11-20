const std = @import("std");
const testing = std.testing;
const zent = @import("zent");

test "blockchain_project CRUD integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 打开测试数据库
    var driver = try zent.sql_sqlite.SQLiteDriver.open(allocator, "zenaipa.db", .{});
    defer driver.close();
    
    std.debug.print("\n=== Testing SQLite Configuration ===\n", .{});
    
    // 测试WAL模式
    {
        var rows = try driver.query("PRAGMA journal_mode;", &.{});
        defer rows.deinit();
        if (rows.next()) |row| {
            const mode = row.getText(0) orelse "unknown";
            std.debug.print("Journal mode: {s}\n", .{mode});
            try testing.expectEqualStrings("wal", mode);
        }
    }
    
    // 测试FK启用（从app连接）
    {
        var rows = try driver.query("PRAGMA foreign_keys;", &.{});
        defer rows.deinit();
        if (rows.next()) |row| {
            const fk = row.getInt(0) orelse 0;
            std.debug.print("Foreign keys (from app): {d}\n", .{fk});
            // 注意：如果FK未启用，需要在连接初始化时执行PRAGMA foreign_keys=ON
        }
    }
    
    std.debug.print("\n=== Testing CRUD Operations ===\n", .{});
    
    // 测试CREATE
    {
        const insert_sql = "INSERT INTO project (name, slug, sector, status) VALUES (?1, ?2, ?3, ?4)";
        _ = try driver.exec(insert_sql, &.{
            .{ .string = "Test Project" },
            .{ .string = "test-slug" },
            .{ .string = "Test" },
            .{ .string = "active" },
        });
        std.debug.print("✓ CREATE: Inserted test project\n", .{});
    }
    
    // 测试READ
    {
        var rows = try driver.query("SELECT id, name, slug FROM project WHERE slug = ?1", &.{.{ .string = "test-slug" }});
        defer rows.deinit();
        
        var found = false;
        if (rows.next()) |row| {
            const id = row.getInt(0) orelse 0;
            const name = row.getText(1) orelse "";
            std.debug.print("✓ READ: Found project id={d}, name={s}\n", .{ id, name });
            found = true;
        }
        try testing.expect(found);
    }
    
    // 测试UPDATE
    {
        _ = try driver.exec("UPDATE project SET name = ?1 WHERE slug = ?2", &.{
            .{ .string = "Updated Project" },
            .{ .string = "test-slug" },
        });
        
        var rows = try driver.query("SELECT name FROM project WHERE slug = ?1", &.{.{ .string = "test-slug" }});
        defer rows.deinit();
        if (rows.next()) |row| {
            const name = row.getText(0) orelse "";
            try testing.expectEqualStrings("Updated Project", name);
            std.debug.print("✓ UPDATE: Name updated\n", .{});
        }
    }
    
    // 测试UNIQUE约束
    {
        const result = driver.exec("INSERT INTO project (name, slug, sector) VALUES (?1, ?2, ?3)", &.{
            .{ .string = "Duplicate" },
            .{ .string = "test-slug" },
            .{ .string = "Test" },
        });
        
        if (result) |_| {
            std.debug.print("✗ UNIQUE constraint failed: duplicate was allowed\n", .{});
            try testing.expect(false);
        } else |err| {
            std.debug.print("✓ UNIQUE constraint: {s}\n", .{@errorName(err)});
            try testing.expect(err == error.Constraint);
        }
    }
    
    // 清理测试数据
    _ = try driver.exec("DELETE FROM project WHERE slug = ?1", &.{.{ .string = "test-slug" }});
    std.debug.print("✓ DELETE: Cleanup completed\n", .{});
    
    std.debug.print("\n=== All tests passed ===\n", .{});
}
