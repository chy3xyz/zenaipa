//! Cache service — thin wrapper over zigmodu's LRU CacheManager.
//!
//! Values are arbitrary bytes (JSON strings work well). Keys are
//! namespaced by the caller, e.g. `user:42`, `kv:<key>`.
//!
//! 线程安全:CacheManager 本身按单线程设计,而 HTTP server 的多个连接是
//! 并发进来的 —— 所有 manager 访问都在本服务的互斥锁内串行化
//! (zweq 同修法)。loader 在锁外执行,避免慢加载器拖住其它请求。

const std = @import("std");
const zigmodu = @import("zigmodu");

pub const CacheService = struct {
    allocator: std.mem.Allocator,
    manager: zigmodu.data.CacheManager,
    mutex: std.Io.Mutex,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, max_entries: usize, ttl_seconds: u64) CacheService {
        return .{
            .allocator = allocator,
            .manager = zigmodu.data.CacheManager.init(allocator, max_entries, ttl_seconds, .LRU),
            .mutex = std.Io.Mutex.init,
            .io = io,
        };
    }

    pub fn deinit(self: *CacheService) void {
        // 先解锁再置 undefined:defer unlock 会读到 self.* = undefined 后的
        // 损坏 mutex 状态(switch on corrupt value)。临界区只有 O(1) map 析构。
        self.mutex.lockUncancelable(self.io);
        self.manager.deinit();
        self.mutex.unlock(self.io);
        self.* = undefined;
    }

    pub fn set(self: *CacheService, key: []const u8, value: []const u8) !void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        try self.manager.set(key, value);
    }

    /// Returns a cache-owned slice (do not free, do not keep across writes).
    pub fn get(self: *CacheService, key: []const u8) ?[]const u8 {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.manager.get(key);
    }

    /// Read-through: return the cached value or run `loader` (outside the
    /// lock), store the result and return it.
    pub fn getOrSet(self: *CacheService, key: []const u8, loader: *const fn (allocator: std.mem.Allocator) anyerror![]const u8) ![]const u8 {
        if (self.get(key)) |v| return v;
        const fresh = try loader(self.allocator);
        self.set(key, fresh) catch |err| {
            // 读穿语义:落缓存失败不掩盖加载结果,但必须留痕(值仍返回给调用方)。
            std.log.warn("[cache] set '{s}' failed after loader: {s}", .{ key, @errorName(err) });
        };
        return fresh;
    }

    pub fn remove(self: *CacheService, key: []const u8) bool {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.manager.remove(key);
    }

    pub fn count(self: *CacheService) usize {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.manager.count();
    }
};
