const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;
const User = @import("user.zig").User;
const Permissions = @import("permissions.zig").Permissions;
const Channel = @import("channel.zig").Channel;
const GuildMember = @import("guild_member.zig").GuildMember;

/// Fluxer role tags object.
pub const RoleTags = struct {
    bot_id: ?Snowflake = null,
    integration_id: ?Snowflake = null,
    premium_subscriber: ?bool = null,
};

/// Fluxer role object.
pub const Role = struct {
    id: Snowflake,
    name: []const u8,
    color: u32,
    hoist: bool,
    icon: ?[]const u8 = null,
    unicode_emoji: ?[]const u8 = null,
    position: i32,
    permissions: Permissions,
    managed: bool,
    mentionable: bool,
    tags: ?RoleTags = null,
};

/// Fluxer emoji object.
pub const Emoji = struct {
    id: ?Snowflake = null,
    name: ?[]const u8 = null,
    roles: ?[]Snowflake = null,
    user: ?User = null,
    require_colons: ?bool = null,
    managed: ?bool = null,
    animated: ?bool = null,
    available: ?bool = null,
};

/// Fluxer welcome screen channel object.
pub const WelcomeScreenChannel = struct {
    channel_id: Snowflake,
    description: []const u8,
    emoji_id: ?Snowflake = null,
    emoji_name: ?[]const u8 = null,
};

/// Fluxer welcome screen object.
pub const WelcomeScreen = struct {
    description: ?[]const u8 = null,
    welcome_channels: []WelcomeScreenChannel,
};

/// Fluxer sticker object.
pub const Sticker = struct {
    id: Snowflake,
    pack_id: ?Snowflake = null,
    name: []const u8,
    description: ?[]const u8 = null,
    tags: []const u8,
    type: u32,
    format_type: u32,
    available: ?bool = null,
    guild_id: ?Snowflake = null,
    user: ?User = null,
    sort_value: ?u32 = null,
};

/// Fluxer guild feature flags. Includes Discord-compatible features and fluxer-specific extensions.
pub const GuildFeature = enum {
    ANIMATED_ICON,
    BANNER,
    COMMERCE,
    COMMUNITY,
    DISCOVERABLE,
    FEATURABLE,
    INVITE_SPLASH,
    MEMBER_VERIFICATION_GATE_ENABLED,
    NEWS,
    PARTNERED,
    PREVIEW_ENABLED,
    VANITY_URL,
    VERIFIED,
    VIP_REGIONS,
    WELCOME_SCREEN_ENABLED,
    TICKETED_EVENTS_ENABLED,
    MONETIZATION_ENABLED,
    MORE_STICKERS,
    THREE_DAY_THREAD_ARCHIVE,
    SEVEN_DAY_THREAD_ARCHIVE,
    PRIVATE_THREADS,
    ROLE_ICONS,
    ROLE_SUBSCRIPTIONS_AVAILABLE_FOR_PURCHASE,
    ROLE_SUBSCRIPTIONS_ENABLED,
    /// Fluxer-specific: visionary guild.
    VISIONARY,
    /// Fluxer-specific: operator guild.
    OPERATOR,
};

/// Fluxer guild object.
pub const Guild = struct {
    id: Snowflake,
    name: []const u8,
    icon: ?[]const u8 = null,
    icon_hash: ?[]const u8 = null,
    splash: ?[]const u8 = null,
    discovery_splash: ?[]const u8 = null,
    owner: ?bool = null,
    owner_id: Snowflake,
    permissions: ?[]const u8 = null,
    region: ?[]const u8 = null,
    afk_channel_id: ?Snowflake = null,
    afk_timeout: u32,
    widget_enabled: ?bool = null,
    widget_channel_id: ?Snowflake = null,
    verification_level: u32,
    default_message_notifications: u32,
    explicit_content_filter: u32,
    roles: []Role,
    emojis: []Emoji,
    features: [][]const u8,
    mfa_level: u32,
    application_id: ?Snowflake = null,
    system_channel_id: ?Snowflake = null,
    system_channel_flags: u32,
    rules_channel_id: ?Snowflake = null,
    max_presences: ?u32 = null,
    max_members: ?u32 = null,
    vanity_url_code: ?[]const u8 = null,
    description: ?[]const u8 = null,
    banner: ?[]const u8 = null,
    premium_tier: u32,
    premium_subscription_count: ?u32 = null,
    preferred_locale: []const u8,
    public_updates_channel_id: ?Snowflake = null,
    max_video_channel_users: ?u32 = null,
    approximate_member_count: ?u32 = null,
    approximate_presence_count: ?u32 = null,
    welcome_screen: ?WelcomeScreen = null,
    nsfw_level: u32,
    stickers: ?[]Sticker = null,
    premium_progress_bar_enabled: bool,
    channels: ?[]Channel = null,
    members: ?[]GuildMember = null,
    /// Fluxer-specific: disabled operations bitmask.
    disabled_operations: ?u64 = null,
    /// Fluxer-specific: message history cutoff timestamp.
    message_history_cutoff: ?[]const u8 = null,
    /// Fluxer-specific: splash card alignment (0|1|2).
    splash_card_alignment: ?u32 = null,
};

test "guild json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "555555555555555555",
        \\  "name": "Test Guild",
        \\  "owner_id": "123456789012345678",
        \\  "afk_timeout": 300,
        \\  "verification_level": 0,
        \\  "default_message_notifications": 0,
        \\  "explicit_content_filter": 0,
        \\  "roles": [],
        \\  "emojis": [],
        \\  "features": [],
        \\  "mfa_level": 0,
        \\  "system_channel_flags": 0,
        \\  "premium_tier": 0,
        \\  "preferred_locale": "en-US",
        \\  "nsfw_level": 0,
        \\  "premium_progress_bar_enabled": false
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Guild, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("Test Guild", parsed.value.name);
    try std.testing.expectEqualStrings("en-US", parsed.value.preferred_locale);
}

test "guild json with channels and members" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "555555555555555555",
        \\  "name": "Test Guild",
        \\  "owner_id": "123456789012345678",
        \\  "afk_timeout": 300,
        \\  "verification_level": 0,
        \\  "default_message_notifications": 0,
        \\  "explicit_content_filter": 0,
        \\  "roles": [],
        \\  "emojis": [],
        \\  "features": [],
        \\  "mfa_level": 0,
        \\  "system_channel_flags": 0,
        \\  "premium_tier": 0,
        \\  "preferred_locale": "en-US",
        \\  "nsfw_level": 0,
        \\  "premium_progress_bar_enabled": false,
        \\  "channels": [
        \\    {
        \\      "id": "333333333333333333",
        \\      "type": 0,
        \\      "name": "general"
        \\    }
        \\  ],
        \\  "members": [
        \\    {
        \\      "roles": [],
        \\      "joined_at": "2024-01-01T00:00:00.000Z",
        \\      "deaf": false,
        \\      "mute": false
        \\    }
        \\  ]
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Guild, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.channels.?.len);
    try std.testing.expectEqualStrings("general", parsed.value.channels.?[0].name.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.members.?.len);
    try std.testing.expectEqualStrings("2024-01-01T00:00:00.000Z", parsed.value.members.?[0].joined_at);
}

test "guild json with fluxer-specific fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "555555555555555555",
        \\  "name": "Test Guild",
        \\  "owner_id": "123456789012345678",
        \\  "afk_timeout": 300,
        \\  "verification_level": 0,
        \\  "default_message_notifications": 0,
        \\  "explicit_content_filter": 0,
        \\  "roles": [],
        \\  "emojis": [],
        \\  "features": ["VISIONARY", "OPERATOR"],
        \\  "mfa_level": 0,
        \\  "system_channel_flags": 0,
        \\  "premium_tier": 0,
        \\  "preferred_locale": "en-US",
        \\  "nsfw_level": 0,
        \\  "premium_progress_bar_enabled": false,
        \\  "disabled_operations": 7,
        \\  "message_history_cutoff": "2024-06-01T00:00:00.000Z",
        \\  "splash_card_alignment": 2
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Guild, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("Test Guild", parsed.value.name);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.features.len);
    try std.testing.expectEqualStrings("VISIONARY", parsed.value.features[0]);
    try std.testing.expectEqualStrings("OPERATOR", parsed.value.features[1]);
    try std.testing.expectEqual(@as(u64, 7), parsed.value.disabled_operations.?);
    try std.testing.expectEqualStrings("2024-06-01T00:00:00.000Z", parsed.value.message_history_cutoff.?);
    try std.testing.expectEqual(@as(u32, 2), parsed.value.splash_card_alignment.?);
}