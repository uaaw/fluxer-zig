const std = @import("std");
const User = @import("../models/user.zig").User;
const Guild = @import("../models/guild.zig").Guild;

/// Payload for the READY gateway event.
pub const ReadyPayload = struct {
    v: u8,
    user: User,
    session_id: []const u8,
    resume_gateway_url: ?[]const u8 = null,
    guilds: []Guild,
};

test "ready payload json" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "v": 1,
        \\  "user": {
        \\    "id": "123456789012345678",
        \\    "username": "testbot",
        \\    "discriminator": null,
        \\    "bot": true
        \\  },
        \\  "session_id": "abc123",
        \\  "guilds": []
        \\}
    ;
    const parsed = try std.json.parseFromSlice(ReadyPayload, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u8, 1), parsed.value.v);
    try std.testing.expectEqualStrings("testbot", parsed.value.user.username);
    try std.testing.expectEqualStrings("abc123", parsed.value.session_id);
    try std.testing.expectEqual(@as(usize, 0), parsed.value.guilds.len);
}