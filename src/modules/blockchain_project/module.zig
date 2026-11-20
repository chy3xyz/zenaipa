const zmodu = @import("zmodu");

pub const info = zmodu.api.Module{
    .name = "blockchain_project",
    .description = "blockchain project management and evaluation",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}
