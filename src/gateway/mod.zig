pub const payload = @import("payload.zig");
pub const shard = @import("shard.zig");
pub const heartbeat = @import("heartbeat.zig");
pub const errors = @import("errors.zig");
pub const shard_manager = @import("shard_manager.zig");
pub const intents = @import("intents.zig");
pub const event_dispatcher = @import("event_dispatcher.zig");
pub const ready_payload = @import("ready_payload.zig");
pub const delete_payloads = @import("delete_payloads.zig");

pub const GatewayOpcode = payload.GatewayOpcode;
pub const GatewayPayload = payload.GatewayPayload;
pub const GatewayErrorPayload = payload.GatewayErrorPayload;
pub const LazyRequestPayload = payload.LazyRequestPayload;
pub const IdentifyProperties = payload.IdentifyProperties;
pub const IdentifyBody = payload.IdentifyBody;
pub const ResumeBody = payload.ResumeBody;
pub const PresenceUpdate = payload.PresenceUpdate;
pub const Status = payload.Status;
pub const Activity = payload.Activity;
pub const ActivityType = payload.ActivityType;

pub const Shard = shard.Shard;
pub const ShardStatus = shard.ShardStatus;
pub const gateway_url = shard.gateway_url;

pub const ShardManager = shard_manager.ShardManager;

pub const Intents = intents.Intents;

pub const EventDispatcher = event_dispatcher.EventDispatcher;
pub const EventHandler = event_dispatcher.EventHandler;

pub const ReadyPayload = ready_payload.ReadyPayload;

pub const MessageDeletePayload = delete_payloads.MessageDeletePayload;
pub const GuildDeletePayload = delete_payloads.GuildDeletePayload;
pub const ChannelDeletePayload = delete_payloads.ChannelDeletePayload;
pub const GuildMemberRemovePayload = delete_payloads.GuildMemberRemovePayload;
pub const MessageReactionAddPayload = delete_payloads.MessageReactionAddPayload;
pub const MessageReactionRemovePayload = delete_payloads.MessageReactionRemovePayload;
pub const MessageReactionRemoveAllPayload = delete_payloads.MessageReactionRemoveAllPayload;
pub const MessageReactionRemoveEmojiPayload = delete_payloads.MessageReactionRemoveEmojiPayload;
pub const MessageDeleteBulkPayload = delete_payloads.MessageDeleteBulkPayload;
pub const GuildRoleCreatePayload = delete_payloads.GuildRoleCreatePayload;
pub const GuildRoleUpdatePayload = delete_payloads.GuildRoleUpdatePayload;
pub const GuildRoleDeletePayload = delete_payloads.GuildRoleDeletePayload;
pub const GuildBanAddPayload = delete_payloads.GuildBanAddPayload;
pub const GuildBanRemovePayload = delete_payloads.GuildBanRemovePayload;
pub const TypingStartPayload = delete_payloads.TypingStartPayload;
pub const WebhooksUpdatePayload = delete_payloads.WebhooksUpdatePayload;
pub const InviteCreatePayload = delete_payloads.InviteCreatePayload;
pub const InviteDeletePayload = delete_payloads.InviteDeletePayload;
pub const VoiceStateUpdatePayload = delete_payloads.VoiceStateUpdatePayload;
pub const VoiceServerUpdatePayload = delete_payloads.VoiceServerUpdatePayload;
pub const PresenceUpdatePayload = delete_payloads.PresenceUpdatePayload;
pub const ThreadMember = delete_payloads.ThreadMember;
pub const ThreadListSyncPayload = delete_payloads.ThreadListSyncPayload;
pub const ThreadMembersUpdatePayload = delete_payloads.ThreadMembersUpdatePayload;
pub const UserUpdatePayload = delete_payloads.UserUpdatePayload;
pub const ChannelPinsUpdatePayload = delete_payloads.ChannelPinsUpdatePayload;
pub const ChannelRecipientAddPayload = delete_payloads.ChannelRecipientAddPayload;
pub const ChannelRecipientRemovePayload = delete_payloads.ChannelRecipientRemovePayload;
pub const CallCreatePayload = delete_payloads.CallCreatePayload;
pub const CallDeletePayload = delete_payloads.CallDeletePayload;
pub const GuildEmojisUpdatePayload = delete_payloads.GuildEmojisUpdatePayload;
pub const GuildStickersUpdatePayload = delete_payloads.GuildStickersUpdatePayload;
pub const RelationshipAddPayload = delete_payloads.RelationshipAddPayload;
pub const RelationshipRemovePayload = delete_payloads.RelationshipRemovePayload;
pub const GuildRoleUpdateBulkPayload = delete_payloads.GuildRoleUpdateBulkPayload;
pub const ChannelUpdateBulkPayload = delete_payloads.ChannelUpdateBulkPayload;

pub const Interaction = @import("../models/interaction.zig").Interaction;

pub const Heartbeat = heartbeat.Heartbeat;
pub const default_interval_ms = heartbeat.default_interval_ms;
pub const timeout_ms = heartbeat.timeout_ms;

pub const GatewayError = errors.GatewayError;
pub const CloseCode = errors.CloseCode;

test {
    _ = @import("payload.zig");
    _ = @import("shard.zig");
    _ = @import("heartbeat.zig");
    _ = @import("errors.zig");
    _ = @import("shard_manager.zig");
    _ = @import("intents.zig");
    _ = @import("event_dispatcher.zig");
    _ = @import("ready_payload.zig");
    _ = @import("delete_payloads.zig");
}