const std = @import("std");
const zent = @import("zent");

pub fn runPublishMigrations(driver: *zent.sql_sqlite.SQLiteDriver) !void {
    // Published reports table - immutable snapshots of approved ratings
    const create_published_report_sql =
        \\CREATE TABLE IF NOT EXISTS published_report (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  rating_id INTEGER NOT NULL,
        \\  project_id INTEGER NOT NULL,
        \\  revision INTEGER NOT NULL,
        \\  
        \\  -- Grade and confidence
        \\  published_grade TEXT NOT NULL,
        \\  confidence INTEGER NOT NULL,
        \\  
        \\  -- Structured content layers
        \\  facts_json TEXT NOT NULL,
        \\  scores_json TEXT NOT NULL,
        \\  disclaimer_text TEXT NOT NULL,
        \\  conflict_disclosure TEXT NOT NULL,
        \\  
        \\  -- Evidence and sources
        \\  evidence_sources TEXT NOT NULL,
        \\  methodology_version TEXT NOT NULL,
        \\  
        \\  -- Provenance
        \\  content_hash TEXT NOT NULL UNIQUE,
        \\  analyst_id INTEGER NOT NULL,
        \\  reviewer_id INTEGER NOT NULL,
        \\  approved_at INTEGER NOT NULL,
        \\  published_at INTEGER NOT NULL,
        \\  publisher_id INTEGER NOT NULL,
        \\  
        \\  -- Status
        \\  status TEXT NOT NULL DEFAULT 'published',
        \\  revoked_at INTEGER,
        \\  revoker_id INTEGER,
        \\  
        \\  FOREIGN KEY(rating_id) REFERENCES rating_draft(id),
        \\  FOREIGN KEY(project_id) REFERENCES project(id)
        \\)
    ;
    _ = try driver.exec(create_published_report_sql, &.{});
    
    // Index for public queries
    _ = try driver.exec(
        "CREATE INDEX IF NOT EXISTS idx_published_project_status ON published_report(project_id, status)",
        &.{}
    );
    
    // Evidence sources registry
    const create_evidence_source_sql =
        \\CREATE TABLE IF NOT EXISTS evidence_source (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  rating_id INTEGER NOT NULL,
        \\  source_type TEXT NOT NULL,
        \\  source_url TEXT NOT NULL,
        \\  description TEXT,
        \\  registered_at INTEGER NOT NULL,
        \\  registered_by INTEGER NOT NULL,
        \\  FOREIGN KEY(rating_id) REFERENCES rating_draft(id)
        \\)
    ;
    _ = try driver.exec(create_evidence_source_sql, &.{});
}
