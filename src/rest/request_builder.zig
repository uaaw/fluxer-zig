const std = @import("std");
const HeaderMap = @import("mod.zig").HeaderMap;

/// Builder for constructing HTTP requests with a fluent API.
pub const RequestBuilder = struct {
    method: std.http.Method,
    path: []const u8,
    headers: HeaderMap,
    body: ?[]const u8,
    query: ?[]const u8,
    allocator: std.mem.Allocator,

    /// Creates a new RequestBuilder.
    pub fn init(allocator: std.mem.Allocator) RequestBuilder {
        return .{
            .method = .GET,
            .path = "",
            .headers = HeaderMap.init(allocator),
            .body = null,
            .query = null,
            .allocator = allocator,
        };
    }

    /// Sets the HTTP method.
    pub fn setMethod(self: *RequestBuilder, m: std.http.Method) *RequestBuilder {
        self.method = m;
        return self;
    }

    /// Sets the request path.
    pub fn setPath(self: *RequestBuilder, p: []const u8) *RequestBuilder {
        self.path = p;
        return self;
    }

    /// Adds a header. Value is duplicated.
    pub fn header(self: *RequestBuilder, k: []const u8, v: []const u8) *RequestBuilder {
        self.headers.put(k, v) catch unreachable;
        return self;
    }

    /// Serializes a value as JSON and sets it as the body.
    /// Allocates memory. Caller owns memory via deinit.
    pub fn bodyJson(self: *RequestBuilder, value: anytype) !*RequestBuilder {
        var list = std.ArrayList(u8).init(self.allocator);
        errdefer list.deinit();
        try std.json.stringify(value, .{}, list.writer());
        if (self.body) |old| self.allocator.free(old);
        self.body = try list.toOwnedSlice();
        return self;
    }

    /// Appends a query parameter.
    pub fn queryParam(self: *RequestBuilder, k: []const u8, v: []const u8) *RequestBuilder {
        const prefix = if (self.query == null) "?" else "&";
        const old = self.query;
        const new = std.fmt.allocPrint(self.allocator, "{s}{s}{s}={s}", .{ old orelse "", prefix, k, v }) catch unreachable;
        if (old) |o| self.allocator.free(o);
        self.query = new;
        return self;
    }

    /// Finalizes the builder. Returns internal state is now ready.
    pub fn build(self: *RequestBuilder) void {
        _ = self;
    }

    /// Releases all owned memory.
    pub fn deinit(self: *RequestBuilder) void {
        self.headers.deinit();
        if (self.body) |b| self.allocator.free(b);
        if (self.query) |q| self.allocator.free(q);
    }
};

test "RequestBuilder chain" {
    const allocator = std.testing.allocator;
    var builder = RequestBuilder.init(allocator);
    defer builder.deinit();

    _ = builder
        .setMethod(.POST)
        .setPath("/api/channels/123")
        .header("Content-Type", "application/json")
        .queryParam("limit", "10")
        .queryParam("after", "100");

    try std.testing.expectEqual(std.http.Method.POST, builder.method);
    try std.testing.expectEqualStrings("/api/channels/123", builder.path);
    try std.testing.expectEqualStrings("?limit=10&after=100", builder.query.?);
    try std.testing.expectEqualStrings("application/json", builder.headers.get("Content-Type").?);
}

test "RequestBuilder bodyJson" {
    const allocator = std.testing.allocator;
    var builder = RequestBuilder.init(allocator);
    defer builder.deinit();

    const Body = struct {
        content: []const u8,
    };
    _ = try builder.bodyJson(Body{ .content = "hello" });

    try std.testing.expectEqualStrings("{\"content\":\"hello\"}", builder.body.?);
}