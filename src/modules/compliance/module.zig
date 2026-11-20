const zmodu = @import("zmodu");

pub const info = zmodu.api.Module{
    .name = "compliance",
    .description = "compliance gates and publish control",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}
