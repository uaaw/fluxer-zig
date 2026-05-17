const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;
const User = @import("user.zig").User;
const Permissions = @import("permissions.zig").Permissions;

/// Fluxer channel types. Includes Discord-compatible types and fluxer-specific extensions.
pub const ChannelType = enum(u16) {
    GuildText = 0,
    DM = 1,
    GuildVoice = 2,
    GroupDM = 3,
    GuildCategory = 4,
    GuildAnnouncement = 5,
    GuildStore = 6,
    GuildAnnouncementThread = 10,
    GuildPublicThread = 11,
    GuildPrivateThread = 12,
    GuildStageVoice = 13,
    GuildDirectory = 14,
    GuildForum = 15,
    /// Fluxer-specific: Link channel.
    Link = 998,
};

/// Fluxer permission overwrite types.
pub const PermissionOverwriteType = enum(u8) {
    Role = 0,
    Member = 1,
};

/// Fluxer permission overwrite object.
pub const PermissionOverwrite = struct {
    id: Snowflake,
    type: PermissionOverwriteType,
    allow: Permissions,
    deny: Permissions,
};

/// Fluxer channel object.
pub const Channel = struct {
    id: Snowflake,
    type: ChannelType,
    guild_id: ?Snowflake = null,
    position: ?i32 = null,
    name: ?[]const u8 = null,
    topic: ?[]const u8 = null,
    nsfw: ?bool = null,
    last_message_id: ?Snowflake = null,
    bitrate: ?u32 = null,
    user_limit: ?u32 = null,
    rate_limit_per_user: ?u32 = null,
    recipients: ?[]User = null,
    icon: ?[]const u8 = null,
    owner_id: ?Snowflake = null,
    application_id: ?Snowflake = null,
    parent_id: ?Snowflake = null,
    last_pin_timestamp: ?[]const u8 = null,
    permission_overwrites: ?[]PermissionOverwrite = null,
    /// Fluxer-specific: URL for Link channels.
    url: ?[]const u8 = null,
};

test "channel json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "333333333333333333",
        \\  "type": 0,
        \\  "guild_id": "444444444444444444",
        \\  "name": "general"
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Channel, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(ChannelType.GuildText, parsed.value.type);
    try std.testing.expectEqualStrings("general", parsed.value.name.?);
}

test "channel json with permission overwrites" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "333333333333333333",
        \\  "type": 0,
        \\  "guild_id": "444444444444444444",
        \\  "name": "general",
        \\  "permission_overwrites": [
        \\    {
        \\      "id": "555555555555555555",
        \\      "type": 0,
        \\      "allow": "1024",
        \\      "deny": "0"
        \\    }
        \\  ]
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Channel, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.permission_overwrites.?.len);
    try std.testing.expectEqual(PermissionOverwriteType.Role, parsed.value.permission_overwrites.?[0].type);
    try std.testing.expect(parsed.value.permission_overwrites.?[0].allow.has("ViewChannel"));
}

test "channel json link type" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "999999999999999999",
        \\  "type": 998,
        \\  "guild_id": "444444444444444444",
        \\  "name": "external-link",
        \\  "url": "https://example.com"
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Channel, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(ChannelType.Link, parsed.value.type);
    try std.testing.expectEqualStrings("external-link", parsed.value.name.?);
    try std.testing.expectEqualStrings("https://example.com", parsed.value.url.?);
}