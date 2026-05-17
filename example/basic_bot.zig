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
        .onMessageReactionAdd = noopReactionAdd,
        .onMessageReactionRemove = noopReactionRemove,
        .onMessageReactionRemoveAll = noopReactionRemoveAll,
        .onMessageReactionRemoveEmoji = noopReactionRemoveEmoji,
        .onMessageDeleteBulk = noopMsgDeleteBulk,
        .onGuildRoleCreate = noopRoleCreate,
        .onGuildRoleUpdate = noopRoleUpdate,
        .onGuildRoleDelete = noopRoleDelete,
        .onGuildBanAdd = noopBanAdd,
        .onGuildBanRemove = noopBanRemove,
        .onTypingStart = noopTypingStart,
        .onWebhooksUpdate = noopWebhooksUpdate,
        .onInviteCreate = noopInviteCreate,
        .onInviteDelete = noopInviteDelete,
        .onVoiceStateUpdate = noopVoiceStateUpdate,
        .onVoiceServerUpdate = noopVoiceServerUpdate,
        .onPresenceUpdate = noopPresenceUpdate,
        .onThreadCreate = noopThreadCreate,
        .onThreadUpdate = noopThreadUpdate,
        .onThreadDelete = noopThreadDelete,
        .onThreadListSync = noopThreadListSync,
        .onThreadMemberUpdate = noopThreadMemberUpdate,
        .onThreadMembersUpdate = noopThreadMembersUpdate,
        .onUserUpdate = noopUserUpdate,
        .onChannelPinsUpdate = noopPinsUpdate,
        .onGuildEmojisUpdate = noopEmojisUpdate,
        .onGuildStickersUpdate = noopStickersUpdate,
        .onGuildRoleUpdateBulk = noopRoleUpdateBulk,
        .onChannelUpdateBulk = noopChannelUpdateBulk,
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

    fn noopReactionAdd(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionAddPayload) void { _ = ptr; _ = payload; }
    fn noopReactionRemove(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemovePayload) void { _ = ptr; _ = payload; }
    fn noopReactionRemoveAll(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemoveAllPayload) void { _ = ptr; _ = payload; }
    fn noopReactionRemoveEmoji(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemoveEmojiPayload) void { _ = ptr; _ = payload; }
    fn noopMsgDeleteBulk(ptr: *anyopaque, payload: fluxer.gateway.MessageDeleteBulkPayload) void { _ = ptr; _ = payload; }
    fn noopRoleCreate(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleCreatePayload) void { _ = ptr; _ = payload; }
    fn noopRoleUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopRoleDelete(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleDeletePayload) void { _ = ptr; _ = payload; }
    fn noopBanAdd(ptr: *anyopaque, payload: fluxer.gateway.GuildBanAddPayload) void { _ = ptr; _ = payload; }
    fn noopBanRemove(ptr: *anyopaque, payload: fluxer.gateway.GuildBanRemovePayload) void { _ = ptr; _ = payload; }
    fn noopTypingStart(ptr: *anyopaque, payload: fluxer.gateway.TypingStartPayload) void { _ = ptr; _ = payload; }
    fn noopWebhooksUpdate(ptr: *anyopaque, payload: fluxer.gateway.WebhooksUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopInviteCreate(ptr: *anyopaque, payload: fluxer.gateway.InviteCreatePayload) void { _ = ptr; _ = payload; }
    fn noopInviteDelete(ptr: *anyopaque, payload: fluxer.gateway.InviteDeletePayload) void { _ = ptr; _ = payload; }
    fn noopVoiceStateUpdate(ptr: *anyopaque, payload: fluxer.gateway.VoiceStateUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopVoiceServerUpdate(ptr: *anyopaque, payload: fluxer.gateway.VoiceServerUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopPresenceUpdate(ptr: *anyopaque, payload: fluxer.gateway.PresenceUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopThreadCreate(ptr: *anyopaque, payload: fluxer.models.Channel) void { _ = ptr; _ = payload; }
    fn noopThreadUpdate(ptr: *anyopaque, payload: fluxer.models.Channel) void { _ = ptr; _ = payload; }
    fn noopThreadDelete(ptr: *anyopaque, payload: fluxer.models.Channel) void { _ = ptr; _ = payload; }
    fn noopThreadListSync(ptr: *anyopaque, payload: fluxer.gateway.ThreadListSyncPayload) void { _ = ptr; _ = payload; }
    fn noopThreadMemberUpdate(ptr: *anyopaque, payload: fluxer.gateway.ThreadMember) void { _ = ptr; _ = payload; }
    fn noopThreadMembersUpdate(ptr: *anyopaque, payload: fluxer.gateway.ThreadMembersUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopUserUpdate(ptr: *anyopaque, payload: fluxer.gateway.UserUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopPinsUpdate(ptr: *anyopaque, payload: fluxer.gateway.ChannelPinsUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopEmojisUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildEmojisUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopStickersUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildStickersUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopRoleUpdateBulk(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleUpdateBulkPayload) void { _ = ptr; _ = payload; }
    fn noopChannelUpdateBulk(ptr: *anyopaque, payload: fluxer.gateway.ChannelUpdateBulkPayload) void { _ = ptr; _ = payload; }
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