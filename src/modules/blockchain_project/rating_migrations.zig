const std = @import("std");
const zent = @import("zent");

pub fn runRatingMigrations(driver: *zent.sql_sqlite.SQLiteDriver) !void {
    // Try to add new columns (idempotent - fails silently if exists)
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN analyst_id INTEGER", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN reviewer_id INTEGER", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN status TEXT DEFAULT 'draft'", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN revision INTEGER DEFAULT 1", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN submitted_at INTEGER", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN reviewed_at INTEGER", &.{}) catch {};
    
    // Report content fields (frozen at submit, approved by reviewer)
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN report_facts_json TEXT", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN report_disclaimer TEXT", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN report_conflict TEXT", &.{}) catch {};
    _ = driver.exec("ALTER TABLE rating_draft ADD COLUMN content_hash TEXT", &.{}) catch {};
    
    // Migrate old created_by to analyst_id if needed
    _ = driver.exec("UPDATE rating_draft SET analyst_id = created_by WHERE analyst_id IS NULL AND created_by IS NOT NULL", &.{}) catch {};
    
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
        \\  analyst_id INTEGER NOT NULL,
        \\  reviewer_id INTEGER,
        \\  status TEXT NOT NULL DEFAULT 'draft',
        \\  revision INTEGER NOT NULL DEFAULT 1,
        \\  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        \\  submitted_at INTEGER,
        \\  reviewed_at INTEGER,
        \\  report_facts_json TEXT,
        \\  report_disclaimer TEXT,
        \\  report_conflict TEXT,
        \\  content_hash TEXT,
        \\  FOREIGN KEY (project_id) REFERENCES project(id),
        \\  FOREIGN KEY (analyst_id) REFERENCES user(id),
        \\  FOREIGN KEY (reviewer_id) REFERENCES user(id),
        \\  CHECK (status IN ('draft', 'submitted', 'approved', 'rejected'))
        \\);
    ;
    
    _ = try driver.exec(create_rating_draft_sql, &.{});
    
    _ = try driver.exec(
        "CREATE INDEX IF NOT EXISTS idx_rating_draft_project ON rating_draft(project_id);",
        &.{},
    );
    
    _ = try driver.exec(
        "CREATE INDEX IF NOT EXISTS idx_rating_draft_status ON rating_draft(status);",
        &.{},
    );
    
    // Audit log for rating approval workflow
    const create_audit_sql =
        \\CREATE TABLE IF NOT EXISTS rating_audit (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  rating_id INTEGER NOT NULL,
        \\  actor_id INTEGER NOT NULL,
        \\  action TEXT NOT NULL,
        \\  from_status TEXT,
        \\  to_status TEXT NOT NULL,
        \\  revision INTEGER NOT NULL,
        \\  comment TEXT,
        \\  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        \\  FOREIGN KEY (rating_id) REFERENCES rating_draft(id),
        \\  FOREIGN KEY (actor_id) REFERENCES user(id),
        \\  CHECK (action IN ('create', 'submit', 'approve', 'reject'))
        \\);
    ;
    
    _ = try driver.exec(create_audit_sql, &.{});
    
    _ = try driver.exec(
        "CREATE INDEX IF NOT EXISTS idx_rating_audit_rating ON rating_audit(rating_id);",
        &.{},
    );
}
