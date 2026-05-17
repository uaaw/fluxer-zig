const std = @import("std");
const Snowflake = @import("../models/snowflake.zig").Snowflake;
const User = @import("../models/user.zig").User;
const ChannelType = @import("../models/channel.zig").ChannelType;

/// Payload for MESSAGE_DELETE event.
pub const MessageDeletePayload = struct {
    id: Snowflake,
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
};

/// Payload for GUILD_DELETE event.
pub const GuildDeletePayload = struct {
    id: Snowflake,
    unavailable: bool = false,
};

/// Payload for CHANNEL_DELETE event.
pub const ChannelDeletePayload = struct {
    id: Snowflake,
    guild_id: ?Snowflake = null,
    type: ChannelType,
};

/// Payload for GUILD_MEMBER_REMOVE event.
pub const GuildMemberRemovePayload = struct {
    guild_id: Snowflake,
    user: User,
};

test "message delete payload json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "111111111111111111",
        \\  "channel_id": "222222222222222222",
        \\  "guild_id": "333333333333333333"
        \\}
    ;
    const parsed = try std.json.parseFromSlice(MessageDeletePayload, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 111111111111111111), parsed.value.id.toU64());
    try std.testing.expectEqual(@as(u64, 222222222222222222), parsed.value.channel_id.toU64());
    try std.testing.expectEqual(@as(u64, 333333333333333333), parsed.value.guild_id.?.toU64());
}

test "guild delete payload json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "555555555555555555",
        \\  "unavailable": true
        \\}
    ;
    const parsed = try std.json.parseFromSlice(GuildDeletePayload, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 555555555555555555), parsed.value.id.toU64());
    try std.testing.expect(parsed.value.unavailable);
}

test "channel delete payload json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "333333333333333333",
        \\  "guild_id": "444444444444444444",
        \\  "type": 0
        \\}
    ;
    const parsed = try std.json.parseFromSlice(ChannelDeletePayload, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 333333333333333333), parsed.value.id.toU64());
    try std.testing.expectEqual(@as(u64, 444444444444444444), parsed.value.guild_id.?.toU64());
    try std.testing.expectEqual(ChannelType.GuildText, parsed.value.type);
}

test "guild member remove payload json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "guild_id": "555555555555555555",
        \\  "user": {
        \\    "id": "123456789012345678",
        \\    "username": "testuser",
        \\    "discriminator": null
        \\  }
        \\}
    ;
    const parsed = try std.json.parseFromSlice(GuildMemberRemovePayload, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 555555555555555555), parsed.value.guild_id.toU64());
    try std.testing.expectEqualStrings("testuser", parsed.value.user.username);
}