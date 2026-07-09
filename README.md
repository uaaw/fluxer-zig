# fluxer-zig

[![Zig Version](https://img.shields.io/badge/Zig-0.13+-orange.svg)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A low-level Zig library for building [fluxer](https://fluxer.app) chat applications and bots.
Inspired by [eris](https://github.com/abalabahaha/eris),
fluxer-zig provides both high-level convenience and low-level control over the Fluxer API.

## Features

- Full REST API client with raw request access
- WebSocket Gateway client with automatic reconnection
- Per-route rate limiter with bucket state inspection
- In-memory cache with configurable options
- Typed event dispatcher with raw payload fallback
- Multi-shard support with manual shard control
- Fluxer API v1 compatible (base URL: `https://api.fluxer.app/v1`)
- Support for Session / Bearer / Bot / Admin authentication
- Custom WebSocket frame implementation (RFC 6455)
- Zero external dependencies (uses Zig standard library only)

## Installation

### Path dependency (recommended)

Add `fluxer` as a local path dependency in your `build.zig.zon`:

```zig
.{
    .name = "your_project",
    .version = "0.0.0",
    .dependencies = .{
        .fluxer = .{
            .path = "path/to/fluxer-zig",
        },
    },
    .paths = .{""},
}
```

### Remote dependency (optional)

After a release tag is published, fetch the package so Zig records the correct hash for you (do not invent a hash by hand):

```bash
zig fetch --save https://github.com/uaaw/fluxer-zig/archive/refs/tags/v0.0.1.tar.gz
```

Until a tag is published, clone the repository and use the path dependency above.

### Wire the module in `build.zig`

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "your_project",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const fluxer_dep = b.dependency("fluxer", .{});
    exe.root_module.addImport("fluxer", fluxer_dep.module("fluxer"));

    b.installArtifact(exe);
}
```

## Quick Start

Load the bot token from the environment (`FLUXER_BOT_TOKEN`) for local experiments — never hardcode or commit tokens. For a full **prefix-command** bot (recommended on Fluxer today: `!ping`, `!help`), see [`example/basic_bot.zig`](example/basic_bot.zig).

```zig
const std = @import("std");
const fluxer = @import("fluxer");

const Handler = struct {
    pub const VTable = fluxer.gateway.EventHandler.VTable{
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
        .onRawGatewayPayload = noopRawGateway,
        .onRawREST = noopRawREST,
        .onInteractionCreate = noopInteraction,
    };

    pub fn onReady(ptr: *anyopaque, ready: fluxer.gateway.ReadyPayload) void {
        _ = ptr;
        std.log.info("Ready as {s}", .{ready.user.username});
    }

    pub fn onMessageCreate(ptr: *anyopaque, message: fluxer.models.Message) void {
        _ = ptr;
        std.log.info("{s}: {s}", .{ message.author.username, message.content });
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
    fn noopRawGateway(ptr: *anyopaque, payload: fluxer.gateway.GatewayPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRawREST(ptr: *anyopaque, response: fluxer.rest.Response) void {
        _ = ptr;
        _ = response;
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

    var client = try fluxer.Client.init(allocator, .{
        .token = "YOUR_BOT_TOKEN",
        .auth_type = .Bot,
        .intents = fluxer.gateway.Intents.guildMessages().combine(fluxer.gateway.Intents.guilds()).value,
    });
    defer client.deinit();

    var handler = Handler{};
    const eh = fluxer.gateway.EventHandler{ .ptr = &handler, .vtable = &Handler.VTable };
    try client.connect(eh, &handler);

    std.time.sleep(std.time.ns_per_s * 60);
    client.disconnect();
}
```

## Low-Level API

### Raw HTTP Request

```zig
// Direct access to the underlying HTTP client
var response = try client.request(.GET, "/users/@me", .{});
defer response.deinit();
std.log.info("Status: {}", .{response.status});
```

### Manual Shard Control

```zig
var sm = try fluxer.gateway.ShardManager.init(
    allocator,
    2,
    "TOKEN",
    fluxer.gateway.Intents.guildMessages().value,
);
defer sm.deinit();
try sm.startAll();
defer sm.stopAll();
```

## Architecture

| Module | Description |
|--------|-------------|
| `client` | High-level `Client` that integrates REST, Gateway, and Cache |
| `rest` | HTTP client (`HttpClient`), per-route rate limiter (`RateLimiter`), request builder, and bucket state inspection |
| `gateway` | WebSocket gateway (`Shard`), shard manager (`ShardManager`), event dispatcher (`EventDispatcher`), and heartbeat |
| `websocket` | RFC 6455 compliant frame parser (`parseFrame`) and serializer (`serializeFrame`) |
| `models` | API data models: `User`, `Guild`, `Channel`, `Message`, `GuildMember`, `Snowflake`, etc. |
| `cache` | In-memory thread-safe cache (`Cache`) with configurable limits and event filtering |

## Project Status

> **Version 0.0.1** - Initial release with core REST/Gateway support.
>
> This library is in early development. The API may change between versions.
> See [CHANGELOG.md](CHANGELOG.md) for version history.

## Fluxer live status

Verified against a real Fluxer bot token (local experiments only):

| Area | Status |
|------|--------|
| Gateway (Ready + heartbeat) | Works |
| REST (`createMessage`, etc.) | Works for supported routes |
| Application slash commands (`/applications/{id}/commands`) | **Not implemented on Fluxer yet** (official docs; `createGlobalCommand` returns 404) |

**Recommended bot pattern today:** prefix commands on `MESSAGE_CREATE` (not slash). Parse `{prefix}{command}[ args...]` (demo prefix `"!"`), ignore bot authors, reply with `Client.createMessage`. Example: `!ping` / `!ping hello` → `pong`, `!help` → short help. See [`example/basic_bot.zig`](example/basic_bot.zig).

For local runs, set a bot token in the environment and never commit it:

```bash
export FLUXER_BOT_TOKEN="your_bot_token_here"
# never commit tokens, .env files with secrets, or token logs
zig build examples
# then run the built basic_bot binary with FLUXER_BOT_TOKEN set
```

The `why-error/` directory is a local sandbox (gitignored). It is not part of the published package.

## Known Limitations

- **Gateway TLS (wss://) is now supported (beta).** `Shard.connect()` uses `std.crypto.tls.Client` with the OS CA bundle for TLS handshake. Certificate verification is enabled by default; if the OS CA bundle cannot be scanned, the handshake may fail on TLS-only endpoints.
- **Slash / application commands are not available on Fluxer yet.** Library helpers such as `createGlobalCommand` are ready for Discord-style routes, but Fluxer does not expose them; prefer **prefix commands** (`!ping`, etc.) on `MESSAGE_CREATE` until the platform adds slash support.
- **`Client.run()` reconnect loop is incomplete.** Prefer `Client.connect()` plus your own keep-alive / process lifetime (for example sleep until signal). `run` is experimental and does not fully implement clean reconnect stacking for long-lived bots.

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on setting up your development environment, code style, and submitting pull requests.

## Security

To report a vulnerability, please see [SECURITY.md](SECURITY.md).

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

I used the following resources as references when creating this library.
I would like to take this opportunity to express my gratitude.

discord-nodejs library
[eris](https://github.com/abalabahaha/eris.git)
