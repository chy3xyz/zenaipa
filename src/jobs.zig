//! Background task handlers registered with the task Dispatcher.

const std = @import("std");
const mail = @import("services/mail.zig");
const task_svc = @import("modules/task/service.zig");

/// `mail.send` — payload is JSON: {"to": "...", "subject": "...", "text": "..."}.
///
/// 载荷问题（JSON 不合法/缺字段/类型不符）必须返回错误而不是静默 return：
/// 返回错误走 markFailedOrRetry（预算内重试、last_error 留痕），静默 return
/// 会把坏任务记成 done。字段类型先校验再解引用——错类型字段直接取 `.string`
/// 会得到 null，炸掉 dispatcher 线程并卡死整个队列（zweq 第 127 批同修法）。
pub fn mailSend(ctx: ?*anyopaque, allocator: std.mem.Allocator, io: std.Io, payload: []const u8) anyerror!void {
    _ = io;
    const mailer: *mail.Mailer = @ptrCast(@alignCast(ctx orelse return error.NoHandlerContext));
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, payload, .{}) catch return error.InvalidPayload;
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidPayload;
    const obj = parsed.value.object;
    const to = obj.get("to") orelse return error.MissingField;
    const subject = obj.get("subject") orelse return error.MissingField;
    const text = obj.get("text") orelse return error.MissingField;
    if (to != .string or subject != .string or text != .string) return error.InvalidPayload;
    mailer.send(.{
        .to = to.string,
        .subject = subject.string,
        .text = text.string,
    });
}

/// The handler registry for this application. `mailer` must outlive the
/// dispatcher.
pub fn handlers(mailer: *const mail.Mailer) [1]task_svc.Handler {
    return .{
        .{
            .name = "mail.send",
            .ctx = @ptrCast(@alignCast(@constCast(mailer))),
            .run = mailSend,
        },
    };
}
