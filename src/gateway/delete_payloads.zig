const std = @import("std");
const Snowflake = @import("../models/snowflake.zig").Snowflake;
const User = @import("../models/user.zig").User;
const ChannelType = @import("../models/channel.zig").ChannelType;
const VoiceState = @import("../models/voice_state.zig").VoiceState;
const ReactionEmoji = @import("../models/message.zig").ReactionEmoji;
const Role = @import("../models/guild.zig").Role;
const Emoji = @import("../models/guild.zig").Emoji;
const Sticker = @import("../models/guild.zig").Sticker;
const Activity = @import("payload.zig").Activity;
const GuildMember = @import("../models/guild_member.zig").GuildMember;
const Channel = @import("../models/channel.zig").Channel;

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

// --- Extended event payloads ---

pub const MessageReactionAddPayload = struct {
    user_id: Snowflake,
    channel_id: Snowflake,
    message_id: Snowflake,
    guild_id: ?Snowflake = null,
    emoji: ReactionEmoji,
    member: ?GuildMember = null,
};

pub const MessageReactionRemovePayload = struct {
    user_id: Snowflake,
    channel_id: Snowflake,
    message_id: Snowflake,
    guild_id: ?Snowflake = null,
    emoji: ReactionEmoji,
};

pub const MessageReactionRemoveAllPayload = struct {
    channel_id: Snowflake,
    message_id: Snowflake,
    guild_id: ?Snowflake = null,
};

pub const MessageReactionRemoveEmojiPayload = struct {
    channel_id: Snowflake,
    message_id: Snowflake,
    guild_id: ?Snowflake = null,
    emoji: ReactionEmoji,
};

pub const MessageDeleteBulkPayload = struct {
    ids: []Snowflake,
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
};

pub const GuildRoleCreatePayload = struct {
    guild_id: Snowflake,
    role: Role,
};

pub const GuildRoleUpdatePayload = struct {
    guild_id: Snowflake,
    role: Role,
};

pub const GuildRoleDeletePayload = struct {
    guild_id: Snowflake,
    role_id: Snowflake,
};

pub const GuildBanAddPayload = struct {
    guild_id: Snowflake,
    user: User,
};

pub const GuildBanRemovePayload = struct {
    guild_id: Snowflake,
    user: User,
};

pub const TypingStartPayload = struct {
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
    user_id: Snowflake,
    timestamp: u64,
    member: ?GuildMember = null,
};

pub const WebhooksUpdatePayload = struct {
    guild_id: Snowflake,
    channel_id: Snowflake,
};

pub const InviteCreatePayload = struct {
    channel_id: Snowflake,
    code: []const u8,
    created_at: []const u8,
    guild_id: ?Snowflake = null,
    inviter: ?User = null,
    max_age: u32,
    max_uses: u32,
    target_type: ?u32 = null,
    target_user: ?User = null,
    target_application_id: ?Snowflake = null,
    temporary: bool,
    uses: u32,
};

pub const InviteDeletePayload = struct {
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
    code: []const u8,
};

pub const VoiceStateUpdatePayload = VoiceState;

pub const VoiceServerUpdatePayload = struct {
    token: []const u8,
    guild_id: Snowflake,
    endpoint: ?[]const u8 = null,
};

pub const PresenceUpdatePayload = struct {
    user: User,
    guild_id: ?Snowflake = null,
    status: []const u8,
    activities: []Activity,
    client_status: ?std.json.Value = null,
};

pub const ThreadMember = struct {
    id: ?Snowflake = null,
    user_id: ?Snowflake = null,
    join_timestamp: []const u8,
    flags: u32,
};

pub const ThreadListSyncPayload = struct {
    guild_id: Snowflake,
    channel_ids: ?[]Snowflake = null,
    threads: []Channel,
    members: ?[]ThreadMember = null,
};

pub const ThreadMembersUpdatePayload = struct {
    id: Snowflake,
    guild_id: Snowflake,
    member_count: u32,
    added_members: ?[]ThreadMember = null,
    removed_member_ids: ?[]Snowflake = null,
};

pub const UserUpdatePayload = User;

pub const ChannelPinsUpdatePayload = struct {
    guild_id: ?Snowflake = null,
    channel_id: Snowflake,
    last_pin_timestamp: ?[]const u8 = null,
};

pub const ChannelRecipientAddPayload = struct {
    channel_id: Snowflake,
    user: User,
};

pub const ChannelRecipientRemovePayload = struct {
    channel_id: Snowflake,
    user: User,
};

pub const CallCreatePayload = struct {
    channel_id: Snowflake,
    message_id: ?Snowflake = null,
    region: ?[]const u8 = null,
    ringing: ?[]Snowflake = null,
};

pub const CallDeletePayload = struct {
    channel_id: Snowflake,
};

pub const GuildEmojisUpdatePayload = struct {
    guild_id: Snowflake,
    emojis: []Emoji,
};

pub const GuildStickersUpdatePayload = struct {
    guild_id: Snowflake,
    stickers: []Sticker,
};

pub const RelationshipAddPayload = struct {
    id: Snowflake,
    type: u32,
    user: User,
    since: []const u8,
    nickname: ?[]const u8 = null,
};

pub const RelationshipRemovePayload = struct {
    id: Snowflake,
    type: u32,
};

pub const GuildRoleUpdateBulkPayload = struct {
    guild_id: Snowflake,
    roles: []Role,
};

pub const ChannelUpdateBulkPayload = struct {
    guild_id: Snowflake,
    channels: []Channel,
};