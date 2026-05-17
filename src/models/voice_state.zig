const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;
const GuildMember = @import("guild_member.zig").GuildMember;

pub const VoiceState = struct {
    guild_id: ?Snowflake = null,
    channel_id: ?Snowflake = null,
    user_id: Snowflake,
    member: ?GuildMember = null,
    session_id: []const u8,
    deaf: bool,
    mute: bool,
    self_deaf: bool,
    self_mute: bool,
    self_stream: ?bool = null,
    self_video: bool,
    suppress: bool,
    request_to_speak_timestamp: ?[]const u8 = null,
};
