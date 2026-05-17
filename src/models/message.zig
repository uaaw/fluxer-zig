const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;
const User = @import("user.zig").User;

/// Fluxer message types. Includes Discord-compatible types.
pub const MessageType = enum(u8) {
    Default = 0,
    RecipientAdd = 1,
    RecipientRemove = 2,
    Call = 3,
    ChannelNameChange = 4,
    ChannelIconChange = 5,
    ChannelPinnedMessage = 6,
    UserJoin = 7,
    GuildBoost = 8,
    GuildBoostTier1 = 9,
    GuildBoostTier2 = 10,
    GuildBoostTier3 = 11,
    ChannelFollowAdd = 12,
    GuildDiscoveryDisqualified = 14,
    GuildDiscoveryRequalified = 15,
    GuildDiscoveryGracePeriodInitialWarning = 16,
    GuildDiscoveryGracePeriodFinalWarning = 17,
    ThreadCreated = 18,
    Reply = 19,
    ChatInputCommand = 20,
    ThreadStarterMessage = 21,
    GuildInvitationReminder = 22,
    ContextMenuCommand = 23,
};

/// Fluxer attachment object.
pub const Attachment = struct {
    id: Snowflake,
    filename: []const u8,
    description: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    size: u64,
    url: []const u8,
    proxy_url: []const u8,
    height: ?u32 = null,
    width: ?u32 = null,
    ephemeral: ?bool = null,
};

/// Fluxer embed field object.
pub const EmbedField = struct {
    name: []const u8,
    value: []const u8,
    @"inline": bool = false,
};

/// Fluxer embed object.
pub const Embed = struct {
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    url: ?[]const u8 = null,
    color: ?u32 = null,
    fields: ?[]EmbedField = null,
};

/// Fluxer reaction emoji object.
pub const ReactionEmoji = struct {
    id: ?Snowflake = null,
    name: ?[]const u8 = null,
};

/// Fluxer reaction object.
pub const Reaction = struct {
    count: u32,
    me: bool,
    emoji: ReactionEmoji,
};

/// Fluxer message snapshot for forwarded messages.
pub const MessageSnapshot = struct {
    message_id: Snowflake,
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
    content: []const u8,
    created_at: []const u8,
};

/// Fluxer call info for voice/video calls in messages.
pub const CallInfo = struct {
    participants: []Snowflake,
    ended_timestamp: ?[]const u8 = null,
};

/// Fluxer message flags. Includes Discord-compatible flags and fluxer-specific extensions.
pub const MessageFlags = struct {
    pub const Crossposted = 1;
    pub const IsCrosspost = 1 << 1;
    pub const SuppressEmbeds = 1 << 2;
    pub const SourceMessageDeleted = 1 << 3;
    pub const Urgent = 1 << 4;
    pub const HasThread = 1 << 5;
    pub const Ephemeral = 1 << 6;
    pub const Loading = 1 << 7;
    pub const FailedToMentionSomeRolesInThread = 1 << 8;
    pub const SuppressNotifications = 1 << 12;
    /// Fluxer-specific: voice message.
    pub const VoiceMessage = 1 << 13;
    /// Fluxer-specific: compact attachments view.
    pub const CompactAttachments = 1 << 14;
};

/// Fluxer message object.
pub const Message = struct {
    id: Snowflake,
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
    author: User,
    content: []const u8,
    timestamp: []const u8,
    edited_timestamp: ?[]const u8 = null,
    tts: bool,
    mention_everyone: bool,
    mentions: []User,
    mention_roles: []Snowflake,
    attachments: []Attachment,
    embeds: []Embed,
    reactions: ?[]Reaction = null,
    pinned: bool,
    type: MessageType,
    flags: ?u64 = null,
    /// Fluxer-specific: forwarded message snapshots.
    message_snapshots: ?[]MessageSnapshot = null,
    /// Fluxer-specific: call info for call messages.
    call: ?CallInfo = null,
};

test "message json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "111111111111111111",
        \\  "channel_id": "222222222222222222",
        \\  "author": {
        \\    "id": "123456789012345678",
        \\    "username": "author",
        \\    "discriminator": null
        \\  },
        \\  "content": "hello",
        \\  "timestamp": "2024-01-01T00:00:00.000Z",
        \\  "tts": false,
        \\  "mention_everyone": false,
        \\  "mentions": [],
        \\  "mention_roles": [],
        \\  "attachments": [],
        \\  "embeds": [
        \\    {
        \\      "title": "Test Embed",
        \\      "fields": [
        \\        {
        \\          "name": "Field 1",
        \\          "value": "Value 1",
        \\          "inline": true
        \\        }
        \\      ]
        \\    }
        \\  ],
        \\  "pinned": false,
        \\  "type": 0
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Message, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("hello", parsed.value.content);
    try std.testing.expectEqual(MessageType.Default, parsed.value.type);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.embeds.len);
    try std.testing.expectEqualStrings("Test Embed", parsed.value.embeds[0].title.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.embeds[0].fields.?.len);
    try std.testing.expectEqualStrings("Field 1", parsed.value.embeds[0].fields.?[0].name);
    try std.testing.expectEqualStrings("Value 1", parsed.value.embeds[0].fields.?[0].value);
    try std.testing.expect(parsed.value.embeds[0].fields.?[0].@"inline");
}

test "message json with fluxer-specific fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "111111111111111111",
        \\  "channel_id": "222222222222222222",
        \\  "guild_id": "333333333333333333",
        \\  "author": {
        \\    "id": "123456789012345678",
        \\    "username": "author",
        \\    "discriminator": null
        \\  },
        \\  "content": "hello with call and snapshot",
        \\  "timestamp": "2024-01-01T00:00:00.000Z",
        \\  "tts": false,
        \\  "mention_everyone": false,
        \\  "mentions": [],
        \\  "mention_roles": [],
        \\  "attachments": [],
        \\  "embeds": [],
        \\  "pinned": false,
        \\  "type": 0,
        \\  "flags": 143360,
        \\  "message_snapshots": [
        \\    {
        \\      "message_id": "444444444444444444",
        \\      "channel_id": "222222222222222222",
        \\      "guild_id": "333333333333333333",
        \\      "content": "original",
        \\      "created_at": "2024-01-01T00:00:00.000Z"
        \\    }
        \\  ],
        \\  "call": {
        \\    "participants": ["123456789012345678"],
        \\    "ended_timestamp": "2024-01-01T01:00:00.000Z"
        \\  }
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Message, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("hello with call and snapshot", parsed.value.content);
    try std.testing.expectEqual(@as(u64, 143360), parsed.value.flags.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.message_snapshots.?.len);
    try std.testing.expectEqualStrings("original", parsed.value.message_snapshots.?[0].content);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.call.?.participants.len);
    try std.testing.expectEqualStrings("2024-01-01T01:00:00.000Z", parsed.value.call.?.ended_timestamp.?);
}