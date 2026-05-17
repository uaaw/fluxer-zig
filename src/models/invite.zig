const Snowflake = @import("snowflake.zig").Snowflake;
const User = @import("user.zig").User;

pub const Invite = struct {
    code: []const u8,
    guild_id: ?Snowflake = null,
    channel_id: Snowflake,
    inviter: ?User = null,
    target_type: ?u32 = null,
    target_user: ?User = null,
    target_application_id: ?Snowflake = null,
    approximate_presence_count: ?u32 = null,
    approximate_member_count: ?u32 = null,
    expires_at: ?[]const u8 = null,
    guild_scheduled_event_id: ?Snowflake = null,
};
