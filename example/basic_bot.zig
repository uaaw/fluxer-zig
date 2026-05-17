const std = @import("std");
const fluxer = @import("fluxer");

// Basic bot example with typed event handlers and automatic reconnect support.
// The EventDispatcher parses models before passing them to handlers.

const MyHandler = struct {
    allocator: std.mem.Allocator,

    pub const EventHandlerVTable = fluxer.gateway.EventHandler.VTable{
        .onReady = onReady,
        .onMessageCreate = onMessageCreate,
        .onMessageUpdate = noopMessage,
        .onMessageDelete = noopMessageDelete,
        .onGuildCreate = noopGuild,
        .onGuildUpdate = noopGuild,
        .onGuildDelete = noopGuildDelete,
        .onChannelCreate = noopChannel,
        .onChannelUpdate = noopChannel,
        .onChannelDelete = noopChannelDelete,
        .onGuildMemberAdd = noopGuildMember,
        .onGuildMemberUpdate = noopGuildMember,
        .onGuildMemberRemove = noopGuildMemberRemove,
        .onRawGatewayPayload = noopRaw,
        .onRawREST = noopREST,
    };

    pub fn onReady(ptr: *anyopaque, payload: fluxer.gateway.ReadyPayload) void {
        const self: *MyHandler = @ptrCast(@alignCast(ptr));
        _ = self;
        std.log.info("Ready! Logged in as {s}, session {s}", .{
            payload.user.username,
            payload.session_id,
        });
    }

    pub fn onMessageCreate(ptr: *anyopaque, payload: fluxer.models.Message) void {
        const self: *MyHandler = @ptrCast(@alignCast(ptr));
        _ = self;
        std.log.info("Message from {s}: {s}", .{
            payload.author.username,
            payload.content,
        });
    }

    fn noopMessage(ptr: *anyopaque, payload: fluxer.models.Message) void {
        _ = ptr;
        _ = payload;
    }

    fn noopMessageDelete(ptr: *anyopaque, payload: fluxer.gateway.MessageDeletePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuild(ptr: *anyopaque, payload: fluxer.models.Guild) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuildDelete(ptr: *anyopaque, payload: fluxer.gateway.GuildDeletePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopChannel(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }

    fn noopChannelDelete(ptr: *anyopaque, payload: fluxer.gateway.ChannelDeletePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuildMember(ptr: *anyopaque, payload: fluxer.models.GuildMember) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuildMemberRemove(ptr: *anyopaque, payload: fluxer.gateway.GuildMemberRemovePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopRaw(ptr: *anyopaque, payload: fluxer.gateway.GatewayPayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopREST(ptr: *anyopaque, response: fluxer.rest.Response) void {
        _ = ptr;
        _ = response;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Client initialization with cache enabled
    var client = try fluxer.Client.init(allocator, .{
        .token = "YOUR_BOT_TOKEN",
        .intents = fluxer.gateway.Intents.guildMessages().combine(fluxer.gateway.Intents.guilds()).value,
        .cache = .{ .enabled = true },
    });
    defer client.deinit();

    // Event handler setup
    var handler = MyHandler{ .allocator = allocator };
    const eh = fluxer.gateway.EventHandler{
        .ptr = &handler,
        .vtable = &MyHandler.EventHandlerVTable,
    };

    // Gateway connection with automatic reconnect support
    try client.connect(eh, &handler);

    // Run for 60 seconds
    std.time.sleep(std.time.ns_per_s * 60);

    // Disconnect
    client.disconnect();
}