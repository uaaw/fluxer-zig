const std = @import("std");
const GatewayPayload = @import("payload.zig").GatewayPayload;
const Response = @import("../rest/response.zig").Response;
const ReadyPayload = @import("ready_payload.zig").ReadyPayload;
const Message = @import("../models/message.zig").Message;
const MessageDeletePayload = @import("delete_payloads.zig").MessageDeletePayload;
const Guild = @import("../models/guild.zig").Guild;
const GuildDeletePayload = @import("delete_payloads.zig").GuildDeletePayload;
const Channel = @import("../models/channel.zig").Channel;
const ChannelDeletePayload = @import("delete_payloads.zig").ChannelDeletePayload;
const GuildMember = @import("../models/guild_member.zig").GuildMember;
const GuildMemberRemovePayload = @import("delete_payloads.zig").GuildMemberRemovePayload;
const Cache = @import("../cache/cache.zig").Cache;
const Snowflake = @import("../models/snowflake.zig").Snowflake;
const Interaction = @import("../models/interaction.zig").Interaction;
const dp = @import("delete_payloads.zig");

/// VTable for event handlers.
pub const EventHandler = struct {
    pub const VTable = struct {
        onReady: *const fn (ptr: *anyopaque, payload: ReadyPayload) void,
        onMessageCreate: *const fn (ptr: *anyopaque, payload: Message) void,
        onMessageUpdate: *const fn (ptr: *anyopaque, payload: Message) void,
        onMessageDelete: *const fn (ptr: *anyopaque, payload: MessageDeletePayload) void,
        onGuildCreate: *const fn (ptr: *anyopaque, payload: Guild) void,
        onGuildUpdate: *const fn (ptr: *anyopaque, payload: Guild) void,
        onGuildDelete: *const fn (ptr: *anyopaque, payload: GuildDeletePayload) void,
        onChannelCreate: *const fn (ptr: *anyopaque, payload: Channel) void,
        onChannelUpdate: *const fn (ptr: *anyopaque, payload: Channel) void,
        onChannelDelete: *const fn (ptr: *anyopaque, payload: ChannelDeletePayload) void,
        onGuildMemberAdd: *const fn (ptr: *anyopaque, payload: GuildMember) void,
        onGuildMemberUpdate: *const fn (ptr: *anyopaque, payload: GuildMember) void,
        onGuildMemberRemove: *const fn (ptr: *anyopaque, payload: GuildMemberRemovePayload) void,
        onMessageReactionAdd: *const fn (ptr: *anyopaque, payload: dp.MessageReactionAddPayload) void,
        onMessageReactionRemove: *const fn (ptr: *anyopaque, payload: dp.MessageReactionRemovePayload) void,
        onMessageReactionRemoveAll: *const fn (ptr: *anyopaque, payload: dp.MessageReactionRemoveAllPayload) void,
        onMessageReactionRemoveEmoji: *const fn (ptr: *anyopaque, payload: dp.MessageReactionRemoveEmojiPayload) void,
        onMessageDeleteBulk: *const fn (ptr: *anyopaque, payload: dp.MessageDeleteBulkPayload) void,
        onGuildRoleCreate: *const fn (ptr: *anyopaque, payload: dp.GuildRoleCreatePayload) void,
        onGuildRoleUpdate: *const fn (ptr: *anyopaque, payload: dp.GuildRoleUpdatePayload) void,
        onGuildRoleDelete: *const fn (ptr: *anyopaque, payload: dp.GuildRoleDeletePayload) void,
        onGuildBanAdd: *const fn (ptr: *anyopaque, payload: dp.GuildBanAddPayload) void,
        onGuildBanRemove: *const fn (ptr: *anyopaque, payload: dp.GuildBanRemovePayload) void,
        onTypingStart: *const fn (ptr: *anyopaque, payload: dp.TypingStartPayload) void,
        onWebhooksUpdate: *const fn (ptr: *anyopaque, payload: dp.WebhooksUpdatePayload) void,
        onInviteCreate: *const fn (ptr: *anyopaque, payload: dp.InviteCreatePayload) void,
        onInviteDelete: *const fn (ptr: *anyopaque, payload: dp.InviteDeletePayload) void,
        onVoiceStateUpdate: *const fn (ptr: *anyopaque, payload: dp.VoiceStateUpdatePayload) void,
        onVoiceServerUpdate: *const fn (ptr: *anyopaque, payload: dp.VoiceServerUpdatePayload) void,
        onPresenceUpdate: *const fn (ptr: *anyopaque, payload: dp.PresenceUpdatePayload) void,
        onThreadCreate: *const fn (ptr: *anyopaque, payload: Channel) void,
        onThreadUpdate: *const fn (ptr: *anyopaque, payload: Channel) void,
        onThreadDelete: *const fn (ptr: *anyopaque, payload: Channel) void,
        onThreadListSync: *const fn (ptr: *anyopaque, payload: dp.ThreadListSyncPayload) void,
        onThreadMemberUpdate: *const fn (ptr: *anyopaque, payload: dp.ThreadMember) void,
        onThreadMembersUpdate: *const fn (ptr: *anyopaque, payload: dp.ThreadMembersUpdatePayload) void,
        onUserUpdate: *const fn (ptr: *anyopaque, payload: dp.UserUpdatePayload) void,
        onChannelPinsUpdate: *const fn (ptr: *anyopaque, payload: dp.ChannelPinsUpdatePayload) void,
        onGuildEmojisUpdate: *const fn (ptr: *anyopaque, payload: dp.GuildEmojisUpdatePayload) void,
        onGuildStickersUpdate: *const fn (ptr: *anyopaque, payload: dp.GuildStickersUpdatePayload) void,
        onGuildRoleUpdateBulk: *const fn (ptr: *anyopaque, payload: dp.GuildRoleUpdateBulkPayload) void,
        onChannelUpdateBulk: *const fn (ptr: *anyopaque, payload: dp.ChannelUpdateBulkPayload) void,
        onRawGatewayPayload: *const fn (ptr: *anyopaque, payload: GatewayPayload) void,
        onRawREST: *const fn (ptr: *anyopaque, response: Response) void,
        onInteractionCreate: *const fn (ptr: *anyopaque, payload: Interaction) void,
    };

    ptr: *anyopaque,
    vtable: *const VTable,
};

/// Routes gateway payloads and REST responses to user-provided event handlers.
/// Parses typed models from dispatch events before calling specific handlers.
pub const EventDispatcher = struct {
    handler: EventHandler,
    allocator: std.mem.Allocator,
    cache: ?*Cache = null,

    pub fn init(allocator: std.mem.Allocator, handler: EventHandler) EventDispatcher {
        return .{
            .handler = handler,
            .allocator = allocator,
            .cache = null,
        };
    }

    pub fn dispatch(self: *EventDispatcher, payload: GatewayPayload) void {
        self.handler.vtable.onRawGatewayPayload(self.handler.ptr, payload);
        const t = payload.t orelse return;
        const data = payload.d orelse return;

        if (std.mem.eql(u8, t, "READY")) {
            const parsed = std.json.parseFromValue(ReadyPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.upsertUser(parsed.value.user) catch {};
                for (parsed.value.guilds) |guild| {
                    cache.upsertGuild(guild) catch {};
                }
            }
            self.handler.vtable.onReady(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_CREATE")) {
            const parsed = std.json.parseFromValue(Message, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.upsertMessage(parsed.value) catch {};
            }
            self.handler.vtable.onMessageCreate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_UPDATE")) {
            const parsed = std.json.parseFromValue(Message, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.upsertMessage(parsed.value) catch {};
            }
            self.handler.vtable.onMessageUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_DELETE")) {
            const parsed = std.json.parseFromValue(MessageDeletePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.removeMessage(parsed.value.id);
            }
            self.handler.vtable.onMessageDelete(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_CREATE")) {
            const parsed = std.json.parseFromValue(Guild, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.upsertGuild(parsed.value) catch {};
            }
            self.handler.vtable.onGuildCreate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_UPDATE")) {
            const parsed = std.json.parseFromValue(Guild, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.upsertGuild(parsed.value) catch {};
            }
            self.handler.vtable.onGuildUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_DELETE")) {
            const parsed = std.json.parseFromValue(GuildDeletePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.removeGuild(parsed.value.id);
            }
            self.handler.vtable.onGuildDelete(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "CHANNEL_CREATE")) {
            const parsed = std.json.parseFromValue(Channel, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.upsertChannel(parsed.value) catch {};
            }
            self.handler.vtable.onChannelCreate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "CHANNEL_UPDATE")) {
            const parsed = std.json.parseFromValue(Channel, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.upsertChannel(parsed.value) catch {};
            }
            self.handler.vtable.onChannelUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "CHANNEL_DELETE")) {
            const parsed = std.json.parseFromValue(ChannelDeletePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.removeChannel(parsed.value.id);
            }
            self.handler.vtable.onChannelDelete(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_MEMBER_ADD")) {
            const parsed = std.json.parseFromValue(GuildMember, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                const guild_id = if (data.object.get("guild_id")) |gv| blk: {
                    const parsed_guild_id = std.json.parseFromValue(Snowflake, self.allocator, gv, .{ .ignore_unknown_fields = true }) catch break :blk null;
                    const id = parsed_guild_id.value;
                    parsed_guild_id.deinit();
                    break :blk id;
                } else null;
                if (guild_id) |gid| {
                    cache.upsertMember(gid, parsed.value) catch {};
                }
            }
            self.handler.vtable.onGuildMemberAdd(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_MEMBER_UPDATE")) {
            const parsed = std.json.parseFromValue(GuildMember, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                const guild_id = if (data.object.get("guild_id")) |gv| blk: {
                    const parsed_guild_id = std.json.parseFromValue(Snowflake, self.allocator, gv, .{ .ignore_unknown_fields = true }) catch break :blk null;
                    const id = parsed_guild_id.value;
                    parsed_guild_id.deinit();
                    break :blk id;
                } else null;
                if (guild_id) |gid| {
                    cache.upsertMember(gid, parsed.value) catch {};
                }
            }
            self.handler.vtable.onGuildMemberUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_MEMBER_REMOVE")) {
            const parsed = std.json.parseFromValue(GuildMemberRemovePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            if (self.cache) |cache| {
                cache.removeMember(parsed.value.guild_id, parsed.value.user.id);
            }
            self.handler.vtable.onGuildMemberRemove(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_REACTION_ADD")) {
            const parsed = std.json.parseFromValue(dp.MessageReactionAddPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onMessageReactionAdd(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_REACTION_REMOVE")) {
            const parsed = std.json.parseFromValue(dp.MessageReactionRemovePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onMessageReactionRemove(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_REACTION_REMOVE_ALL")) {
            const parsed = std.json.parseFromValue(dp.MessageReactionRemoveAllPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onMessageReactionRemoveAll(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_REACTION_REMOVE_EMOJI")) {
            const parsed = std.json.parseFromValue(dp.MessageReactionRemoveEmojiPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onMessageReactionRemoveEmoji(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "MESSAGE_DELETE_BULK")) {
            const parsed = std.json.parseFromValue(dp.MessageDeleteBulkPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onMessageDeleteBulk(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_ROLE_CREATE")) {
            const parsed = std.json.parseFromValue(dp.GuildRoleCreatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildRoleCreate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_ROLE_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.GuildRoleUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildRoleUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_ROLE_DELETE")) {
            const parsed = std.json.parseFromValue(dp.GuildRoleDeletePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildRoleDelete(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_BAN_ADD")) {
            const parsed = std.json.parseFromValue(dp.GuildBanAddPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildBanAdd(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_BAN_REMOVE")) {
            const parsed = std.json.parseFromValue(dp.GuildBanRemovePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildBanRemove(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "TYPING_START")) {
            const parsed = std.json.parseFromValue(dp.TypingStartPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onTypingStart(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "WEBHOOKS_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.WebhooksUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onWebhooksUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "INVITE_CREATE")) {
            const parsed = std.json.parseFromValue(dp.InviteCreatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onInviteCreate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "INVITE_DELETE")) {
            const parsed = std.json.parseFromValue(dp.InviteDeletePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onInviteDelete(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "VOICE_STATE_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.VoiceStateUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onVoiceStateUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "VOICE_SERVER_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.VoiceServerUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onVoiceServerUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "PRESENCE_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.PresenceUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onPresenceUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "THREAD_CREATE")) {
            const parsed = std.json.parseFromValue(Channel, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onThreadCreate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "THREAD_UPDATE")) {
            const parsed = std.json.parseFromValue(Channel, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onThreadUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "THREAD_DELETE")) {
            const parsed = std.json.parseFromValue(Channel, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onThreadDelete(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "THREAD_LIST_SYNC")) {
            const parsed = std.json.parseFromValue(dp.ThreadListSyncPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onThreadListSync(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "THREAD_MEMBER_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.ThreadMember, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onThreadMemberUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "THREAD_MEMBERS_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.ThreadMembersUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onThreadMembersUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "USER_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.UserUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onUserUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "CHANNEL_PINS_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.ChannelPinsUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onChannelPinsUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_EMOJIS_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.GuildEmojisUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildEmojisUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_STICKERS_UPDATE")) {
            const parsed = std.json.parseFromValue(dp.GuildStickersUpdatePayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildStickersUpdate(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "GUILD_ROLE_UPDATE_BULK")) {
            const parsed = std.json.parseFromValue(dp.GuildRoleUpdateBulkPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onGuildRoleUpdateBulk(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "CHANNEL_UPDATE_BULK")) {
            const parsed = std.json.parseFromValue(dp.ChannelUpdateBulkPayload, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onChannelUpdateBulk(self.handler.ptr, parsed.value);
        } else if (std.mem.eql(u8, t, "INTERACTION_CREATE")) {
            const parsed = std.json.parseFromValue(Interaction, self.allocator, data, .{ .ignore_unknown_fields = true }) catch return;
            defer parsed.deinit();
            self.handler.vtable.onInteractionCreate(self.handler.ptr, parsed.value);
        }
    }

    pub fn dispatchREST(self: *EventDispatcher, response: Response) void {
        self.handler.vtable.onRawREST(self.handler.ptr, response);
    }
};

const MockHandler = struct {
    ready_called: bool = false,
    message_create_called: bool = false,
    raw_gateway_called: bool = false,
    raw_rest_called: bool = false,

    const vtable = EventHandler.VTable{
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
        .onRawGatewayPayload = onRawGatewayPayload,
        .onRawREST = onRawREST,
        .onInteractionCreate = noopInteraction,
    };

    fn onReady(ptr: *anyopaque, payload: ReadyPayload) void {
        _ = payload;
        const self: *MockHandler = @ptrCast(@alignCast(ptr));
        self.ready_called = true;
    }

    fn onMessageCreate(ptr: *anyopaque, payload: Message) void {
        _ = payload;
        const self: *MockHandler = @ptrCast(@alignCast(ptr));
        self.message_create_called = true;
    }

    fn onRawGatewayPayload(ptr: *anyopaque, payload: GatewayPayload) void {
        _ = payload;
        const self: *MockHandler = @ptrCast(@alignCast(ptr));
        self.raw_gateway_called = true;
    }

    fn onRawREST(ptr: *anyopaque, response: Response) void {
        _ = response;
        const self: *MockHandler = @ptrCast(@alignCast(ptr));
        self.raw_rest_called = true;
    }

    fn noopMessage(ptr: *anyopaque, payload: Message) void {
        _ = ptr;
        _ = payload;
    }

    fn noopMessageDelete(ptr: *anyopaque, payload: MessageDeletePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuild(ptr: *anyopaque, payload: Guild) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuildDelete(ptr: *anyopaque, payload: GuildDeletePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopChannel(ptr: *anyopaque, payload: Channel) void {
        _ = ptr;
        _ = payload;
    }

    fn noopChannelDelete(ptr: *anyopaque, payload: ChannelDeletePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuildMember(ptr: *anyopaque, payload: GuildMember) void {
        _ = ptr;
        _ = payload;
    }

    fn noopGuildMemberRemove(ptr: *anyopaque, payload: GuildMemberRemovePayload) void {
        _ = ptr;
        _ = payload;
    }

    fn noopReactionAdd(ptr: *anyopaque, payload: dp.MessageReactionAddPayload) void { _ = ptr; _ = payload; }
    fn noopReactionRemove(ptr: *anyopaque, payload: dp.MessageReactionRemovePayload) void { _ = ptr; _ = payload; }
    fn noopReactionRemoveAll(ptr: *anyopaque, payload: dp.MessageReactionRemoveAllPayload) void { _ = ptr; _ = payload; }
    fn noopReactionRemoveEmoji(ptr: *anyopaque, payload: dp.MessageReactionRemoveEmojiPayload) void { _ = ptr; _ = payload; }
    fn noopMsgDeleteBulk(ptr: *anyopaque, payload: dp.MessageDeleteBulkPayload) void { _ = ptr; _ = payload; }
    fn noopRoleCreate(ptr: *anyopaque, payload: dp.GuildRoleCreatePayload) void { _ = ptr; _ = payload; }
    fn noopRoleUpdate(ptr: *anyopaque, payload: dp.GuildRoleUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopRoleDelete(ptr: *anyopaque, payload: dp.GuildRoleDeletePayload) void { _ = ptr; _ = payload; }
    fn noopBanAdd(ptr: *anyopaque, payload: dp.GuildBanAddPayload) void { _ = ptr; _ = payload; }
    fn noopBanRemove(ptr: *anyopaque, payload: dp.GuildBanRemovePayload) void { _ = ptr; _ = payload; }
    fn noopTypingStart(ptr: *anyopaque, payload: dp.TypingStartPayload) void { _ = ptr; _ = payload; }
    fn noopWebhooksUpdate(ptr: *anyopaque, payload: dp.WebhooksUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopInviteCreate(ptr: *anyopaque, payload: dp.InviteCreatePayload) void { _ = ptr; _ = payload; }
    fn noopInviteDelete(ptr: *anyopaque, payload: dp.InviteDeletePayload) void { _ = ptr; _ = payload; }
    fn noopVoiceStateUpdate(ptr: *anyopaque, payload: dp.VoiceStateUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopVoiceServerUpdate(ptr: *anyopaque, payload: dp.VoiceServerUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopPresenceUpdate(ptr: *anyopaque, payload: dp.PresenceUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopThreadCreate(ptr: *anyopaque, payload: Channel) void { _ = ptr; _ = payload; }
    fn noopThreadUpdate(ptr: *anyopaque, payload: Channel) void { _ = ptr; _ = payload; }
    fn noopThreadDelete(ptr: *anyopaque, payload: Channel) void { _ = ptr; _ = payload; }
    fn noopThreadListSync(ptr: *anyopaque, payload: dp.ThreadListSyncPayload) void { _ = ptr; _ = payload; }
    fn noopThreadMemberUpdate(ptr: *anyopaque, payload: dp.ThreadMember) void { _ = ptr; _ = payload; }
    fn noopThreadMembersUpdate(ptr: *anyopaque, payload: dp.ThreadMembersUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopUserUpdate(ptr: *anyopaque, payload: dp.UserUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopPinsUpdate(ptr: *anyopaque, payload: dp.ChannelPinsUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopEmojisUpdate(ptr: *anyopaque, payload: dp.GuildEmojisUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopStickersUpdate(ptr: *anyopaque, payload: dp.GuildStickersUpdatePayload) void { _ = ptr; _ = payload; }
    fn noopRoleUpdateBulk(ptr: *anyopaque, payload: dp.GuildRoleUpdateBulkPayload) void { _ = ptr; _ = payload; }
    fn noopChannelUpdateBulk(ptr: *anyopaque, payload: dp.ChannelUpdateBulkPayload) void { _ = ptr; _ = payload; }
    fn noopInteraction(ptr: *anyopaque, payload: Interaction) void { _ = ptr; _ = payload; }
};

test "EventDispatcher dispatches READY" {
    var mock = MockHandler{};
    const handler = EventHandler{
        .ptr = &mock,
        .vtable = &MockHandler.vtable,
    };
    var dispatcher = EventDispatcher.init(std.testing.allocator, handler);

    const json =
        \\{"op":0,"t":"READY","d":{"v":1,"user":{"id":"123456789012345678","username":"testbot","discriminator":null,"bot":true},"session_id":"abc123","guilds":[]}}
    ;
    const parsed = try std.json.parseFromSlice(GatewayPayload, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    dispatcher.dispatch(parsed.value);

    try std.testing.expect(mock.ready_called);
    try std.testing.expect(mock.raw_gateway_called);
}

test "EventDispatcher dispatches MESSAGE_CREATE" {
    var mock = MockHandler{};
    const handler = EventHandler{
        .ptr = &mock,
        .vtable = &MockHandler.vtable,
    };
    var dispatcher = EventDispatcher.init(std.testing.allocator, handler);

    const json =
        \\{"op":0,"t":"MESSAGE_CREATE","d":{"id":"111111111111111111","channel_id":"222222222222222222","author":{"id":"123456789012345678","username":"author","discriminator":null},"content":"hello","timestamp":"2024-01-01T00:00:00.000Z","tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}}
    ;
    const parsed = try std.json.parseFromSlice(GatewayPayload, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    dispatcher.dispatch(parsed.value);

    try std.testing.expect(mock.message_create_called);
    try std.testing.expect(mock.raw_gateway_called);
}

test "EventDispatcher ignores unknown event" {
    var mock = MockHandler{};
    const handler = EventHandler{
        .ptr = &mock,
        .vtable = &MockHandler.vtable,
    };
    var dispatcher = EventDispatcher.init(std.testing.allocator, handler);

    const payload = GatewayPayload{
        .op = .dispatch,
        .t = "UNKNOWN_EVENT",
    };
    dispatcher.dispatch(payload);

    try std.testing.expect(!mock.ready_called);
    try std.testing.expect(!mock.message_create_called);
    try std.testing.expect(mock.raw_gateway_called);
}

test "EventDispatcher dispatches raw REST" {
    var mock = MockHandler{};
    const handler = EventHandler{
        .ptr = &mock,
        .vtable = &MockHandler.vtable,
    };
    var dispatcher = EventDispatcher.init(std.testing.allocator, handler);

    const allocator = std.testing.allocator;
    const body = try allocator.dupe(u8, "test body");
    const headers = @import("../rest/mod.zig").HeaderMap.init(allocator);
    var response = Response{
        .status = .ok,
        .headers = headers,
        .body = body,
        .allocator = allocator,
    };
    defer response.deinit();

    dispatcher.dispatchREST(response);
    try std.testing.expect(mock.raw_rest_called);
}