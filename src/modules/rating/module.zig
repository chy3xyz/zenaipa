const zmodu = @import("zmodu");

pub const info = zmodu.api.Module{
    .name = "rating",
    .description = "rating engine and review workflow",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}
