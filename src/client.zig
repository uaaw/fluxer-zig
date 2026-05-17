const std = @import("std");
const builtin = @import("builtin");
const rest = @import("rest/mod.zig");
const models = @import("models/mod.zig");
const cache_mod = @import("cache/mod.zig");
const gateway = @import("gateway/mod.zig");

const HttpClient = rest.HttpClient;
const RequestOptions = rest.RequestOptions;
const Response = rest.Response;
const AuthType = rest.AuthType;
const Snowflake = models.Snowflake;
const User = models.User;
const Guild = models.Guild;
const Channel = models.Channel;
const Message = models.Message;
const GuildMember = models.GuildMember;
const Cache = cache_mod.Cache;
const CacheOptions = cache_mod.CacheOptions;
const Role = models.Role;

const Ban = struct {
    reason: ?[]const u8 = null,
    user: User,
};

const GatewayBotResponse = struct {
    url: []const u8,
    shards: u32 = 1,
    session_start_limit: SessionStartLimit,
};

const SessionStartLimit = struct {
    total: u32,
    remaining: u32,
    reset_after: u64,
    max_concurrency: u32,
};

/// Options for configuring the Client.
pub const ClientOptions = struct {
    token: []const u8,
    auth_type: AuthType = .Bot,
    intents: u64 = 0,
    num_shards: u32 = 1,
    cache: CacheOptions = .{},
};

/// High-level client for the Fluxer API.
/// Integrates HTTP, Gateway, and Cache.
pub const Client = struct {
    allocator: std.mem.Allocator,
    http: HttpClient,
    shard_manager: ?gateway.ShardManager = null,
    cache: Cache,
    dispatcher: ?gateway.EventDispatcher = null,
    options: ClientOptions,
    shutdown_signal: std.atomic.Value(bool),
    reconnect_enabled: bool = true,
    token_owned: []const u8,

    /// Creates a new Client with the given allocator and options.
    /// Allocates memory. Caller owns returned memory and must call `deinit`.
    pub fn init(allocator: std.mem.Allocator, options: ClientOptions) !Client {
        const token = try allocator.dupe(u8, options.token);
        errdefer allocator.free(token);
        const http = try HttpClient.init(allocator, token, options.auth_type);
        errdefer http.deinit();
        const cache = try Cache.init(allocator, options.cache);
        errdefer cache.deinit();
        return .{
            .allocator = allocator,
            .http = http,
            .cache = cache,
            .options = options,
            .token_owned = token,
            .shutdown_signal = std.atomic.Value(bool).init(false),
        };
    }

    /// Releases all resources owned by the client.
    pub fn deinit(self: *Client) void {
        self.disconnect();
        self.http.deinit();
        self.cache.deinit();
        self.allocator.free(self.token_owned);
    }

    /// Gateway dispatch callback that forwards payloads to the EventDispatcher.
    fn dispatchCallback(shard: *gateway.Shard, pl: gateway.GatewayPayload) void {
        const dispatcher: *gateway.EventDispatcher = @ptrCast(@alignCast(shard.dispatch_ctx.?));
        dispatcher.dispatch(pl);
    }

    /// Starts the gateway connection, shard manager, and event dispatcher.
    /// Wires shards to the dispatcher and optionally integrates the cache.
    pub fn connect(self: *Client, handler: gateway.EventHandler, handler_ctx: *anyopaque) !void {
        var shard_manager = try gateway.ShardManager.init(self.allocator, self.options.num_shards, self.token_owned, self.options.intents);
        errdefer shard_manager.deinit();

        var handler_mut = handler;
        handler_mut.ptr = handler_ctx;
        var dispatcher = gateway.EventDispatcher.init(self.allocator, handler_mut);

        // Wire cache integration if enabled
        if (self.cache.options.enabled) {
            dispatcher.cache = &self.cache;
        }

        // Store in self first to ensure stable addresses for shard callbacks
        self.dispatcher = dispatcher;
        self.shard_manager = shard_manager;

        // Wire each shard to the dispatcher
        for (self.shard_manager.?.shards) |*shard| {
            shard.dispatch_ctx = &self.dispatcher.?;
            shard.on_dispatch = dispatchCallback;
        }

        try self.shard_manager.?.startAll();
    }

    /// Disconnects from the gateway.
    pub fn disconnect(self: *Client) void {
        if (self.shard_manager) |*sm| {
            sm.stopAll();
            sm.deinit();
        }
        self.shard_manager = null;
        self.dispatcher = null;
    }

    /// Performs a raw HTTP request.
    pub fn request(
        self: *Client,
        method: std.http.Method,
        path: []const u8,
        options: RequestOptions,
    ) !Response {
        return self.http.request(method, path, options);
    }

    // Channels

    fn channelPath(allocator: std.mem.Allocator, id: Snowflake) ![]const u8 {
        return std.fmt.allocPrint(allocator, "/channels/{d}", .{id.toU64()});
    }

    pub fn getChannel(self: *Client, id: Snowflake) !std.json.Parsed(Channel) {
        const path = try channelPath(self.allocator, id);
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice(Channel, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn modifyChannel(self: *Client, id: Snowflake, data: anytype) !std.json.Parsed(Channel) {
        const path = try channelPath(self.allocator, id);
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(body);
        var resp = try self.http.patch(path, body);
        defer resp.deinit();
        return std.json.parseFromSlice(Channel, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn deleteChannel(self: *Client, id: Snowflake) !std.json.Parsed(Channel) {
        const path = try channelPath(self.allocator, id);
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
        return std.json.parseFromSlice(Channel, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    fn channelMessagesPath(allocator: std.mem.Allocator, id: Snowflake, query: ?[]const u8) ![]const u8 {
        if (query) |q| {
            return std.fmt.allocPrint(allocator, "/channels/{d}/messages{s}", .{ id.toU64(), q });
        }
        return std.fmt.allocPrint(allocator, "/channels/{d}/messages", .{id.toU64()});
    }

    pub fn getChannelMessages(self: *Client, id: Snowflake, query: ?[]const u8) !std.json.Parsed([]Message) {
        const path = try channelMessagesPath(self.allocator, id, query);
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice([]Message, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    fn channelMessagePath(
        allocator: std.mem.Allocator,
        channel_id: Snowflake,
        message_id: Snowflake,
    ) ![]const u8 {
        return std.fmt.allocPrint(allocator, "/channels/{d}/messages/{d}", .{ channel_id.toU64(), message_id.toU64() });
    }

    pub fn getChannelMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake) !std.json.Parsed(Message) {
        const path = try channelMessagePath(self.allocator, channel_id, message_id);
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice(Message, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn createMessage(self: *Client, channel_id: Snowflake, content: []const u8) !std.json.Parsed(Message) {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/messages", .{channel_id.toU64()});
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, .{ .content = content }, .{});
        defer self.allocator.free(body);
        var resp = try self.http.post(path, body);
        defer resp.deinit();
        return std.json.parseFromSlice(Message, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn editMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake, content: []const u8) !std.json.Parsed(Message) {
        const path = try channelMessagePath(self.allocator, channel_id, message_id);
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, .{ .content = content }, .{});
        defer self.allocator.free(body);
        var resp = try self.http.patch(path, body);
        defer resp.deinit();
        return std.json.parseFromSlice(Message, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn deleteMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake) !void {
        const path = try channelMessagePath(self.allocator, channel_id, message_id);
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    // Guilds

    fn guildPath(allocator: std.mem.Allocator, id: Snowflake) ![]const u8 {
        return std.fmt.allocPrint(allocator, "/guilds/{d}", .{id.toU64()});
    }

    pub fn getGuild(self: *Client, id: Snowflake) !std.json.Parsed(Guild) {
        const path = try guildPath(self.allocator, id);
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice(Guild, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn getGuildChannels(self: *Client, id: Snowflake) !std.json.Parsed([]Channel) {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/channels", .{id.toU64()});
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice([]Channel, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn createGuildChannel(self: *Client, id: Snowflake, name: []const u8) !std.json.Parsed(Channel) {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/channels", .{id.toU64()});
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, .{ .name = name }, .{});
        defer self.allocator.free(body);
        var resp = try self.http.post(path, body);
        defer resp.deinit();
        return std.json.parseFromSlice(Channel, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    fn guildMemberPath(
        allocator: std.mem.Allocator,
        guild_id: Snowflake,
        user_id: Snowflake,
    ) ![]const u8 {
        return std.fmt.allocPrint(allocator, "/guilds/{d}/members/{d}", .{ guild_id.toU64(), user_id.toU64() });
    }

    pub fn getGuildMember(self: *Client, guild_id: Snowflake, user_id: Snowflake) !std.json.Parsed(GuildMember) {
        const path = try guildMemberPath(self.allocator, guild_id, user_id);
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice(GuildMember, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn getGuildMembers(self: *Client, guild_id: Snowflake, limit: ?u32) !std.json.Parsed([]GuildMember) {
        const query = if (limit) |l| try std.fmt.allocPrint(self.allocator, "?limit={d}", .{l}) else "";
        defer if (limit != null) self.allocator.free(query);
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/members{s}", .{ guild_id.toU64(), query });
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice([]GuildMember, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    // Users

    pub fn getCurrentUser(self: *Client) !std.json.Parsed(User) {
        var resp = try self.http.get("/users/@me");
        defer resp.deinit();
        return std.json.parseFromSlice(User, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn getUser(self: *Client, id: Snowflake) !std.json.Parsed(User) {
        const path = try std.fmt.allocPrint(self.allocator, "/users/{d}", .{id.toU64()});
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice(User, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    /// Signals shutdown to the run loop.
    pub fn shutdown(self: *Client) void {
        self.shutdown_signal.store(true, .monotonic);
        self.disconnect();
    }

    /// Connects and enters a reconnect loop. Blocks the calling thread until shutdown() is called.
    pub fn run(self: *Client, handler: gateway.EventHandler, handler_ctx: *anyopaque) !void {
        self.reconnect_enabled = true;
        self.shutdown_signal.store(false, .monotonic);
        while (!self.shutdown_signal.load(.monotonic)) {
            self.connect(handler, handler_ctx) catch |err| {
                if (!builtin.is_test) {
                    std.log.err("Client connect failed: {s}", .{@errorName(err)});
                }
            };
            if (self.shutdown_signal.load(.monotonic)) break;
            if (!self.reconnect_enabled) break;
            var backoff_ms: u64 = 1000;
            var attempt: u32 = 0;
            while (attempt < 5 and !self.shutdown_signal.load(.monotonic)) : (attempt += 1) {
                std.time.sleep(backoff_ms * std.time.ns_per_ms);
                backoff_ms = @min(backoff_ms * 2, 60000);
            }
        }
    }

    // Reactions

    pub fn createReaction(self: *Client, channel_id: Snowflake, message_id: Snowflake, emoji: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/messages/{d}/reactions/{s}/@me", .{ channel_id.toU64(), message_id.toU64(), emoji });
        defer self.allocator.free(path);
        var resp = try self.http.put(path, null);
        defer resp.deinit();
    }

    pub fn deleteOwnReaction(self: *Client, channel_id: Snowflake, message_id: Snowflake, emoji: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/messages/{d}/reactions/{s}/@me", .{ channel_id.toU64(), message_id.toU64(), emoji });
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    pub fn deleteUserReaction(self: *Client, channel_id: Snowflake, message_id: Snowflake, emoji: []const u8, user_id: Snowflake) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/messages/{d}/reactions/{s}/{d}", .{ channel_id.toU64(), message_id.toU64(), emoji, user_id.toU64() });
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    pub fn deleteAllReactions(self: *Client, channel_id: Snowflake, message_id: Snowflake) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/messages/{d}/reactions", .{ channel_id.toU64(), message_id.toU64() });
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    pub fn deleteAllReactionsForEmoji(self: *Client, channel_id: Snowflake, message_id: Snowflake, emoji: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/messages/{d}/reactions/{s}", .{ channel_id.toU64(), message_id.toU64(), emoji });
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    // Typing

    pub fn triggerTypingIndicator(self: *Client, channel_id: Snowflake) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/typing", .{channel_id.toU64()});
        defer self.allocator.free(path);
        var resp = try self.http.post(path, null);
        defer resp.deinit();
    }

    // User

    pub fn modifyCurrentUser(self: *Client, data: anytype) !std.json.Parsed(User) {
        const body = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(body);
        var resp = try self.http.patch("/users/@me", body);
        defer resp.deinit();
        return std.json.parseFromSlice(User, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    // Guild management

    pub fn modifyGuild(self: *Client, id: Snowflake, data: anytype) !std.json.Parsed(Guild) {
        const path = try guildPath(self.allocator, id);
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(body);
        var resp = try self.http.patch(path, body);
        defer resp.deinit();
        return std.json.parseFromSlice(Guild, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn deleteGuild(self: *Client, id: Snowflake) !void {
        const path = try guildPath(self.allocator, id);
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    pub fn getGuildRoles(self: *Client, id: Snowflake) !std.json.Parsed([]Role) {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/roles", .{id.toU64()});
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice([]Role, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn createGuildRole(self: *Client, guild_id: Snowflake, data: anytype) !std.json.Parsed(Role) {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/roles", .{guild_id.toU64()});
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(body);
        var resp = try self.http.post(path, body);
        defer resp.deinit();
        return std.json.parseFromSlice(Role, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn modifyGuildRole(self: *Client, guild_id: Snowflake, role_id: Snowflake, data: anytype) !std.json.Parsed(Role) {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/roles/{d}", .{ guild_id.toU64(), role_id.toU64() });
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(body);
        var resp = try self.http.patch(path, body);
        defer resp.deinit();
        return std.json.parseFromSlice(Role, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn deleteGuildRole(self: *Client, guild_id: Snowflake, role_id: Snowflake) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/roles/{d}", .{ guild_id.toU64(), role_id.toU64() });
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    pub fn getGuildBans(self: *Client, id: Snowflake) !std.json.Parsed([]Ban) {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/bans", .{id.toU64()});
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice([]Ban, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    pub fn createGuildBan(self: *Client, guild_id: Snowflake, user_id: Snowflake, data: anytype) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/bans/{d}", .{ guild_id.toU64(), user_id.toU64() });
        defer self.allocator.free(path);
        const body = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(body);
        var resp = try self.http.put(path, body);
        defer resp.deinit();
    }

    pub fn deleteGuildBan(self: *Client, guild_id: Snowflake, user_id: Snowflake) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/guilds/{d}/bans/{d}", .{ guild_id.toU64(), user_id.toU64() });
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    pub fn kickGuildMember(self: *Client, guild_id: Snowflake, user_id: Snowflake) !void {
        const path = try guildMemberPath(self.allocator, guild_id, user_id);
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    // Pins

    pub fn pinMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/pins/{d}", .{ channel_id.toU64(), message_id.toU64() });
        defer self.allocator.free(path);
        var resp = try self.http.put(path, null);
        defer resp.deinit();
    }

    pub fn unpinMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/pins/{d}", .{ channel_id.toU64(), message_id.toU64() });
        defer self.allocator.free(path);
        var resp = try self.http.delete(path);
        defer resp.deinit();
    }

    pub fn getPinnedMessages(self: *Client, channel_id: Snowflake) !std.json.Parsed([]Message) {
        const path = try std.fmt.allocPrint(self.allocator, "/channels/{d}/pins", .{channel_id.toU64()});
        defer self.allocator.free(path);
        var resp = try self.http.get(path);
        defer resp.deinit();
        return std.json.parseFromSlice([]Message, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }

    // Gateway

    pub fn getGatewayBot(self: *Client) !std.json.Parsed(GatewayBotResponse) {
        var resp = try self.http.get("/gateway/bot");
        defer resp.deinit();
        return std.json.parseFromSlice(GatewayBotResponse, self.allocator, resp.body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    }
};

// URL construction tests

test "channelPath builds correct path" {
    const allocator = std.testing.allocator;
    const id = Snowflake.fromU64(123456789012345678);
    const path = try Client.channelPath(allocator, id);
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/channels/123456789012345678", path);
}

test "channelMessagesPath without query" {
    const allocator = std.testing.allocator;
    const id = Snowflake.fromU64(111);
    const path = try Client.channelMessagesPath(allocator, id, null);
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/channels/111/messages", path);
}

test "channelMessagesPath with query" {
    const allocator = std.testing.allocator;
    const id = Snowflake.fromU64(111);
    const path = try Client.channelMessagesPath(allocator, id, "?limit=10");
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/channels/111/messages?limit=10", path);
}

test "channelMessagePath builds correct path" {
    const allocator = std.testing.allocator;
    const cid = Snowflake.fromU64(111);
    const mid = Snowflake.fromU64(222);
    const path = try Client.channelMessagePath(allocator, cid, mid);
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/channels/111/messages/222", path);
}

test "guildPath builds correct path" {
    const allocator = std.testing.allocator;
    const id = Snowflake.fromU64(555);
    const path = try Client.guildPath(allocator, id);
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/guilds/555", path);
}

test "guildMemberPath builds correct path" {
    const allocator = std.testing.allocator;
    const gid = Snowflake.fromU64(555);
    const uid = Snowflake.fromU64(123);
    const path = try Client.guildMemberPath(allocator, gid, uid);
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/guilds/555/members/123", path);
}

// Mock response parse tests

test "parse channel from mock response" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "333333333333333333",
        \\  "type": 0,
        \\  "guild_id": "444444444444444444",
        \\  "name": "general"
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Channel, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("general", parsed.value.name.?);
}

test "parse message from mock response" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "id": "111111111111111111",
        \\  "channel_id": "222222222222222222",
        \\  "author": {
        \\    "id": "123456789012345678",
        \\    "username": "author",
        \\    "discriminator": null
        \\  },
        \\  "content": "hello",
        \\  "timestamp": "2024-01-01T00:00:00.000Z",
        \\  "tts": false,
        \\  "mention_everyone": false,
        \\  "mentions": [],
        \\  "mention_roles": [],
        \\  "attachments": [],
        \\  "embeds": [],
        \\  "pinned": false,
        \\  "type": 0
        \\}
    ;
    const parsed = try std.json.parseFromSlice(Message, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("hello", parsed.value.content);
}

test "parse guild from mock response" {
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
    const parsed = try std.json.parseFromSlice(Guild, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("Test Guild", parsed.value.name);
}

test "parse user from mock response" {
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
    const parsed = try std.json.parseFromSlice(User, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("testuser", parsed.value.username);
}

test "parse guild member from mock response" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "user": {
        \\    "id": "123456789012345678",
        \\    "username": "testuser",
        \\    "discriminator": null
        \\  },
        \\  "nick": "TestNick",
        \\  "roles": ["111111111111111111", "222222222222222222"],
        \\  "joined_at": "2024-01-01T00:00:00.000Z",
        \\  "deaf": false,
        \\  "mute": false
        \\}
    ;
    const parsed = try std.json.parseFromSlice(GuildMember, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("TestNick", parsed.value.nick.?);
}

test "parse messages array from mock response" {
    const allocator = std.testing.allocator;
    const json =
        \\[
        \\  {
        \\    "id": "111111111111111111",
        \\    "channel_id": "222222222222222222",
        \\    "author": {
        \\      "id": "123456789012345678",
        \\      "username": "author",
        \\      "discriminator": null
        \\    },
        \\    "content": "hello",
        \\    "timestamp": "2024-01-01T00:00:00.000Z",
        \\    "tts": false,
        \\    "mention_everyone": false,
        \\    "mentions": [],
        \\    "mention_roles": [],
        \\    "attachments": [],
        \\    "embeds": [],
        \\    "pinned": false,
        \\    "type": 0
        \\  }
        \\]
    ;
    const parsed = try std.json.parseFromSlice([]Message, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.len);
    try std.testing.expectEqualStrings("hello", parsed.value[0].content);
}