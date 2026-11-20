const std = @import("std");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    
    // Test 1: ArrayList initialization
    var items = std.ArrayList(u8).init(alloc);
    defer items.deinit();
    try items.append('A');
    std.debug.print("Test 1 OK: ArrayList.init\n", .{});
    
    // Test 2: Optional with if-else
    const opt_str: ?[]const u8 = null;
    const result: []const u8 = if (opt_str) |s| s else "default";
    std.debug.print("Test 2 OK: Optional if-else = {s}\n", .{result});
    
    // Test 3: Anonymous struct
    const MyStruct = struct { id: i64, name: []const u8 };
    const data = MyStruct{ .id = 1, .name = "test" };
    _ = data;
    std.debug.print("Test 3 OK: Struct creation\n", .{});
    
    std.debug.print("All syntax tests passed\n", .{});
}
