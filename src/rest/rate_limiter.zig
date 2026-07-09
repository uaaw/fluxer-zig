const std = @import("std");
const Response = @import("response.zig").Response;
const Bucket = @import("bucket.zig").Bucket;
const BucketState = @import("bucket.zig").BucketState;
const HeaderMap = @import("mod.zig").HeaderMap;

/// Manages per-route and global rate limits.
pub const RateLimiter = struct {
    global_limit: u32 = 50,
    global_remaining: u32 = 50,
    global_reset: i64 = 0,
    buckets: std.StringArrayHashMap(Bucket),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RateLimiter {
        return .{
            .global_limit = 50,
            .global_remaining = 50,
            .global_reset = 0,
            .buckets = std.StringArrayHashMap(Bucket).init(allocator),
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RateLimiter) void {
        var it = self.buckets.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.buckets.deinit();
    }

    /// Ensures a bucket exists for `route`, owning a duplicated key.
    fn ensureBucket(self: *RateLimiter, route: []const u8) !*Bucket {
        const gop = try self.buckets.getOrPut(route);
        if (!gop.found_existing) {
            // StringArrayHashMap stores the provided key slice; caller routes are often
            // temporary path buffers, so always own a copy.
            errdefer _ = self.buckets.swapRemove(route);
            gop.key_ptr.* = try self.allocator.dupe(u8, route);
            gop.value_ptr.* = Bucket.init(self.allocator);
        }
        return gop.value_ptr;
    }

    /// Waits for both bucket and global rate limits, then atomically decrements.
    /// Call this BEFORE executing the HTTP request.
    pub fn waitForRateLimit(self: *RateLimiter, route: []const u8) !void {
        while (true) {
            self.mutex.lock();
            const bucket = self.ensureBucket(route) catch |err| {
                self.mutex.unlock();
                return err;
            };
            const can_exec = bucket.canExecute();
            self.mutex.unlock();
            if (can_exec) break;
            std.time.sleep(100 * std.time.ns_per_ms);
        }

        while (true) {
            self.mutex.lock();
            const now = std.time.timestamp();
            if (now >= self.global_reset) {
                self.global_remaining = self.global_limit;
                self.global_reset = 0;
            }
            if (self.global_remaining > 0) {
                self.global_remaining -= 1;
                self.mutex.unlock();
                break;
            }
            self.mutex.unlock();
            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }

    /// Submits a request, respecting rate limits.
    pub fn submit(
        self: *RateLimiter,
        route: []const u8,
        execute_fn: *const fn () anyerror!Response,
    ) !Response {
        self.mutex.lock();
        const bucket = self.ensureBucket(route) catch |err| {
            self.mutex.unlock();
            return err;
        };
        self.mutex.unlock();

        // Wait for bucket rate limit
        while (true) {
            if (bucket.canExecute()) break;
            const now = std.time.timestamp();
            if (bucket.reset > now) {
                const wait_ns = @as(u64, @intCast(bucket.reset - now)) * std.time.ns_per_s;
                std.time.sleep(wait_ns);
            } else {
                break;
            }
        }

        // Wait for global rate limit
        while (true) {
            self.mutex.lock();
            const gr = self.global_remaining;
            const greset = self.global_reset;
            self.mutex.unlock();
            if (gr > 0 or std.time.timestamp() >= greset) break;
            const wait_ns = @as(u64, @intCast(greset - std.time.timestamp())) * std.time.ns_per_s;
            std.time.sleep(wait_ns);
        }

        var response = try execute_fn();

        // Update bucket from response headers
        self.updateFromResponse(route, response);

        // Handle 429
        if (response.status == .too_many_requests) {
            const retry_after = if (response.headers.get("retry-after")) |v|
                std.fmt.parseInt(u64, v, 10) catch 1
            else
                1;
            response.deinit();
            std.time.sleep(retry_after * std.time.ns_per_s);
            response = try execute_fn();
            self.updateFromResponse(route, response);
        }

        return response;
    }

    /// Returns the current state of a bucket, or null if unknown.
    pub fn bucketState(self: *RateLimiter, route: []const u8) ?BucketState {
        self.mutex.lock();
        defer self.mutex.unlock();
        const bucket = self.buckets.get(route) orelse return null;
        return .{
            .limit = bucket.limit,
            .remaining = bucket.remaining,
            .reset = bucket.reset,
            .reset_after = bucket.reset_after,
        };
    }

    /// Returns the remaining global quota.
    pub fn globalLimitRemaining(self: *RateLimiter) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (std.time.timestamp() >= self.global_reset) {
            self.global_remaining = self.global_limit;
        }
        return self.global_remaining;
    }

    /// Updates bucket and global limits from a response.
    pub fn updateFromResponse(self: *RateLimiter, route: []const u8, response: Response) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const bucket = self.buckets.getPtr(route) orelse return;
        bucket.updateFromHeaders(response.headers);

        if (response.headers.get("x-ratelimit-global")) |_| {
            const retry_after = if (response.headers.get("retry-after")) |v|
                std.fmt.parseInt(i64, v, 10) catch 0
            else
                0;
            self.global_reset = std.time.timestamp() + retry_after;
            self.global_remaining = 0;
        }
    }
};

test "RateLimiter submit and update" {
    const allocator = std.testing.allocator;
    var limiter = RateLimiter.init(allocator);
    defer limiter.deinit();

    const mockExecute = struct {
        fn call() anyerror!Response {
            const alloc = std.testing.allocator;
            var headers = HeaderMap.init(alloc);
            try headers.put("x-ratelimit-limit", "5");
            try headers.put("x-ratelimit-remaining", "4");
            try headers.put("x-ratelimit-reset", "9999999999");
            try headers.put("x-ratelimit-reset-after", "60");
            return Response{
                .status = .ok,
                .headers = headers,
                .body = try alloc.dupe(u8, ""),
                .allocator = alloc,
            };
        }
    }.call;

    var response = try limiter.submit("/channels/123", mockExecute);
    defer response.deinit();

    try std.testing.expectEqual(std.http.Status.ok, response.status);
    const state = limiter.bucketState("/channels/123").?;
    try std.testing.expectEqual(@as(u32, 5), state.limit);
    try std.testing.expectEqual(@as(u32, 4), state.remaining);
}

test "RateLimiter global limit" {
    const allocator = std.testing.allocator;
    var limiter = RateLimiter.init(allocator);
    defer limiter.deinit();

    try std.testing.expectEqual(@as(u32, 50), limiter.globalLimitRemaining());

    limiter.global_remaining = 0;
    limiter.global_reset = std.time.timestamp() - 1;
    try std.testing.expectEqual(@as(u32, 50), limiter.globalLimitRemaining());
}

// Regression: routes are often temporary path buffers freed after the request.
// Bucket map keys must be owned copies so later lookups/deinit stay valid.
test "RateLimiter owns route key after temporary path freed" {
    const allocator = std.testing.allocator;
    var limiter = RateLimiter.init(allocator);
    defer limiter.deinit();

    {
        const temp_path = try std.fmt.allocPrint(allocator, "/applications/{d}/commands", .{123456789012345678});
        defer allocator.free(temp_path);
        try limiter.waitForRateLimit(temp_path);
    }

    // temp_path is freed; key must still be reachable and freeable via deinit.
    const state = limiter.bucketState("/applications/123456789012345678/commands");
    try std.testing.expect(state != null);
}