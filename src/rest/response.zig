const std = @import("std");
const HeaderMap = @import("mod.zig").HeaderMap;

/// Represents an HTTP response with parsed status, headers, and body.
pub const Response = struct {
    status: std.http.Status,
    headers: HeaderMap,
    body: []const u8,
    allocator: std.mem.Allocator,

    /// Allocates memory. Caller owns the returned `std.json.Parsed(T)` and must call `deinit()`.
    /// Deserializes the response body as JSON into type T. String slices inside T remain
    /// valid only for the lifetime of the returned Parsed value.
    pub fn json(self: Response, comptime T: type) !std.json.Parsed(T) {
        return std.json.parseFromSlice(T, self.allocator, self.body, .{ .ignore_unknown_fields = true });
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

// Would fail under the old UAF pattern (return T after parsed.deinit()): poison-on-free
// overwrites string bytes so expectEqualStrings would not match.
test "Response json string fields remain valid until Parsed deinit" {
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
    defer response.deinit();

    // Old bug: parseFromSlice + defer parsed.deinit() + return parsed.value
    // would free (and poison) name before the caller could use it.
    const parsed = try response.json(TestData);
    defer parsed.deinit();

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
