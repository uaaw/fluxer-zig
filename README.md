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

Add `fluxer` to your `build.zig.zon` dependencies:

```zig
.{
    .name = "your_project",
    .version = "0.0.0",
    .dependencies = .{
        .fluxer = .{
            .url = "https://github.com/your-org/fluxer-zig/archive/refs/tags/v0.0.1.tar.gz",
            .hash = "...",
        },
    },
    .paths = .{""},
}
```

Then wire the module in your `build.zig`:

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
        .onRawGatewayPayload = noopRawGateway,
        .onRawREST = noopRawREST,
    };

    pub fn onReady(ptr: *anyopaque, ready: fluxer.gateway.ReadyPayload) void {
        _ = ptr;
        std.log.info("Ready as {s}", .{ready.user.username});
    }

    pub fn onMessageCreate(ptr: *anyopaque, message: fluxer.models.Message) void {
        _ = ptr;
        std.log.info("{s}: {s}", .{message.author.username, message.content});
    }

    fn noopMessage(ptr: *anyopaque, payload: fluxer.models.Message) void { _ = ptr; _ = payload; }
    fn noopMessageDelete(ptr: *anyopaque, payload: fluxer.gateway.MessageDeletePayload) void { _ = ptr; _ = payload; }
    fn noopGuild(ptr: *anyopaque, payload: fluxer.models.Guild) void { _ = ptr; _ = payload; }
    fn noopGuildDelete(ptr: *anyopaque, payload: fluxer.gateway.GuildDeletePayload) void { _ = ptr; _ = payload; }
    fn noopChannel(ptr: *anyopaque, payload: fluxer.models.Channel) void { _ = ptr; _ = payload; }
    fn noopChannelDelete(ptr: *anyopaque, payload: fluxer.gateway.ChannelDeletePayload) void { _ = ptr; _ = payload; }
    fn noopGuildMember(ptr: *anyopaque, payload: fluxer.models.GuildMember) void { _ = ptr; _ = payload; }
    fn noopGuildMemberRemove(ptr: *anyopaque, payload: fluxer.gateway.GuildMemberRemovePayload) void { _ = ptr; _ = payload; }
    fn noopRawGateway(ptr: *anyopaque, payload: fluxer.gateway.GatewayPayload) void { _ = ptr; _ = payload; }
    fn noopRawREST(ptr: *anyopaque, response: fluxer.rest.Response) void { _ = ptr; _ = response; }
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

## Known Limitations

- **Gateway TLS (wss://) is now supported (beta).** `Shard.connect()` uses `std.crypto.tls.Client` with the OS CA bundle for TLS handshake. Certificate verification is enabled by default; if the OS CA bundle cannot be scanned, the handshake may fail on TLS-only endpoints.

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on setting up your development environment, code style, and submitting pull requests.

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

I used the following resources as references when creating this library.
I would like to take this opportunity to express my gratitude.

discord-nodejs library
[eris](https://github.com/abalabahaha/eris.git)