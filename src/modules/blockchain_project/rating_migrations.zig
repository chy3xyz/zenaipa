const std = @import("std");
const zent = @import("zent");

pub fn runRatingMigrations(driver: *zent.sql_sqlite.SQLiteDriver) !void {
    const create_rating_draft_sql =
        \\CREATE TABLE IF NOT EXISTS rating_draft (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  project_id INTEGER NOT NULL,
        \\  model_version TEXT NOT NULL,
        \\  input_json TEXT NOT NULL,
        \\  c1_tech INTEGER,
        \\  c2_team INTEGER,
        \\  c3_token INTEGER,
        \\  c4_product INTEGER,
        \\  c5_community INTEGER,
        \\  c6_governance INTEGER,
        \\  confidence INTEGER NOT NULL,
        \\  red_flags TEXT,
        \\  base_grade TEXT NOT NULL,
        \\  redflag_grade TEXT NOT NULL,
        \\  shadow_grade TEXT NOT NULL,
        \\  published_grade TEXT NOT NULL,
        \\  created_by INTEGER NOT NULL,
        \\  is_draft INTEGER NOT NULL DEFAULT 1,
        \\  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        \\  FOREIGN KEY (project_id) REFERENCES project(id),
        \\  FOREIGN KEY (created_by) REFERENCES user(id)
        \\);
    ;
    
    _ = try driver.exec(create_rating_draft_sql, &.{});
    
    _ = try driver.exec(
        "CREATE INDEX IF NOT EXISTS idx_rating_draft_project ON rating_draft(project_id);",
        &.{},
    );
}
