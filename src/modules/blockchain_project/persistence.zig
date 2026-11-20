const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");

const schema = @import("../../schema.zig");
const infos = schema.infos;
const ProjectInfo = infos[14]; // blockchain_project_model.Project在buildGraph中的索引
const Client = schema.Client;

pub const ProjectRow = struct {
    id: i64,
    name: []const u8,
    slug: []const u8,
    sector: []const u8,
    status: []const u8,
    description: []const u8,
    website: []const u8,
    
    pub fn free(self: ProjectRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.slug);
        allocator.free(self.sector);
        allocator.free(self.status);
        allocator.free(self.description);
        allocator.free(self.website);
    }
};

pub const ProjectListResult = struct {
    items: []ProjectRow,
    total: i64,
    
    pub fn free(self: *ProjectListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const ListParams = struct {
    limit: i32,
    offset: i32,
    sector: ?[]const u8,
    status: ?[]const u8,
    keyword: ?[]const u8,
};

pub const ProjectStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(client: *Client) ProjectStore {
        return .{ .allocator = client.allocator, .client = client.* };
    }

    fn dupProject(self: *ProjectStore, e: anytype) !ProjectRow {
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const slug = try self.allocator.dupe(u8, e.slug);
        errdefer self.allocator.free(slug);
        const sector = try self.allocator.dupe(u8, e.sector);
        errdefer self.allocator.free(sector);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const desc = if (e.description) |d| try self.allocator.dupe(u8, d) else try self.allocator.dupe(u8, "");
        errdefer self.allocator.free(desc);
        const web = if (e.official_url) |w| try self.allocator.dupe(u8, w) else try self.allocator.dupe(u8, "");
        errdefer self.allocator.free(web);
        
        return .{
            .id = e.id,
            .name = name,
            .slug = slug,
            .sector = sector,
            .status = status,
            .description = desc,
            .website = web,
        };
    }

    pub fn create(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        data: anytype,
    ) !i64 {
        _ = alloc;
        var b = try self.client.project.Create();
        defer b.deinit();
        
        _ = try b.setFieldValue("name", data.name);
        _ = try b.setFieldValue("slug", data.slug);
        _ = try b.setFieldValue("sector", data.sector);
        _ = try b.setFieldValue("status", data.status);
        if (data.description) |desc| {
            _ = try b.setFieldValue("description", desc);
        }
        if (data.website) |web| {
            _ = try b.setFieldValue("official_url", web);
        }
        
        var row = try b.Save();
        defer zent.codegen.deinitEntity(infos, ProjectInfo, &row, self.allocator);
        return row.id;
    }

    pub fn getById(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        id: i64,
    ) !?ProjectRow {
        _ = alloc;
        var entity = (try crud.get(self.client.project, id)) orelse return null;
        defer zent.codegen.deinitEntity(infos, ProjectInfo, &entity, self.allocator);
        return try self.dupProject(entity);
    }

    pub fn getBySlug(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        slug: []const u8,
    ) !?ProjectRow {
        _ = alloc;
        var preds = [_]zent.sql.Predicate{
            zent.sql.Predicate.init("slug", .eq, slug),
        };
        var q = self.client.project.Query();
        q = q.Where(&preds);
        const rows = q.All(self.allocator);
        if (rows.len == 0) return null;
        
        const entity = rows[0];
        defer zent.codegen.deinitEntity(infos, ProjectInfo, &entity, self.allocator);
        return try self.dupProject(entity);
    }

    pub fn list(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        params: ListParams,
    ) !ProjectListResult {
        _ = alloc;
        _ = params.sector;
        _ = params.status;
        _ = params.keyword;
        
        var q = self.client.project.Query();
        defer q.deinit();
        _ = q.Limit(@intCast(params.limit));
        _ = q.Offset(@intCast(params.offset));
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        
        var rows = try q.All();
        defer {
            for (rows.items) |*e| zent.codegen.deinitEntity(infos, ProjectInfo, e, self.allocator);
            rows.deinit();
        }
        const count = try q.Count();
        
        var out = try self.allocator.alloc(ProjectRow, rows.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items) |e| {
            out[n] = try self.dupProject(e);
            n += 1;
        }
        
        return .{ .items = out, .total = count };
    }

    pub fn updateById(
        self: *ProjectStore,
        alloc: std.mem.Allocator,
        id: i64,
        data: anytype,
    ) !void {
        _ = alloc;
        var old_entity = (try crud.get(self.client.project, id)) orelse return error.NotFound;
        defer zent.codegen.deinitEntity(infos, ProjectInfo, &old_entity, self.allocator);
        
        var upd = self.client.project.Update();
        defer upd.deinit();
        _ = try upd.Where(.{self.client.project.predicates.idEQ(.{ .int = id })});
        
        if (data.name) |name| _ = try upd.setFieldValue("name", name);
        if (data.status) |status| _ = try upd.setFieldValue("status", status);
        if (data.description) |desc| _ = try upd.setFieldValue("description", desc);
        if (data.website) |web| _ = try upd.setFieldValue("official_url", web);
        
        _ = try upd.Save();
    }
};
