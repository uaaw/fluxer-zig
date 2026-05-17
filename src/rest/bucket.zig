const std = @import("std");
const HeaderMap = @import("mod.zig").HeaderMap;

/// Tracks rate-limit state for a single route bucket.
pub const Bucket = struct {
    limit: u32,
    remaining: u32,
    reset: i64,
    reset_after: f64,
    bucket_id: ?[]const u8,
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    /// Initializes a new Bucket with default values.
    pub fn init(allocator: std.mem.Allocator) Bucket {
        return .{
            .limit = 1,
            .remaining = 1,
            .reset = 0,
            .reset_after = 0,
            .bucket_id = null,
            .mutex = .{},
            .allocator = allocator,
        };
    }

    /// Releases memory owned by the bucket.
    pub fn deinit(self: *Bucket) void {
        if (self.bucket_id) |id| {
            self.allocator.free(id);
        }
    }

    /// Returns true if the bucket's reset time has passed.
    pub fn isExpired(self: *Bucket) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return std.time.timestamp() >= self.reset;
    }

    /// Returns true if the bucket has remaining capacity or has expired.
    pub fn canExecute(self: *Bucket) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const now = std.time.timestamp();
        if (now >= self.reset) {
            self.remaining = self.limit;
            return true;
        }
        return self.remaining > 0;
    }

    /// Updates bucket state from Fluxer API response headers.
    pub fn updateFromHeaders(self: *Bucket, headers: HeaderMap) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (headers.get("x-ratelimit-limit")) |v| {
            self.limit = std.fmt.parseInt(u32, v, 10) catch self.limit;
        }
        if (headers.get("x-ratelimit-remaining")) |v| {
            self.remaining = std.fmt.parseInt(u32, v, 10) catch self.remaining;
        }
        if (headers.get("x-ratelimit-reset")) |v| {
            const f = std.fmt.parseFloat(f64, v) catch @as(f64, @floatFromInt(self.reset));
            self.reset = @intFromFloat(f);
        }
        if (headers.get("x-ratelimit-reset-after")) |v| {
            self.reset_after = std.fmt.parseFloat(f64, v) catch self.reset_after;
        }
        if (headers.get("x-ratelimit-bucket")) |v| {
            const new_id = self.allocator.dupe(u8, v) catch return;
            if (self.bucket_id) |old| self.allocator.free(old);
            self.bucket_id = new_id;
        }
    }
};

/// Snapshot of a bucket's state for observation.
pub const BucketState = struct {
    limit: u32,
    remaining: u32,
    reset: i64,
    reset_after: f64,
};

test "Bucket canExecute and isExpired" {
    var bucket = Bucket.init(std.testing.allocator);
    defer bucket.deinit();
    try std.testing.expect(bucket.canExecute());

    bucket.remaining = 0;
    bucket.reset = std.time.timestamp() + 100;
    try std.testing.expect(!bucket.canExecute());

    bucket.reset = std.time.timestamp() - 1;
    try std.testing.expect(bucket.canExecute());
    try std.testing.expect(bucket.isExpired());
}

test "Bucket updateFromHeaders" {
    var bucket = Bucket.init(std.testing.allocator);
    defer bucket.deinit();
    var headers = HeaderMap.init(std.testing.allocator);
    defer headers.deinit();

    try headers.put("x-ratelimit-limit", "5");
    try headers.put("x-ratelimit-remaining", "3");
    try headers.put("x-ratelimit-reset", "1893456000");
    try headers.put("x-ratelimit-reset-after", "60.5");
    try headers.put("x-ratelimit-bucket", "abc123");

    bucket.updateFromHeaders(headers);

    try std.testing.expectEqual(@as(u32, 5), bucket.limit);
    try std.testing.expectEqual(@as(u32, 3), bucket.remaining);
    try std.testing.expectEqual(@as(i64, 1893456000), bucket.reset);
    try std.testing.expectApproxEqRel(@as(f64, 60.5), bucket.reset_after, 0.001);
    try std.testing.expectEqualStrings("abc123", bucket.bucket_id.?);
}