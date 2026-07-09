const std = @import("std");

/// Gateway opcode enum, aligned with the fluxer API specification.
pub const GatewayOpcode = enum(u8) {
    dispatch = 0,
    heartbeat = 1,
    identify = 2,
    presence_update = 3,
    voice_state_update = 4,
    voice_server_ping = 5,
    resume_session = 6,
    reconnect = 7,
    request_guild_members = 8,
    invalid_session = 9,
    hello = 10,
    heartbeat_ack = 11,
    /// Fluxer-specific: error processing gateway message (receive-only).
    gateway_error = 12,
    // opcode 13 is reserved / unused in fluxer.
    /// Fluxer-specific: lazy-load guild data (send-only).
    lazy_request = 14,

    /// Wire format requires numeric opcodes (e.g. {"op":1}), not tag names.
    pub fn jsonStringify(self: GatewayOpcode, jw: anytype) !void {
        try jw.write(@intFromEnum(self));
    }
};

/// Top-level gateway payload envelope.
pub const GatewayPayload = struct {
    op: GatewayOpcode,
    d: ?std.json.Value = null,
    s: ?u64 = null,
    t: ?[]const u8 = null,
};

/// Payload for `GATEWAY_ERROR` (op 12).
pub const GatewayErrorPayload = struct {
    code: i32,
    message: []const u8,
};

/// Payload for `LAZY_REQUEST` (op 14).
pub const LazyRequestPayload = struct {
    guild_id: u64,
    channel_id: u64,
    typing: bool = false,
    threads: bool = false,
    activities: bool = false,
};

/// Properties sent during IDENTIFY.
pub const IdentifyProperties = struct {
    os: []const u8,
    browser: []const u8,
    device: []const u8,
};

/// Body of the IDENTIFY payload.
pub const IdentifyBody = struct {
    token: []const u8,
    properties: IdentifyProperties,
    intents: u32,
    shard: ?[2]u16 = null,
    presence: ?PresenceUpdate = null,
};

/// Body of the RESUME payload.
pub const ResumeBody = struct {
    token: []const u8,
    session_id: []const u8,
    seq: u64,
};

/// Presence update payload.
pub const PresenceUpdate = struct {
    since: ?u64,
    activities: []const Activity,
    status: Status,
    afk: bool,
};

/// User status.
pub const Status = enum {
    online,
    dnd,
    idle,
    invisible,
    offline,
};

/// Activity object.
pub const Activity = struct {
    name: []const u8,
    type: ActivityType,
    url: ?[]const u8 = null,
};

/// Activity type.
pub const ActivityType = enum(u8) {
    game = 0,
    streaming = 1,
    listening = 2,
    watching = 3,
    custom = 4,
    competing = 5,

    pub fn jsonStringify(self: ActivityType, jw: anytype) !void {
        try jw.write(@intFromEnum(self));
    }
};

test "gateway opcodes" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(GatewayOpcode.dispatch));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(GatewayOpcode.heartbeat));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(GatewayOpcode.identify));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(GatewayOpcode.presence_update));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(GatewayOpcode.voice_state_update));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(GatewayOpcode.voice_server_ping));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(GatewayOpcode.resume_session));
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(GatewayOpcode.reconnect));
    try std.testing.expectEqual(@as(u8, 8), @intFromEnum(GatewayOpcode.request_guild_members));
    try std.testing.expectEqual(@as(u8, 9), @intFromEnum(GatewayOpcode.invalid_session));
    try std.testing.expectEqual(@as(u8, 10), @intFromEnum(GatewayOpcode.hello));
    try std.testing.expectEqual(@as(u8, 11), @intFromEnum(GatewayOpcode.heartbeat_ack));
    try std.testing.expectEqual(@as(u8, 12), @intFromEnum(GatewayOpcode.gateway_error));
    try std.testing.expectEqual(@as(u8, 14), @intFromEnum(GatewayOpcode.lazy_request));
}

test "gateway error payload" {
    const payload = GatewayErrorPayload{
        .code = 4001,
        .message = "Unknown opcode",
    };
    try std.testing.expectEqual(@as(i32, 4001), payload.code);
    try std.testing.expectEqualStrings("Unknown opcode", payload.message);
}

test "lazy request payload" {
    const payload = LazyRequestPayload{
        .guild_id = 123456789,
        .channel_id = 987654321,
        .typing = true,
        .threads = false,
        .activities = true,
    };
    try std.testing.expectEqual(@as(u64, 123456789), payload.guild_id);
    try std.testing.expectEqual(@as(u64, 987654321), payload.channel_id);
    try std.testing.expect(payload.typing);
    try std.testing.expect(!payload.threads);
    try std.testing.expect(payload.activities);
}

test "identify body serialization" {
    const body = IdentifyBody{
        .token = "test_token",
        .properties = .{
            .os = "linux",
            .browser = "fluxer-zig",
            .device = "fluxer-zig",
        },
        .intents = 1,
    };
    try std.testing.expectEqualStrings("test_token", body.token);
    try std.testing.expectEqualStrings("linux", body.properties.os);
}

test "gateway heartbeat payload op serializes as integer" {
    const allocator = std.testing.allocator;
    const gp = GatewayPayload{
        .op = .heartbeat,
        .d = std.json.Value{ .null = {} },
    };
    const json = try std.json.stringifyAlloc(allocator, gp, .{});
    defer allocator.free(json);

    // Must be numeric op, never the tag string "heartbeat".
    try std.testing.expect(std.mem.indexOf(u8, json, "\"op\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"op\":\"heartbeat\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "heartbeat") == null);
}

test "gateway identify opcode serializes as integer via GatewayPayload" {
    const allocator = std.testing.allocator;
    const gp = GatewayPayload{ .op = .identify };
    const json = try std.json.stringifyAlloc(allocator, gp, .{});
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"op\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "identify") == null);
}