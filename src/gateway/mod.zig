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