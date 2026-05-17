const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;

/// Fluxer user object. Includes Discord-compatible fields and fluxer-specific extensions.
pub const User = struct {
    id: Snowflake,
    username: []const u8,
    discriminator: ?[]const u8 = null,
    global_name: ?[]const u8 = null,
    avatar: ?[]const u8 = null,
    bot: bool = false,
    system: bool = false,
    mfa_enabled: ?bool = null,
    locale: ?[]const u8 = null,
    verified: ?bool = null,
    email: ?[]const u8 = null,
    flags: ?u64 = null,
    premium_type: ?u32 = null,
    public_flags: ?u64 = null,
    /// Fluxer-specific: user's preferred pronouns.
    pronouns: ?[]const u8 = null,
    /// Fluxer-specific: user biography / about me.
    bio: ?[]const u8 = null,
    /// Fluxer-specific: accent color for profile (Int32).
    accent_color: ?u32 = null,
    /// Fluxer-specific: dominant color extracted from avatar (Int32).
    avatar_color: ?u32 = null,
    /// Fluxer-specific: internal/admin traits string.
    traits: ?[]const u8 = null,
    /// Fluxer-specific: premium lifetime sequence number.
    premium_lifetime_sequence: ?u64 = null,

    /// Returns true if the user has a non-empty username.
    pub fn isValid(self: User) bool {
        return self.username.len > 0;
    }
};

test "user json with discriminator" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "123456789012345678",
        \\  "username": "testuser",
        \\  "discriminator": "1234",
        \\  "avatar": null,
        \\  "bot": true
        \\}
    ;
    const parsed = try std.json.parseFromSlice(User, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 123456789012345678), parsed.value.id.toU64());
    try std.testing.expectEqualStrings("testuser", parsed.value.username);
    try std.testing.expectEqualStrings("1234", parsed.value.discriminator.?);
    try std.testing.expect(parsed.value.bot);
    try std.testing.expect(!parsed.value.system);
    try std.testing.expect(parsed.value.isValid());
}

test "user json without discriminator" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "123456789012345678",
        \\  "username": "testuser",
        \\  "avatar": null,
        \\  "bot": false
        \\}
    ;
    const parsed = try std.json.parseFromSlice(User, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 123456789012345678), parsed.value.id.toU64());
    try std.testing.expectEqualStrings("testuser", parsed.value.username);
    try std.testing.expect(parsed.value.discriminator == null);
    try std.testing.expect(!parsed.value.bot);
    try std.testing.expect(parsed.value.isValid());
}

test "user json with fluxer-specific fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "123456789012345678",
        \\  "username": "fluxeruser",
        \\  "discriminator": "0001",
        \\  "avatar": null,
        \\  "bot": false,
        \\  "pronouns": "they/them",
        \\  "bio": "Hello, fluxer!",
        \\  "accent_color": 16711680,
        \\  "avatar_color": 65280,
        \\  "traits": "admin,beta",
        \\  "premium_lifetime_sequence": 42
        \\}
    ;
    const parsed = try std.json.parseFromSlice(User, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("fluxeruser", parsed.value.username);
    try std.testing.expectEqualStrings("they/them", parsed.value.pronouns.?);
    try std.testing.expectEqualStrings("Hello, fluxer!", parsed.value.bio.?);
    try std.testing.expectEqual(@as(u32, 16711680), parsed.value.accent_color.?);
    try std.testing.expectEqual(@as(u32, 65280), parsed.value.avatar_color.?);
    try std.testing.expectEqualStrings("admin,beta", parsed.value.traits.?);
    try std.testing.expectEqual(@as(u64, 42), parsed.value.premium_lifetime_sequence.?);
}