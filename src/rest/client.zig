const std = @import("std");
const Response = @import("response.zig").Response;
const RateLimiter = @import("rate_limiter.zig").RateLimiter;
const RestError = @import("errors.zig").RestError;
const fromStatus = @import("errors.zig").fromStatus;
const HeaderMap = @import("mod.zig").HeaderMap;

/// Authentication scheme for the Fluxer REST API.
pub const AuthType = enum {
    Session,
    Bearer,
    Bot,
    Admin,

    /// Returns the prefix used in the Authorization header for this auth type.
    pub fn token_prefix(self: AuthType) []const u8 {
        return switch (self) {
            .Session => "",
            .Bearer => "Bearer ",
            .Bot => "Bot ",
            .Admin => "Admin ",
        };
    }
};

/// Options for customizing an HTTP request.
pub const RequestOptions = struct {
    headers: ?HeaderMap = null,
    body: ?[]const u8 = null,
    query: ?[]const u8 = null,
};

/// Low-level HTTP client for the Fluxer REST API.
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    auth_type: AuthType = .Bot,
    base_url: []const u8 = "https://api.fluxer.app/v1",
    user_agent: []const u8 = "fluxer-zig/0.0.1",
    http_client: std.http.Client,
    rate_limiter: RateLimiter,

    /// Creates a new HttpClient with the specified authentication type.
    pub fn init(allocator: std.mem.Allocator, token: []const u8, auth_type: AuthType) !HttpClient {
        const token_copy = try allocator.dupe(u8, token);
        errdefer allocator.free(token_copy);
        return .{
            .allocator = allocator,
            .token = token_copy,
            .auth_type = auth_type,
            .http_client = std.http.Client{ .allocator = allocator },
            .rate_limiter = RateLimiter.init(allocator),
        };
    }

    /// Releases all resources owned by the client.
    pub fn deinit(self: *HttpClient) void {
        self.allocator.free(self.token);
        self.http_client.deinit();
        self.rate_limiter.deinit();
    }

    /// Performs a raw HTTP request.
    pub fn request(
        self: *HttpClient,
        method: std.http.Method,
        path: []const u8,
        options: RequestOptions,
    ) !Response {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{
            self.base_url,
            path,
            options.query orelse "",
        });
        defer self.allocator.free(url);

        const uri = try std.Uri.parse(url);

        var extra_headers = std.ArrayList(std.http.Header).init(self.allocator);
        defer {
            for (extra_headers.items) |h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            extra_headers.deinit();
        }

        const auth_value = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.auth_type.token_prefix(), self.token });
        defer self.allocator.free(auth_value);
        try extra_headers.append(.{
            .name = try self.allocator.dupe(u8, "Authorization"),
            .value = try self.allocator.dupe(u8, auth_value),
        });
        try extra_headers.append(.{
            .name = try self.allocator.dupe(u8, "User-Agent"),
            .value = try self.allocator.dupe(u8, self.user_agent),
        });

        if (options.headers) |opts_headers| {
            var it = opts_headers.iterator();
            while (it.next()) |entry| {
                try extra_headers.append(.{
                    .name = try self.allocator.dupe(u8, entry.name),
                    .value = try self.allocator.dupe(u8, entry.value),
                });
            }
        }

        var server_header_buffer: [16 * 1024]u8 = undefined;
        var req = try self.http_client.open(method, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = extra_headers.items,
            .headers = .{
                .content_type = if (options.body != null) .{ .override = "application/json" } else .default,
            },
        });
        defer req.deinit();

        if (options.body) |body| {
            req.transfer_encoding = .{ .content_length = body.len };
        }

        try self.rate_limiter.waitForRateLimit(path);

        try req.send();
        if (options.body) |body| {
            try req.writeAll(body);
        }
        try req.finish();
        try req.wait();

        var response_body = std.ArrayList(u8).init(self.allocator);
        errdefer response_body.deinit();
        try req.reader().readAllArrayList(&response_body, 10 * 1024 * 1024);

        var headers = try parseHeaders(self.allocator, req.response.parser.get());
        errdefer {
            headers.deinit();
        }

        const body_slice = try response_body.toOwnedSlice();

        var response = Response{
            .status = req.response.status,
            .headers = headers,
            .body = body_slice,
            .allocator = self.allocator,
        };

        self.rate_limiter.updateFromResponse(path, response);

        if (req.response.status.class() != .success and req.response.status.class() != .redirect) {
            defer response.deinit();
            return fromStatus(req.response.status, body_slice);
        }

        return response;
    }

    /// Convenience wrapper for GET.
    pub fn get(self: *HttpClient, path: []const u8) !Response {
        return self.request(.GET, path, .{});
    }

    /// Convenience wrapper for POST.
    pub fn post(self: *HttpClient, path: []const u8, body: ?[]const u8) !Response {
        return self.request(.POST, path, .{ .body = body });
    }

    /// Convenience wrapper for PATCH.
    pub fn patch(self: *HttpClient, path: []const u8, body: ?[]const u8) !Response {
        return self.request(.PATCH, path, .{ .body = body });
    }

    /// Convenience wrapper for PUT.
    pub fn put(self: *HttpClient, path: []const u8, body: ?[]const u8) !Response {
        return self.request(.PUT, path, .{ .body = body });
    }

    /// Convenience wrapper for DELETE.
    pub fn delete(self: *HttpClient, path: []const u8) !Response {
        return self.request(.DELETE, path, .{});
    }
};

fn parseHeaders(allocator: std.mem.Allocator, raw: []const u8) !HeaderMap {
    var map = HeaderMap.init(allocator);
    errdefer map.deinit();

    var lines = std.mem.splitSequence(u8, raw, "\r\n");
    // skip status line
    _ = lines.next();

    while (lines.next()) |line| {
        if (line.len == 0) break;
        if (std.mem.indexOfScalar(u8, line, ':')) |colon| {
            const name = std.mem.trim(u8, line[0..colon], " \t");
            const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
            if (name.len > 0) {
                try map.put(name, value);
            }
        }
    }
    return map;
}

test "HttpClient init without token" {
    const allocator = std.testing.allocator;
    var client = try HttpClient.init(allocator, "", .Bot);
    defer client.deinit();
    try std.testing.expectEqualStrings("", client.token);
    try std.testing.expectEqualStrings("https://api.fluxer.app/v1", client.base_url);
    try std.testing.expectEqual(.Bot, client.auth_type);
}

test "RequestOptions construction" {
    const opts = RequestOptions{
        .headers = null,
        .body = null,
        .query = null,
    };
    try std.testing.expect(opts.headers == null);
    try std.testing.expect(opts.body == null);
    try std.testing.expect(opts.query == null);
}