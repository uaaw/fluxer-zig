const std = @import("std");
const fluxer = @import("fluxer");

// Prefix-command bot example (recommended on Fluxer today).
// Gateway Ready + heartbeat work; slash/application commands are not on Fluxer yet.
// Load FLUXER_BOT_TOKEN from the environment — never hardcode or commit tokens.

/// Command prefix. Messages must start with this (after trim) to be treated as commands.
/// Uses the library default (`fluxer.default_prefix` / `"!"`).
const COMMAND_PREFIX = fluxer.default_prefix;

const MyHandler = struct {
    allocator: std.mem.Allocator,
    client: *fluxer.Client,

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
        .onInteractionCreate = noopInteraction,
    };

    pub fn onReady(ptr: *anyopaque, payload: fluxer.gateway.ReadyPayload) void {
        const self: *MyHandler = @ptrCast(@alignCast(ptr));
        std.log.info("Ready! Logged in as {s}, session {s}", .{
            payload.user.username,
            payload.session_id,
        });
        std.log.info("Prefix commands ({s}): {s}ping [args...], {s}help", .{
            COMMAND_PREFIX,
            COMMAND_PREFIX,
            COMMAND_PREFIX,
        });
        // Presence must be sent only after READY (not right after connect/upgrade).
        const activities = [_]fluxer.gateway.Activity{
            .{ .name = "fluxer-zig", .type = .game },
        };
        self.client.updatePresence(.online, &activities, null, false) catch |err| {
            std.log.warn("Failed to set presence on Ready: {s}", .{@errorName(err)});
        };
    }

    pub fn onMessageCreate(ptr: *anyopaque, payload: fluxer.models.Message) void {
        const self: *MyHandler = @ptrCast(@alignCast(ptr));

        // Avoid reply loops from ourselves / other bots.
        if (payload.author.bot) return;

        const trimmed = std.mem.trim(u8, payload.content, " \t\r\n");
        const parsed = fluxer.prefixParse(trimmed, COMMAND_PREFIX) orelse return;

        if (fluxer.prefixMatchCommand(parsed, "ping")) {
            std.log.info("Command ping (args={s}) from {s} in channel {d}", .{
                parsed.args,
                payload.author.username,
                payload.channel_id.toU64(),
            });
            reply(self, payload.channel_id, "pong");
            return;
        }

        if (fluxer.prefixMatchCommand(parsed, "help")) {
            std.log.info("Command help from {s} in channel {d}", .{
                payload.author.username,
                payload.channel_id.toU64(),
            });
            reply(self, payload.channel_id, "Commands: !ping [args...] → pong; !help → this text");
            return;
        }
    }

    fn reply(self: *MyHandler, channel_id: fluxer.models.Snowflake, content: []const u8) void {
        const sent = self.client.createMessage(channel_id, content) catch |err| {
            std.log.err("Failed to send reply: {s}", .{@errorName(err)});
            return;
        };
        defer sent.deinit();
        std.log.info("Replied: {s}", .{content});
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

    fn noopReactionAdd(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionAddPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopReactionRemove(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemovePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopReactionRemoveAll(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemoveAllPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopReactionRemoveEmoji(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemoveEmojiPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopMsgDeleteBulk(ptr: *anyopaque, payload: fluxer.gateway.MessageDeleteBulkPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleCreate(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleCreatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleDelete(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleDeletePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopBanAdd(ptr: *anyopaque, payload: fluxer.gateway.GuildBanAddPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopBanRemove(ptr: *anyopaque, payload: fluxer.gateway.GuildBanRemovePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopTypingStart(ptr: *anyopaque, payload: fluxer.gateway.TypingStartPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopWebhooksUpdate(ptr: *anyopaque, payload: fluxer.gateway.WebhooksUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopInviteCreate(ptr: *anyopaque, payload: fluxer.gateway.InviteCreatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopInviteDelete(ptr: *anyopaque, payload: fluxer.gateway.InviteDeletePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopVoiceStateUpdate(ptr: *anyopaque, payload: fluxer.gateway.VoiceStateUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopVoiceServerUpdate(ptr: *anyopaque, payload: fluxer.gateway.VoiceServerUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopPresenceUpdate(ptr: *anyopaque, payload: fluxer.gateway.PresenceUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadCreate(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadUpdate(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadDelete(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadListSync(ptr: *anyopaque, payload: fluxer.gateway.ThreadListSyncPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadMemberUpdate(ptr: *anyopaque, payload: fluxer.gateway.ThreadMember) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadMembersUpdate(ptr: *anyopaque, payload: fluxer.gateway.ThreadMembersUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopUserUpdate(ptr: *anyopaque, payload: fluxer.gateway.UserUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopPinsUpdate(ptr: *anyopaque, payload: fluxer.gateway.ChannelPinsUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopEmojisUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildEmojisUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopStickersUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildStickersUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleUpdateBulk(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleUpdateBulkPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopChannelUpdateBulk(ptr: *anyopaque, payload: fluxer.gateway.ChannelUpdateBulkPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopInteraction(ptr: *anyopaque, payload: fluxer.models.Interaction) void {
        _ = ptr;
        _ = payload;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const token = std.process.getEnvVarOwned(allocator, "FLUXER_BOT_TOKEN") catch |err| {
        std.log.err(
            "FLUXER_BOT_TOKEN is not set ({s}). Export your bot token, e.g.: export FLUXER_BOT_TOKEN=...",
            .{@errorName(err)},
        );
        return error.MissingBotToken;
    };
    defer allocator.free(token);

    if (token.len == 0) {
        std.log.err("FLUXER_BOT_TOKEN is empty. Set a non-empty bot token before running.", .{});
        return error.MissingBotToken;
    }

    // guilds + guildMessages + messageContent so MESSAGE_CREATE includes content
    // when the platform treats content as privileged.
    const intents = fluxer.gateway.Intents.guilds()
        .combine(fluxer.gateway.Intents.guildMessages())
        .combine(fluxer.gateway.Intents.messageContent());

    var client = try fluxer.Client.init(allocator, .{
        .token = token,
        .auth_type = .Bot,
        .intents = intents.value,
        .cache = .{ .enabled = true },
    });
    defer client.deinit();

    var handler = MyHandler{
        .allocator = allocator,
        .client = &client,
    };
    const eh = fluxer.gateway.EventHandler{
        .ptr = &handler,
        .vtable = &MyHandler.EventHandlerVTable,
    };

    try client.connect(eh, &handler);

    // Keep the process alive so Gateway heartbeats and message handlers run.
    // Presence is set from onReady (sending op 3 before IDENTIFY closes the gateway).
    // Prefer connect + keep-alive over Client.run() (reconnect loop is incomplete).
    std.time.sleep(std.time.ns_per_s * 60);

    client.disconnect();
}
