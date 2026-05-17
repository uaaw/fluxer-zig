const std = @import("std");
const HeaderMap = @import("mod.zig").HeaderMap;

/// Represents an HTTP response with parsed status, headers, and body.
pub const Response = struct {
    status: std.http.Status,
    headers: HeaderMap,
    body: []const u8,
    allocator: std.mem.Allocator,

    /// Allocates memory. Caller owns returned memory.
    /// Deserializes the response body as JSON into type T.
    pub fn json(self: Response, comptime T: type) !T {
        const parsed = try std.json.parseFromSlice(T, self.allocator, self.body, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    /// Returns the raw response body.
    pub fn text(self: Response) []const u8 {
        return self.body;
    }

    /// Releases all memory owned by this response.
    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }
};

test "Response json parsing" {
    const allocator = std.testing.allocator;

    const TestData = struct {
        id: u64,
        name: []const u8,
    };

    const raw_body = "{\"id\":12345,\"name\":\"test\"}";
    const body = try allocator.dupe(u8, raw_body);

    var headers = HeaderMap.init(allocator);
    try headers.put(try allocator.dupe(u8, "content-type"), try allocator.dupe(u8, "application/json"));

    var response = Response{
        .status = .ok,
        .headers = headers,
        .body = body,
        .allocator = allocator,
    };
    defer response.deinit();

    const data = try response.json(TestData);
    try std.testing.expectEqual(@as(u64, 12345), data.id);
    try std.testing.expectEqualStrings("test", data.name);
}

test "Response text returns raw body" {
    const allocator = std.testing.allocator;

    const raw_body = "raw text";
    const body = try allocator.dupe(u8, raw_body);

    const headers = HeaderMap.init(allocator);

    var response = Response{
        .status = .ok,
        .headers = headers,
        .body = body,
        .allocator = allocator,
    };
    defer response.deinit();

    try std.testing.expectEqualStrings("raw text", response.text());
}