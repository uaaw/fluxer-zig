# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.0.1]

### Added

- Project initialization with `build.zig`, `build.zig.zon`, and `root.zig`
- Core data models: `Snowflake`, `User`, `Guild`, `Channel`, `Message`, `GuildMember`, `Permissions`
- Fluxer-specific model fields: `User.pronouns`/`bio`/`accent_color`, `Channel.Link=998`, `Message.message_snapshots`/`call`, `Guild.disabled_operations`
- HTTP client built on `std.http.Client`
- `RequestBuilder` with fluent API for constructing requests
- `Response` handling for status, headers, body, and JSON parsing
- Rate limiter with per-route buckets and global limit tracking
- `Bucket` management for `limit`/`remaining`/`reset`
- `AuthType` enumeration (`Session`, `Bearer`, `Bot`, `Admin`)
- `FluxerAPIError` struct compatible with Discord API error formats
- RFC 6455 compliant WebSocket frame processing (`parseFrame`/`serializeFrame`)
- TLS support for `wss://` connections using `std.crypto.tls.Client`
- Gateway payload handling (Opcodes 0–14, including Fluxer-specific Opcodes 12 and 14)
- Heartbeat mechanism (41250ms interval) with zombie detection
- `Shard` for WebSocket connection management and automatic reconnection
- `ShardManager` for multi-shard orchestration
- `EventDispatcher` using VTable-based event handlers
- `Intents` bitflag management
- In-memory `Cache` using `std.AutoHashMap` with `Mutex`
- High-level `Client` integrating REST, Gateway, and Cache layers
- Documentation: `README.md`, `README_JA.md`, `API_DESIGN.md`, `API_DESIGN_JA.md`, `ARCHITECTURE.md`, `ARCHITECTURE_JA.md`, `DEVELOP.md`, `CONTRIBUTING.md`

### Fixed

- Resolved future compilation error caused by `std.StringHashMap` `deinit` signature change by implementing a custom `HeaderMap` based on `ArrayList`
- Fixed missing Gateway protocol flow (Hello → Identify → Ready → Heartbeat)
- Fixed TLS stream issue where `std.crypto.tls.Client` was copied by value, causing encryption sequence numbers to desynchronize and drop connections; corrected by pointerizing the TLS client
