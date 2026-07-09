const std = @import("std");
const fluxer = @import("fluxer");

// Token is loaded from FLUXER_BOT_TOKEN at runtime. Never hardcode secrets.

const BotHandler = struct {
    allocator: std.mem.Allocator,
    client: *fluxer.Client,
    app_id: ?fluxer.models.Snowflake,

    pub const VTable = fluxer.gateway.EventHandler.VTable{
        .onReady = onReady,
        .onMessageCreate = noopMessage,
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
        .onInteractionCreate = onInteractionCreate,
    };

    fn onReady(ptr: *anyopaque, payload: fluxer.gateway.ReadyPayload) void {
        const self: *BotHandler = @ptrCast(@alignCast(ptr));
        std.log.info("Ready! Logged in as {s}", .{payload.user.username});

        self.app_id = payload.user.id;

        const cmd = fluxer.models.ApplicationCommand{
            .name = "ping",
            .description = "Replies with pong!",
        };
        const parsed = self.client.createGlobalCommand(self.app_id.?, cmd) catch |err| {
            std.log.err("Failed to register /ping: {s}", .{@errorName(err)});
            return;
        };
        defer parsed.deinit();
        std.log.info("Registered /ping command!", .{});
    }

    fn onInteractionCreate(ptr: *anyopaque, interaction: fluxer.models.Interaction) void {
        const self: *BotHandler = @ptrCast(@alignCast(ptr));

        if (interaction.type != .ApplicationCommand) return;

        const data = interaction.data orelse return;
        if (!std.mem.eql(u8, data.name orelse return, "ping")) return;

        std.log.info("/ping interaction received", .{});

        // Integer type (4 = ChannelMessageWithSource). Zig 0.13 stringifies
        // InteractionCallbackType as a tag name unless the library adds jsonStringify.
        // createInteractionResponse takes anytype so this body is accepted.
        const response = .{
            .type = @as(u8, 4),
            .data = .{ .content = "pong! 🏓" },
        };
        self.client.createInteractionResponse(interaction.id, interaction.token, response) catch |err| {
            std.log.err("Failed to respond to /ping: {s}", .{@errorName(err)});
            return;
        };
        std.log.info("/ping response sent (pong)", .{});
    }

    // --- noop handlers ---
    fn noopMessage(ptr: *anyopaque, _: fluxer.models.Message) void {
        _ = ptr;
    }
    fn noopMessageDelete(ptr: *anyopaque, _: fluxer.gateway.MessageDeletePayload) void {
        _ = ptr;
    }
    fn noopGuild(ptr: *anyopaque, _: fluxer.models.Guild) void {
        _ = ptr;
    }
    fn noopGuildDelete(ptr: *anyopaque, _: fluxer.gateway.GuildDeletePayload) void {
        _ = ptr;
    }
    fn noopChannel(ptr: *anyopaque, _: fluxer.models.Channel) void {
        _ = ptr;
    }
    fn noopChannelDelete(ptr: *anyopaque, _: fluxer.gateway.ChannelDeletePayload) void {
        _ = ptr;
    }
    fn noopGuildMember(ptr: *anyopaque, _: fluxer.models.GuildMember) void {
        _ = ptr;
    }
    fn noopGuildMemberRemove(ptr: *anyopaque, _: fluxer.gateway.GuildMemberRemovePayload) void {
        _ = ptr;
    }
    fn noopReactionAdd(ptr: *anyopaque, _: fluxer.gateway.MessageReactionAddPayload) void {
        _ = ptr;
    }
    fn noopReactionRemove(ptr: *anyopaque, _: fluxer.gateway.MessageReactionRemovePayload) void {
        _ = ptr;
    }
    fn noopReactionRemoveAll(ptr: *anyopaque, _: fluxer.gateway.MessageReactionRemoveAllPayload) void {
        _ = ptr;
    }
    fn noopReactionRemoveEmoji(ptr: *anyopaque, _: fluxer.gateway.MessageReactionRemoveEmojiPayload) void {
        _ = ptr;
    }
    fn noopMsgDeleteBulk(ptr: *anyopaque, _: fluxer.gateway.MessageDeleteBulkPayload) void {
        _ = ptr;
    }
    fn noopRoleCreate(ptr: *anyopaque, _: fluxer.gateway.GuildRoleCreatePayload) void {
        _ = ptr;
    }
    fn noopRoleUpdate(ptr: *anyopaque, _: fluxer.gateway.GuildRoleUpdatePayload) void {
        _ = ptr;
    }
    fn noopRoleDelete(ptr: *anyopaque, _: fluxer.gateway.GuildRoleDeletePayload) void {
        _ = ptr;
    }
    fn noopBanAdd(ptr: *anyopaque, _: fluxer.gateway.GuildBanAddPayload) void {
        _ = ptr;
    }
    fn noopBanRemove(ptr: *anyopaque, _: fluxer.gateway.GuildBanRemovePayload) void {
        _ = ptr;
    }
    fn noopTypingStart(ptr: *anyopaque, _: fluxer.gateway.TypingStartPayload) void {
        _ = ptr;
    }
    fn noopWebhooksUpdate(ptr: *anyopaque, _: fluxer.gateway.WebhooksUpdatePayload) void {
        _ = ptr;
    }
    fn noopInviteCreate(ptr: *anyopaque, _: fluxer.gateway.InviteCreatePayload) void {
        _ = ptr;
    }
    fn noopInviteDelete(ptr: *anyopaque, _: fluxer.gateway.InviteDeletePayload) void {
        _ = ptr;
    }
    fn noopVoiceStateUpdate(ptr: *anyopaque, _: fluxer.gateway.VoiceStateUpdatePayload) void {
        _ = ptr;
    }
    fn noopVoiceServerUpdate(ptr: *anyopaque, _: fluxer.gateway.VoiceServerUpdatePayload) void {
        _ = ptr;
    }
    fn noopPresenceUpdate(ptr: *anyopaque, _: fluxer.gateway.PresenceUpdatePayload) void {
        _ = ptr;
    }
    fn noopThreadCreate(ptr: *anyopaque, _: fluxer.models.Channel) void {
        _ = ptr;
    }
    fn noopThreadUpdate(ptr: *anyopaque, _: fluxer.models.Channel) void {
        _ = ptr;
    }
    fn noopThreadDelete(ptr: *anyopaque, _: fluxer.models.Channel) void {
        _ = ptr;
    }
    fn noopThreadListSync(ptr: *anyopaque, _: fluxer.gateway.ThreadListSyncPayload) void {
        _ = ptr;
    }
    fn noopThreadMemberUpdate(ptr: *anyopaque, _: fluxer.gateway.ThreadMember) void {
        _ = ptr;
    }
    fn noopThreadMembersUpdate(ptr: *anyopaque, _: fluxer.gateway.ThreadMembersUpdatePayload) void {
        _ = ptr;
    }
    fn noopUserUpdate(ptr: *anyopaque, _: fluxer.gateway.UserUpdatePayload) void {
        _ = ptr;
    }
    fn noopPinsUpdate(ptr: *anyopaque, _: fluxer.gateway.ChannelPinsUpdatePayload) void {
        _ = ptr;
    }
    fn noopEmojisUpdate(ptr: *anyopaque, _: fluxer.gateway.GuildEmojisUpdatePayload) void {
        _ = ptr;
    }
    fn noopStickersUpdate(ptr: *anyopaque, _: fluxer.gateway.GuildStickersUpdatePayload) void {
        _ = ptr;
    }
    fn noopRoleUpdateBulk(ptr: *anyopaque, _: fluxer.gateway.GuildRoleUpdateBulkPayload) void {
        _ = ptr;
    }
    fn noopChannelUpdateBulk(ptr: *anyopaque, _: fluxer.gateway.ChannelUpdateBulkPayload) void {
        _ = ptr;
    }
    fn noopRaw(ptr: *anyopaque, _: fluxer.gateway.GatewayPayload) void {
        _ = ptr;
    }
    fn noopREST(ptr: *anyopaque, _: fluxer.rest.Response) void {
        _ = ptr;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const token = std.process.getEnvVarOwned(allocator, "FLUXER_BOT_TOKEN") catch |err| {
        std.log.err("FLUXER_BOT_TOKEN is not set ({s}). Export your bot token, e.g.: export FLUXER_BOT_TOKEN=...", .{@errorName(err)});
        return error.MissingBotToken;
    };
    defer allocator.free(token);

    if (token.len == 0) {
        std.log.err("FLUXER_BOT_TOKEN is empty. Set a non-empty bot token before running.", .{});
        return error.MissingBotToken;
    }

    std.log.info("Starting Fluxer /ping bot...", .{});

    var client = try fluxer.Client.init(allocator, .{
        .token = token,
        .intents = fluxer.gateway.Intents.guilds().value,
        .cache = .{ .enabled = false },
    });
    defer client.deinit();

    var handler = BotHandler{
        .allocator = allocator,
        .client = &client,
        .app_id = null,
    };

    const eh = fluxer.gateway.EventHandler{
        .ptr = &handler,
        .vtable = &BotHandler.VTable,
    };

    // Use connect (not Client.run — currently stacks reconnects without waiting).
    try client.connect(eh, &handler);
    std.log.info("Gateway connect started. Waiting for Ready / interactions...", .{});

    // Keep-alive for smoke / manual /ping: sleep loop (~5 minutes).
    // Ctrl+C may not be wired; process exits after the window then disconnects.
    const keep_alive_s: u64 = 5 * 60;
    const step_s: u64 = 10;
    var elapsed: u64 = 0;
    while (elapsed < keep_alive_s) : (elapsed += step_s) {
        std.time.sleep(step_s * std.time.ns_per_s);
        if (elapsed + step_s >= keep_alive_s or (elapsed + step_s) % 60 == 0) {
            std.log.info("Still running... {d}s / {d}s", .{ @min(elapsed + step_s, keep_alive_s), keep_alive_s });
        }
    }

    std.log.info("Keep-alive window ended; disconnecting...", .{});
    client.disconnect();
    std.log.info("Bot stopped.", .{});
}
