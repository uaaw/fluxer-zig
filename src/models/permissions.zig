const std = @import("std");

/// Fluxer permission bit flags.
pub const Permissions = packed struct(u64) {
    CreateInstantInvite: bool = false,
    KickMembers: bool = false,
    BanMembers: bool = false,
    Administrator: bool = false,
    ManageChannels: bool = false,
    ManageGuild: bool = false,
    AddReactions: bool = false,
    ViewAuditLog: bool = false,
    PrioritySpeaker: bool = false,
    Stream: bool = false,
    ViewChannel: bool = false,
    SendMessages: bool = false,
    SendTTSMessages: bool = false,
    ManageMessages: bool = false,
    EmbedLinks: bool = false,
    AttachFiles: bool = false,
    ReadMessageHistory: bool = false,
    MentionEveryone: bool = false,
    UseExternalEmojis: bool = false,
    ViewGuildInsights: bool = false,
    Connect: bool = false,
    Speak: bool = false,
    MuteMembers: bool = false,
    DeafenMembers: bool = false,
    MoveMembers: bool = false,
    UseVAD: bool = false,
    ChangeNickname: bool = false,
    ManageNicknames: bool = false,
    ManageRoles: bool = false,
    ManageWebhooks: bool = false,
    ManageGuildExpressions: bool = false,
    UseApplicationCommands: bool = false,
    RequestToSpeak: bool = false,
    ManageEvents: bool = false,
    ManageThreads: bool = false,
    CreatePublicThreads: bool = false,
    CreatePrivateThreads: bool = false,
    UseExternalStickers: bool = false,
    SendMessagesInThreads: bool = false,
    UseEmbeddedActivities: bool = false,
    ModerateMembers: bool = false,
    ViewCreatorMonetizationAnalytics: bool = false,
    UseSoundboard: bool = false,
    CreateGuildExpressions: bool = false,
    CreateEvents: bool = false,
    UseExternalSounds: bool = false,
    SendVoiceMessages: bool = false,
    UseClydeAI: bool = false,
    _: u16 = 0,

    /// Parses Permissions from a decimal string.
    pub fn fromString(str: []const u8) !Permissions {
        const val = try std.fmt.parseInt(u64, str, 10);
        return @bitCast(val);
    }

    /// Formats Permissions into a decimal string using the provided buffer.
    pub fn toString(self: Permissions, buf: []u8) ![]const u8 {
        return try std.fmt.bufPrint(buf, "{d}", .{@as(u64, @bitCast(self))});
    }

    /// Returns true if the specified permission field is set.
    pub fn has(self: Permissions, comptime field: []const u8) bool {
        return @field(self, field);
    }

    /// Sets the specified permission field to true.
    pub fn add(self: *Permissions, comptime field: []const u8) void {
        @field(self, field) = true;
    }

    /// Sets the specified permission field to false.
    pub fn remove(self: *Permissions, comptime field: []const u8) void {
        @field(self, field) = false;
    }

    /// Parses Permissions from JSON (expects a string).
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Permissions {
        const token = try source.nextAllocMax(allocator, .alloc_always, options.max_value_len orelse std.math.maxInt(u32));
        defer {
            switch (token) {
                .allocated_number, .allocated_string => |slice| allocator.free(slice),
                else => {},
            }
        }
        const slice = switch (token) {
            .string, .allocated_string => |s| s,
            else => return error.UnexpectedToken,
        };
        return fromString(slice);
    }

    /// Parses Permissions from an already-parsed JSON value.
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !Permissions {
        _ = allocator;
        _ = options;
        switch (source) {
            .string => |s| return try fromString(s),
            else => return error.UnexpectedToken,
        }
    }

    /// Serializes Permissions to JSON as a string.
    pub fn jsonStringify(self: Permissions, jw: anytype) !void {
        var buf: [32]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{d}", .{@as(u64, @bitCast(self))});
        try jw.write(str);
    }
};

test "permissions fromString and toString" {
    const perms = try Permissions.fromString("104324673");
    var buf: [32]u8 = undefined;
    const str = try perms.toString(&buf);
    try std.testing.expectEqualStrings("104324673", str);
}

test "permissions has add remove" {
    var perms = Permissions{};
    try std.testing.expect(!perms.has("SendMessages"));
    perms.add("SendMessages");
    try std.testing.expect(perms.has("SendMessages"));
    perms.remove("SendMessages");
    try std.testing.expect(!perms.has("SendMessages"));
}

test "permissions json" {
    const allocator = std.testing.allocator;
    const json = "\"104324673\"";
    const parsed = try std.json.parseFromSlice(Permissions, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expect(parsed.value.has("CreateInstantInvite"));
    try std.testing.expect(parsed.value.has("ViewChannel"));
    try std.testing.expect(parsed.value.has("SendMessages"));

    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try std.json.stringify(parsed.value, .{}, fbs.writer());
    try std.testing.expectEqualStrings("\"104324673\"", fbs.getWritten());
}