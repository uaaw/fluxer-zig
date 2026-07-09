const std = @import("std");
const HeaderMap = @import("mod.zig").HeaderMap;

/// Represents an HTTP response with parsed status, headers, and body.
pub const Response = struct {
    status: std.http.Status,
    headers: HeaderMap,
    body: []const u8,
    allocator: std.mem.Allocator,

    /// Deserializes the response body as JSON into type T.
    /// Caller owns the returned `std.json.Parsed(T)` and must call `deinit()`.
    /// Uses `.allocate = .alloc_always` so string slices are owned by the Parsed arena
    /// and remain valid until `parsed.deinit()`, even if this Response is deinited first.
    pub fn json(self: Response, comptime T: type) !std.json.Parsed(T) {
        return std.json.parseFromSlice(T, self.allocator, self.body, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        });
    }

    /// Returns the raw response body.
    pub fn text(self: Response) []const u8 {
        return self.body;
    }

    /// Releases all memory owned by this response.
    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        self.headers.deinit();
    }
};

/// Allocator that overwrites freed bytes so use-after-free on string slices is observable.
const PoisonAllocator = struct {
    parent: std.mem.Allocator,

    fn allocator(self: *PoisonAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const self: *PoisonAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawAlloc(len, ptr_align, ret_addr);
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *PoisonAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        const self: *PoisonAllocator = @ptrCast(@alignCast(ctx));
        @memset(buf, 0xDE);
        self.parent.rawFree(buf, buf_align, ret_addr);
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
    try headers.put("content-type", "application/json");

    var response = Response{
        .status = .ok,
        .headers = headers,
        .body = body,
        .allocator = allocator,
    };
    defer response.deinit();

    const parsed = try response.json(TestData);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u64, 12345), parsed.value.id);
    try std.testing.expectEqualStrings("test", parsed.value.name);
}

// Real regression: free Response (body) before reading Parsed string fields.
// Requires .allocate = .alloc_always and returning Parsed without early deinit.
// Old return-T-after-Parsed.deinit() poisons name (0xDE) under PoisonAllocator.
// Without alloc_always, name would point into freed body and also fail after response.deinit().
test "Response json string fields outlive Response body" {
    var poison = PoisonAllocator{ .parent = std.testing.allocator };
    const allocator = poison.allocator();

    const TestData = struct {
        id: u64,
        name: []const u8,
    };

    const raw_body = "{\"id\":1,\"name\":\"must_survive\"}";
    const body = try allocator.dupe(u8, raw_body);

    var headers = HeaderMap.init(allocator);
    try headers.put("content-type", "application/json");

    var response = Response{
        .status = .ok,
        .headers = headers,
        .body = body,
        .allocator = allocator,
    };

    const parsed = try response.json(TestData);
    defer parsed.deinit();

    // Body/header storage gone; strings must still be owned by Parsed.
    response.deinit();

    try std.testing.expectEqual(@as(u64, 1), parsed.value.id);
    try std.testing.expectEqualStrings("must_survive", parsed.value.name);
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
