const std = @import("std");

pub const version = "0.0.1";

pub const models = @import("models/mod.zig");
pub const rest = @import("rest/mod.zig");
pub const gateway = @import("gateway/mod.zig");
pub const cache = @import("cache/mod.zig");
pub const websocket = @import("websocket/mod.zig");
pub const commands = @import("commands/mod.zig");
pub const Client = @import("client.zig").Client;
pub const ClientOptions = @import("client.zig").ClientOptions;

pub const prefixParse = commands.parse;
pub const prefixMatchCommand = commands.matchCommand;
pub const PrefixParsed = commands.Parsed;
pub const default_prefix = commands.default_prefix;

pub const Intents = gateway.Intents;
pub const ShardManager = gateway.ShardManager;
pub const Shard = gateway.Shard;
pub const ShardStatus = gateway.ShardStatus;
pub const Heartbeat = gateway.Heartbeat;
pub const default_interval_ms = gateway.default_interval_ms;
pub const timeout_ms = gateway.timeout_ms;
pub const GatewayError = gateway.GatewayError;
pub const CloseCode = gateway.CloseCode;
pub const EventDispatcher = gateway.EventDispatcher;
pub const EventHandler = gateway.EventHandler;
pub const GatewayOpcode = gateway.GatewayOpcode;
pub const GatewayPayload = gateway.GatewayPayload;

pub const RestError = rest.RestError;
pub const FluxerAPIError = rest.FluxerAPIError;
pub const HttpResponse = rest.Response;
pub const RateLimiter = rest.RateLimiter;
pub const BucketState = rest.BucketState;
pub const HeaderMap = rest.HeaderMap;
pub const RequestBuilder = rest.RequestBuilder;
pub const AuthType = rest.AuthType;
pub const RequestOptions = rest.RequestOptions;

pub const WsOpcode = websocket.Opcode;
pub const WsFrame = websocket.Frame;
pub const wsParseFrame = websocket.parseFrame;
pub const wsSerializeFrame = websocket.serializeFrame;
pub const wsSerializeText = websocket.serializeText;
pub const wsSerializeClose = websocket.serializeClose;

pub const Cache = cache.Cache;
pub const CacheOptions = cache.CacheOptions;

pub const VoiceState = models.VoiceState;
pub const Invite = models.Invite;
pub const Interaction = models.Interaction;
pub const ApplicationCommand = models.ApplicationCommand;
pub const EmbedAuthor = models.EmbedAuthor;
pub const EmbedFooter = models.EmbedFooter;
pub const EmbedMedia = models.EmbedMedia;
pub const EmbedProvider = models.EmbedProvider;
pub const Button = models.Button;
pub const SelectMenu = models.SelectMenu;
pub const ComponentType = models.ComponentType;
pub const ButtonStyle = models.ButtonStyle;
pub const SelectOption = models.SelectOption;
pub const TextInput = models.TextInput;
pub const ActionRow = models.ActionRow;
pub const Webhook = models.Webhook;

test {
    std.testing.refAllDecls(@This());
    _ = @import("models/snowflake.zig");
    _ = @import("models/user.zig");
    _ = @import("models/message.zig");
    _ = @import("models/message_component.zig");
    _ = @import("models/channel.zig");
    _ = @import("models/guild.zig");
    _ = @import("models/guild_member.zig");
    _ = @import("models/permissions.zig");
    _ = @import("models/mod.zig");
    _ = @import("rest/mod.zig");
    _ = @import("gateway/mod.zig");
    _ = @import("cache/mod.zig");
    _ = @import("websocket/mod.zig");
    _ = @import("commands/mod.zig");
    _ = @import("client.zig");
}