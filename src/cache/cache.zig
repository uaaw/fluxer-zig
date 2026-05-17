const std = @import("std");
const models = @import("../models/mod.zig");

const Snowflake = models.Snowflake;
const User = models.User;
const Guild = models.Guild;
const Channel = models.Channel;
const Message = models.Message;
const GuildMember = models.GuildMember;
const ChannelType = models.ChannelType;

/// Options for configuring the in-memory cache.
pub const CacheOptions = struct {
    enabled: bool = true,
    message_limit: u32 = 100,
    disabled_events: ?[]const []const u8 = null,
};

/// In-memory cache for gateway-derived objects.
/// All operations are protected by an internal mutex for thread safety.
pub const Cache = struct {
    users: std.AutoHashMap(u64, User),
    guilds: std.AutoHashMap(u64, Guild),
    channels: std.AutoHashMap(u64, Channel),
    messages: std.AutoHashMap(u64, Message),
    members: std.AutoHashMap(u64, GuildMember),
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    options: CacheOptions,

    /// Creates a new Cache with the given allocator and options.
    /// Allocates memory. Caller owns returned memory and must call `deinit`.
    pub fn init(allocator: std.mem.Allocator, options: CacheOptions) !Cache {
        return .{
            .users = std.AutoHashMap(u64, User).init(allocator),
            .guilds = std.AutoHashMap(u64, Guild).init(allocator),
            .channels = std.AutoHashMap(u64, Channel).init(allocator),
            .messages = std.AutoHashMap(u64, Message).init(allocator),
            .members = std.AutoHashMap(u64, GuildMember).init(allocator),
            .allocator = allocator,
            .mutex = .{},
            .options = options,
        };
    }

    /// Releases all resources owned by the cache.
    pub fn deinit(self: *Cache) void {
        self.users.deinit();
        self.guilds.deinit();
        self.channels.deinit();
        self.messages.deinit();
        self.members.deinit();
    }

    /// Returns a copy of the user if present in the cache.
    pub fn getUser(self: *Cache, id: Snowflake) ?User {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.users.get(id.toU64());
    }

    /// Inserts or updates a user in the cache.
    pub fn upsertUser(self: *Cache, user: User) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.users.put(user.id.toU64(), user);
    }

    /// Removes a user from the cache.
    pub fn removeUser(self: *Cache, id: Snowflake) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.users.remove(id.toU64());
    }

    /// Returns a copy of the guild if present in the cache.
    pub fn getGuild(self: *Cache, id: Snowflake) ?Guild {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.guilds.get(id.toU64());
    }

    /// Inserts or updates a guild in the cache.
    pub fn upsertGuild(self: *Cache, guild: Guild) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.guilds.put(guild.id.toU64(), guild);
    }

    /// Removes a guild from the cache.
    pub fn removeGuild(self: *Cache, id: Snowflake) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.guilds.remove(id.toU64());
    }

    /// Returns a copy of the channel if present in the cache.
    pub fn getChannel(self: *Cache, id: Snowflake) ?Channel {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.channels.get(id.toU64());
    }

    /// Inserts or updates a channel in the cache.
    pub fn upsertChannel(self: *Cache, channel: Channel) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.channels.put(channel.id.toU64(), channel);
    }

    /// Removes a channel from the cache.
    pub fn removeChannel(self: *Cache, id: Snowflake) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.channels.remove(id.toU64());
    }

    /// Returns a copy of the message if present in the cache.
    pub fn getMessage(self: *Cache, id: Snowflake) ?Message {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.messages.get(id.toU64());
    }

    /// Inserts or updates a message in the cache.
    pub fn upsertMessage(self: *Cache, message: Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.messages.count() >= self.options.message_limit) {
            var it = self.messages.iterator();
            if (it.next()) |entry| {
                const key = entry.key_ptr.*;
                _ = self.messages.remove(key);
            }
        }
        try self.messages.put(message.id.toU64(), message);
    }

    /// Removes a message from the cache.
    pub fn removeMessage(self: *Cache, id: Snowflake) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.messages.remove(id.toU64());
    }

    /// Returns a copy of the guild member if present in the cache.
    pub fn getMember(self: *Cache, guild_id: Snowflake, user_id: Snowflake) ?GuildMember {
        self.mutex.lock();
        defer self.mutex.unlock();
        const key = composeMemberKey(guild_id, user_id);
        return self.members.get(key);
    }

    /// Inserts or updates a guild member in the cache.
    pub fn upsertMember(self: *Cache, guild_id: Snowflake, member: GuildMember) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const user = member.user orelse return error.MissingUser;
        const key = composeMemberKey(guild_id, user.id);
        try self.members.put(key, member);
    }

    /// Removes a guild member from the cache.
    pub fn removeMember(self: *Cache, guild_id: Snowflake, user_id: Snowflake) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const key = composeMemberKey(guild_id, user_id);
        _ = self.members.remove(key);
    }

    fn composeMemberKey(guild_id: Snowflake, user_id: Snowflake) u64 {
        return guild_id.toU64() ^ (user_id.toU64() << 1);
    }
};

test "Cache init and deinit" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, .{ .enabled = true, .message_limit = 10 });
    defer cache.deinit();
    try std.testing.expect(cache.options.enabled);
    try std.testing.expectEqual(@as(u32, 10), cache.options.message_limit);
}

test "Cache user CRUD" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, .{});
    defer cache.deinit();

    const user = User{
        .id = Snowflake.fromU64(123),
        .username = "test",
    };
    try cache.upsertUser(user);
    const got = cache.getUser(Snowflake.fromU64(123)).?;
    try std.testing.expectEqualStrings("test", got.username);

    cache.removeUser(Snowflake.fromU64(123));
    try std.testing.expect(cache.getUser(Snowflake.fromU64(123)) == null);
}

test "Cache guild CRUD" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, .{});
    defer cache.deinit();

    const guild = Guild{
        .id = Snowflake.fromU64(456),
        .name = "TestGuild",
        .owner_id = Snowflake.fromU64(123),
        .afk_timeout = 300,
        .verification_level = 0,
        .default_message_notifications = 0,
        .explicit_content_filter = 0,
        .roles = &.{},
        .emojis = &.{},
        .features = &.{},
        .mfa_level = 0,
        .system_channel_flags = 0,
        .premium_tier = 0,
        .preferred_locale = "en-US",
        .nsfw_level = 0,
        .premium_progress_bar_enabled = false,
    };
    try cache.upsertGuild(guild);
    const got = cache.getGuild(Snowflake.fromU64(456)).?;
    try std.testing.expectEqualStrings("TestGuild", got.name);

    cache.removeGuild(Snowflake.fromU64(456));
    try std.testing.expect(cache.getGuild(Snowflake.fromU64(456)) == null);
}

test "Cache channel CRUD" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, .{});
    defer cache.deinit();

    const channel = Channel{
        .id = Snowflake.fromU64(789),
        .type = .GuildText,
    };
    try cache.upsertChannel(channel);
    const got = cache.getChannel(Snowflake.fromU64(789)).?;
    try std.testing.expectEqual(ChannelType.GuildText, got.type);

    cache.removeChannel(Snowflake.fromU64(789));
    try std.testing.expect(cache.getChannel(Snowflake.fromU64(789)) == null);
}

test "Cache message limit eviction" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, .{ .message_limit = 2 });
    defer cache.deinit();

    const base_message = Message{
        .id = Snowflake.fromU64(0),
        .channel_id = Snowflake.fromU64(1),
        .author = .{ .id = Snowflake.fromU64(2), .username = "a" },
        .content = "c",
        .timestamp = "2024-01-01T00:00:00.000Z",
        .tts = false,
        .mention_everyone = false,
        .mentions = &.{},
        .mention_roles = &.{},
        .attachments = &.{},
        .embeds = &.{},
        .pinned = false,
        .type = .Default,
    };

    var m1 = base_message;
    m1.id = Snowflake.fromU64(100);
    try cache.upsertMessage(m1);

    var m2 = base_message;
    m2.id = Snowflake.fromU64(200);
    try cache.upsertMessage(m2);

    var m3 = base_message;
    m3.id = Snowflake.fromU64(300);
    try cache.upsertMessage(m3);

    try std.testing.expectEqual(@as(usize, 2), cache.messages.count());
}

test "Cache upsertMember with null user returns error" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, .{});
    defer cache.deinit();

    const member = GuildMember{
        .user = null,
        .roles = &.{},
        .joined_at = "2024-01-01T00:00:00.000Z",
        .deaf = false,
        .mute = false,
    };
    try std.testing.expectError(error.MissingUser, cache.upsertMember(Snowflake.fromU64(999), member));
}

test "Cache member CRUD" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, .{});
    defer cache.deinit();

    const member = GuildMember{
        .user = .{ .id = Snowflake.fromU64(111), .username = "mem" },
        .roles = &.{},
        .joined_at = "2024-01-01T00:00:00.000Z",
        .deaf = false,
        .mute = false,
    };
    try cache.upsertMember(Snowflake.fromU64(999), member);
    const got = cache.getMember(Snowflake.fromU64(999), Snowflake.fromU64(111)).?;
    try std.testing.expectEqualStrings("mem", got.user.?.username);

    cache.removeMember(Snowflake.fromU64(999), Snowflake.fromU64(111));
    try std.testing.expect(cache.getMember(Snowflake.fromU64(999), Snowflake.fromU64(111)) == null);
}