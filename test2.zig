const std = @import("std");
pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var items = std.ArrayList(u8).init(alloc);
    defer items.deinit();
    try items.append('A');
    std.debug.print("OK\n", .{});
}
