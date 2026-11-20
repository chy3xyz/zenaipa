const std = @import("std");
const zent = @import("zent");

pub fn runMigrations(driver: *zent.sql_sqlite.SQLiteDriver) !void {
    // 创建Project表（最小化版本）
    const create_project_sql =
        \\CREATE TABLE IF NOT EXISTS project (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  name TEXT NOT NULL,
        \\  slug TEXT NOT NULL UNIQUE,
        \\  sector TEXT NOT NULL DEFAULT 'Other',
        \\  status TEXT NOT NULL DEFAULT 'active',
        \\  description TEXT,
        \\  official_url TEXT,
        \\  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        \\  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        \\);
    ;
    
    _ = try driver.exec(create_project_sql, &.{});
    
    // 创建索引
    _ = try driver.exec(
        "CREATE INDEX IF NOT EXISTS idx_project_sector_status ON project(sector, status);",
        &.{},
    );
    _ = try driver.exec(
        "CREATE INDEX IF NOT EXISTS idx_project_slug ON project(slug);",
        &.{},
    );
}
