const std = @import("std");
const Shard = @import("shard.zig").Shard;
const ShardStatus = @import("shard.zig").ShardStatus;
const Snowflake = @import("../models/snowflake.zig").Snowflake;

/// Manages multiple gateway shards for large-scale bots.
pub const ShardManager = struct {
    shards: []Shard,
    num_shards: u32,
    token: []const u8,
    intents: u64,
    allocator: std.mem.Allocator,

    /// Allocates memory. Caller owns returned memory.
    pub fn init(allocator: std.mem.Allocator, num_shards: u32, token: []const u8, intents: u64) !ShardManager {
        const token_copy = try allocator.dupe(u8, token);
        errdefer allocator.free(token_copy);

        const shards = try allocator.alloc(Shard, num_shards);
        errdefer allocator.free(shards);

        const total_shards: u16 = @intCast(num_shards);
        for (0..num_shards) |i| {
            shards[i] = Shard.init(allocator, @intCast(i), total_shards, token_copy);
            shards[i].intents = @intCast(intents);
        }

        return .{
            .shards = shards,
            .num_shards = num_shards,
            .token = token_copy,
            .intents = intents,
            .allocator = allocator,
        };
    }

    /// Releases all resources owned by the manager.
    pub fn deinit(self: *ShardManager) void {
        self.stopAll();
        self.allocator.free(self.shards);
        self.allocator.free(self.token);
    }

    /// Starts all shards in parallel on separate threads.
    pub fn startAll(self: *ShardManager) !void {
        for (self.shards) |*shard| {
            const thread = try std.Thread.spawn(.{}, Shard.connect, .{shard});
            thread.detach();
        }
    }

    /// Disconnects all shards.
    pub fn stopAll(self: *ShardManager) void {
        for (self.shards) |*shard| {
            shard.disconnect();
        }
    }

    /// Returns the shard responsible for the given guild ID.
    pub fn getShard(self: *ShardManager, guild_id: Snowflake) *Shard {
        const shard_id: usize = @intCast((guild_id.value >> 22) % self.num_shards);
        return &self.shards[shard_id];
    }

    /// Allocates memory. Caller owns returned memory.
    /// Returns the status of all shards.
    pub fn shardStatus(self: ShardManager) ![]ShardStatus {
        const statuses = try self.allocator.alloc(ShardStatus, self.shards.len);
        for (self.shards, 0..) |shard, i| {
            statuses[i] = shard.status;
        }
        return statuses;
    }
};

test "ShardManager init and deinit" {
    const allocator = std.testing.allocator;
    var manager = try ShardManager.init(allocator, 4, "test_token", 1 << 0);
    defer manager.deinit();

    try std.testing.expectEqual(@as(u32, 4), manager.num_shards);
    try std.testing.expectEqual(@as(u64, 1 << 0), manager.intents);
    try std.testing.expectEqual(@as(usize, 4), manager.shards.len);
}

test "ShardManager getShard calculation" {
    const allocator = std.testing.allocator;
    var manager = try ShardManager.init(allocator, 4, "test_token", 0);
    defer manager.deinit();

    const guild_id = Snowflake.fromU64(175928847299117063);
    const shard = manager.getShard(guild_id);
    const expected_id: u16 = @intCast((guild_id.value >> 22) % 4);
    try std.testing.expectEqual(expected_id, shard.id);
}

test "ShardManager startAll and stopAll" {
    const allocator = std.testing.allocator;
    var manager = try ShardManager.init(allocator, 2, "test_token", 0);
    defer manager.deinit();

    try manager.startAll();
    std.time.sleep(50 * std.time.ns_per_ms);
    manager.stopAll();

    for (manager.shards) |shard| {
        try std.testing.expectEqual(ShardStatus.disconnected, shard.status);
    }
}

test "ShardManager shardStatus" {
    const allocator = std.testing.allocator;
    var manager = try ShardManager.init(allocator, 3, "test_token", 0);
    defer manager.deinit();

    const statuses = try manager.shardStatus();
    defer allocator.free(statuses);

    try std.testing.expectEqual(@as(usize, 3), statuses.len);
    for (statuses) |status| {
        try std.testing.expectEqual(ShardStatus.disconnected, status);
    }
}