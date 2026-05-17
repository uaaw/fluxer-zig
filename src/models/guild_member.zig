const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;
const User = @import("user.zig").User;

/// Fluxer guild member object. Includes Discord-compatible fields and fluxer-specific extensions.
pub const GuildMember = struct {
    user: ?User = null,
    nick: ?[]const u8 = null,
    avatar: ?[]const u8 = null,
    roles: []Snowflake,
    joined_at: []const u8,
    premium_since: ?[]const u8 = null,
    deaf: bool,
    mute: bool,
    flags: ?u64 = null,
    pending: ?bool = null,
    permissions: ?[]const u8 = null,
    communication_disabled_until: ?[]const u8 = null,
    /// Fluxer-specific: profile flags bitmask (AVATAR_UNSET=1, BANNER_UNSET=2).
    profile_flags: ?u64 = null,
    /// Fluxer-specific: hoist position for role ordering.
    hoist_position: ?u32 = null,
    /// The guild ID this member belongs to (gateway events may include this).
    guild_id: ?Snowflake = null,
};

test "guild member json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "user": {
        \\    "id": "123456789012345678",
        \\    "username": "testuser",
        \\    "discriminator": null
        \\  },
        \\  "nick": "TestNick",
        \\  "roles": ["111111111111111111", "222222222222222222"],
        \\  "joined_at": "2024-01-01T00:00:00.000Z",
        \\  "deaf": false,
        \\  "mute": false
        \\}
    ;
    const parsed = try std.json.parseFromSlice(GuildMember, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("testuser", parsed.value.user.?.username);
    try std.testing.expectEqualStrings("TestNick", parsed.value.nick.?);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.roles.len);
    try std.testing.expectEqual(@as(u64, 111111111111111111), parsed.value.roles[0].toU64());
    try std.testing.expectEqual(@as(u64, 222222222222222222), parsed.value.roles[1].toU64());
}

test "guild member json with fluxer-specific fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "user": {
        \\    "id": "123456789012345678",
        \\    "username": "testuser",
        \\    "discriminator": null
        \\  },
        \\  "nick": "TestNick",
        \\  "roles": [],
        \\  "joined_at": "2024-01-01T00:00:00.000Z",
        \\  "deaf": false,
        \\  "mute": false,
        \\  "profile_flags": 1,
        \\  "hoist_position": 3
        \\}
    ;
    const parsed = try std.json.parseFromSlice(GuildMember, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 1), parsed.value.profile_flags.?);
    try std.testing.expectEqual(@as(u32, 3), parsed.value.hoist_position.?);
}

test "guild member json with guild_id" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "user": {
        \\    "id": "123456789012345678",
        \\    "username": "testuser",
        \\    "discriminator": null
        \\  },
        \\  "guild_id": "987654321098765432",
        \\  "nick": "TestNick",
        \\  "roles": [],
        \\  "joined_at": "2024-01-01T00:00:00.000Z",
        \\  "deaf": false,
        \\  "mute": false
        \\}
    ;
    const parsed = try std.json.parseFromSlice(GuildMember, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 987654321098765432), parsed.value.guild_id.?.toU64());
    try std.testing.expectEqualStrings("testuser", parsed.value.user.?.username);
}