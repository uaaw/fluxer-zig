const std = @import("std");

pub const version = "0.0.1";

pub const models = @import("models/mod.zig");
pub const rest = @import("rest/mod.zig");
pub const gateway = @import("gateway/mod.zig");
pub const cache = @import("cache/mod.zig");
pub const websocket = @import("websocket/mod.zig");
pub const Client = @import("client.zig").Client;
pub const ClientOptions = @import("client.zig").ClientOptions;

test {
    std.testing.refAllDecls(@This());
    _ = @import("models/snowflake.zig");
    _ = @import("models/user.zig");
    _ = @import("models/message.zig");
    _ = @import("models/channel.zig");
    _ = @import("models/guild.zig");
    _ = @import("models/guild_member.zig");
    _ = @import("models/permissions.zig");
    _ = @import("models/mod.zig");
    _ = @import("rest/mod.zig");
    _ = @import("gateway/mod.zig");
    _ = @import("cache/mod.zig");
    _ = @import("websocket/mod.zig");
    _ = @import("client.zig");
}