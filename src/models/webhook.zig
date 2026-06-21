const Snowflake = @import("snowflake.zig").Snowflake;
const User = @import("user.zig").User;

pub const WebhookType = enum(u8) {
    Incoming = 1,
    ChannelFollower = 2,
    Application = 3,
};

/// Partial guild object returned in webhook source_guild.
pub const WebhookSourceGuild = struct {
    id: Snowflake,
    name: []const u8,
    icon: ?[]const u8 = null,
};

/// Partial channel object returned in webhook source_channel.
pub const WebhookSourceChannel = struct {
    id: Snowflake,
    name: []const u8,
};

pub const Webhook = struct {
    id: Snowflake,
    type: WebhookType,
    guild_id: ?Snowflake = null,
    channel_id: ?Snowflake = null,
    user: ?User = null,
    name: ?[]const u8 = null,
    avatar: ?[]const u8 = null,
    token: ?[]const u8 = null,
    application_id: ?Snowflake = null,
    source_guild: ?WebhookSourceGuild = null,
    source_channel: ?WebhookSourceChannel = null,
    url: ?[]const u8 = null,
};
