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

/// Embed author object.
pub const EmbedAuthor = struct {
    name: []const u8,
    url: ?[]const u8 = null,
    icon_url: ?[]const u8 = null,
    proxy_icon_url: ?[]const u8 = null,
};

/// Embed footer object.
pub const EmbedFooter = struct {
    text: []const u8,
    icon_url: ?[]const u8 = null,
    proxy_icon_url: ?[]const u8 = null,
};

/// Embed image/thumbnail/video object.
pub const EmbedMedia = struct {
    url: []const u8,
    proxy_url: ?[]const u8 = null,
    height: ?u32 = null,
    width: ?u32 = null,
};

/// Embed provider object.
pub const EmbedProvider = struct {
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
};

/// Fluxer embed object.
pub const Embed = struct {
    title: ?[]const u8 = null,
    type: ?[]const u8 = null,
    description: ?[]const u8 = null,
    url: ?[]const u8 = null,
    timestamp: ?[]const u8 = null,
    color: ?u32 = null,
    footer: ?EmbedFooter = null,
    image: ?EmbedMedia = null,
    thumbnail: ?EmbedMedia = null,
    video: ?EmbedMedia = null,
    provider: ?EmbedProvider = null,
    author: ?EmbedAuthor = null,
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

test "embed json with all fields" {
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
        \\  "content": "embed test",
        \\  "timestamp": "2024-01-01T00:00:00.000Z",
        \\  "tts": false,
        \\  "mention_everyone": false,
        \\  "mentions": [],
        \\  "mention_roles": [],
        \\  "attachments": [],
        \\  "embeds": [
        \\    {
        \\      "title": "Full Embed",
        \\      "type": "rich",
        \\      "description": "A full embed with all fields",
        \\      "url": "https://example.com",
        \\      "timestamp": "2024-01-01T00:00:00.000Z",
        \\      "color": 16711680,
        \\      "footer": {
        \\        "text": "Footer text",
        \\        "icon_url": "https://example.com/icon.png",
        \\        "proxy_icon_url": "https://proxy.example.com/icon.png"
        \\      },
        \\      "image": {
        \\        "url": "https://example.com/image.png",
        \\        "proxy_url": "https://proxy.example.com/image.png",
        \\        "height": 200,
        \\        "width": 400
        \\      },
        \\      "thumbnail": {
        \\        "url": "https://example.com/thumb.png",
        \\        "proxy_url": "https://proxy.example.com/thumb.png",
        \\        "height": 50,
        \\        "width": 50
        \\      },
        \\      "video": {
        \\        "url": "https://example.com/video.mp4",
        \\        "proxy_url": "https://proxy.example.com/video.mp4",
        \\        "height": 720,
        \\        "width": 1280
        \\      },
        \\      "provider": {
        \\        "name": "Example",
        \\        "url": "https://example.com"
        \\      },
        \\      "author": {
        \\        "name": "Author Name",
        \\        "url": "https://example.com/author",
        \\        "icon_url": "https://example.com/author.png",
        \\        "proxy_icon_url": "https://proxy.example.com/author.png"
        \\      },
        \\      "fields": [
        \\        {
        \\          "name": "Field 1",
        \\          "value": "Value 1",
        \\          "inline": true
        \\        },
        \\        {
        \\          "name": "Field 2",
        \\          "value": "Value 2",
        \\          "inline": false
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

    const embed = parsed.value.embeds[0];

    try std.testing.expectEqualStrings("Full Embed", embed.title.?);
    try std.testing.expectEqualStrings("rich", embed.type.?);
    try std.testing.expectEqualStrings("A full embed with all fields", embed.description.?);
    try std.testing.expectEqualStrings("https://example.com", embed.url.?);
    try std.testing.expectEqualStrings("2024-01-01T00:00:00.000Z", embed.timestamp.?);
    try std.testing.expectEqual(@as(u32, 16711680), embed.color.?);

    // Footer
    try std.testing.expectEqualStrings("Footer text", embed.footer.?.text);
    try std.testing.expectEqualStrings("https://example.com/icon.png", embed.footer.?.icon_url.?);
    try std.testing.expectEqualStrings("https://proxy.example.com/icon.png", embed.footer.?.proxy_icon_url.?);

    // Image
    try std.testing.expectEqualStrings("https://example.com/image.png", embed.image.?.url);
    try std.testing.expectEqualStrings("https://proxy.example.com/image.png", embed.image.?.proxy_url.?);
    try std.testing.expectEqual(@as(u32, 200), embed.image.?.height.?);
    try std.testing.expectEqual(@as(u32, 400), embed.image.?.width.?);

    // Thumbnail
    try std.testing.expectEqualStrings("https://example.com/thumb.png", embed.thumbnail.?.url);
    try std.testing.expectEqualStrings("https://proxy.example.com/thumb.png", embed.thumbnail.?.proxy_url.?);
    try std.testing.expectEqual(@as(u32, 50), embed.thumbnail.?.height.?);
    try std.testing.expectEqual(@as(u32, 50), embed.thumbnail.?.width.?);

    // Video
    try std.testing.expectEqualStrings("https://example.com/video.mp4", embed.video.?.url);
    try std.testing.expectEqualStrings("https://proxy.example.com/video.mp4", embed.video.?.proxy_url.?);
    try std.testing.expectEqual(@as(u32, 720), embed.video.?.height.?);
    try std.testing.expectEqual(@as(u32, 1280), embed.video.?.width.?);

    // Provider
    try std.testing.expectEqualStrings("Example", embed.provider.?.name.?);
    try std.testing.expectEqualStrings("https://example.com", embed.provider.?.url.?);

    // Author
    try std.testing.expectEqualStrings("Author Name", embed.author.?.name);
    try std.testing.expectEqualStrings("https://example.com/author", embed.author.?.url.?);
    try std.testing.expectEqualStrings("https://example.com/author.png", embed.author.?.icon_url.?);
    try std.testing.expectEqualStrings("https://proxy.example.com/author.png", embed.author.?.proxy_icon_url.?);

    // Fields
    try std.testing.expectEqual(@as(usize, 2), embed.fields.?.len);
    try std.testing.expectEqualStrings("Field 1", embed.fields.?[0].name);
    try std.testing.expectEqualStrings("Value 1", embed.fields.?[0].value);
    try std.testing.expect(embed.fields.?[0].@"inline");
    try std.testing.expectEqualStrings("Field 2", embed.fields.?[1].name);
    try std.testing.expectEqualStrings("Value 2", embed.fields.?[1].value);
    try std.testing.expect(!embed.fields.?[1].@"inline");
}