//! 出站 URL 白名单校验（OWASP API4 SSRF 基线）。
//! 服务端会主动请求管理员配置的 URL，写入口与服务端拉取前统一经本模块拦截
//! 非 http(s) 与字面内网地址。当前接入点：
//! - AI provider endpoint（ai/api.zig 创建/更新 provider 写入校验；
//!   ai/service.zig chat/checkProvider 出站前二次校验，防历史行绕过）。
//! 注：SMTP host 来自环境变量而非管理输入，不经本模块。

const std = @import("std");

/// 判断 URL 是否允许作为服务端出站请求目标：
/// scheme 必须 http/https、host 非空、且不是字面回环/内网地址。
///
/// 局限（按字面判断，仅作基线防护）：
/// - 不做 DNS 解析：域名解析到内网 IP（含 DNS rebinding）的情况防不住；
/// - 不识别 IP 的等价写法（十进制/十六进制整数形式、IPv6 映射地址等）；
/// - 完整防护需在出站连接层按解析后的真实 IP 二次拦截（egress 代理/网络策略）。
pub fn isAcceptableOutboundUrl(url: []const u8) bool {
    // scheme 只认 http/https（大小写不敏感），其余（ftp/file/无 scheme 等）一律拒绝。
    const rest = if (std.ascii.startsWithIgnoreCase(url, "https://"))
        url["https://".len..]
    else if (std.ascii.startsWithIgnoreCase(url, "http://"))
        url["http://".len..]
    else
        return false;

    // authority 段到首个 / ? # 为止。
    const authority_end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    var authority = rest[0..authority_end];

    // 剥离 userinfo（user:pass@host）：取最后一个 '@' 之后，防 http://x@127.0.0.1/ 字面绕过。
    if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| authority = authority[at + 1 ..];

    // host 段：IPv6 字面量带 [] 整段取；否则取到首个 ':'（端口分隔符）前。
    var host: []const u8 = undefined;
    if (authority.len > 0 and authority[0] == '[') {
        const close = std.mem.indexOfScalar(u8, authority, ']') orelse return false;
        host = authority[0 .. close + 1];
    } else {
        const colon = std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
        host = authority[0..colon];
    }
    if (host.len == 0) return false;

    return !isLiteralPrivateHost(host);
}

/// 字面回环/内网地址判断（不解析、不做 DNS）：
/// localhost、::1 与 [::1]、127. / 10. / 192.168. / 169.254. 前缀、172.16.–172.31. 段。
fn isLiteralPrivateHost(host: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(host, "localhost")) return true;
    if (std.mem.eql(u8, host, "::1") or std.mem.eql(u8, host, "[::1]")) return true;
    if (std.ascii.startsWithIgnoreCase(host, "127.")) return true;
    if (std.ascii.startsWithIgnoreCase(host, "10.")) return true;
    if (std.ascii.startsWithIgnoreCase(host, "192.168.")) return true;
    if (std.ascii.startsWithIgnoreCase(host, "169.254.")) return true;
    // 172.16.0.0 – 172.31.255.255：解析 "172." 后的第一段八位组。
    if (std.ascii.startsWithIgnoreCase(host, "172.")) {
        const second_end = std.mem.indexOfScalarPos(u8, host, 4, '.') orelse return false;
        const second = std.fmt.parseInt(u16, host[4..second_end], 10) catch return false;
        if (second >= 16 and second <= 31) return true;
    }
    return false;
}

test "url_guard rejects non-http schemes" {
    try std.testing.expect(!isAcceptableOutboundUrl("ftp://example.com"));
    try std.testing.expect(!isAcceptableOutboundUrl("file:///etc/passwd"));
    try std.testing.expect(!isAcceptableOutboundUrl("example.com"));
    try std.testing.expect(!isAcceptableOutboundUrl(""));
}

test "url_guard rejects literal loopback and private hosts" {
    try std.testing.expect(!isAcceptableOutboundUrl("http://localhost/api"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://127.0.0.1:8080/v1"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://10.0.0.1/"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://192.168.1.1/"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://169.254.169.254/latest/meta-data"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://172.16.0.1/"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://172.31.255.255/"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://[::1]/"));
    try std.testing.expect(!isAcceptableOutboundUrl("http://user:pass@127.0.0.1/"));
    // 172.32.0.1 在公网段,允许。
    try std.testing.expect(isAcceptableOutboundUrl("http://172.32.0.1/"));
}

test "url_guard accepts public http(s) urls" {
    try std.testing.expect(isAcceptableOutboundUrl("https://api.openai.com/v1/chat/completions"));
    try std.testing.expect(isAcceptableOutboundUrl("http://api.example.com:8080/v1"));
    try std.testing.expect(isAcceptableOutboundUrl("HTTPS://API.EXAMPLE.COM/path"));
}
