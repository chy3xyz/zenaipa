//! Security response headers (HSTS, X-Frame-Options, nosniff, referrer
//! policy, download/ DNS protections) — zmodu defaults, one call.

const zmodu = @import("zmodu");
const http = zmodu.http;

pub fn securityHeaders() !http.Middleware {
    return try http.http_middleware.securityHeaders(null);
}
