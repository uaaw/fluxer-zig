# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- REST: avoid `HeaderMap` double-free on non-success HTTP responses (error paths previously ran both `response.deinit()` and `errdefer headers.deinit()`, freeing entries twice under safety allocators)
- REST: own rate-limit route keys so temporary path buffers remain valid after request setup

### Changed

- Docs/examples: recommend **prefix commands** on Fluxer (`MESSAGE_CREATE` + `createMessage`); application slash commands are not implemented on Fluxer yet (`createGlobalCommand` returns 404)
- `example/basic_bot.zig`: true prefix routing with documented `COMMAND_PREFIX = "!"` — `!ping` / `!ping args` → `pong`, `!help` → short help; ignores bot authors; `FLUXER_BOT_TOKEN` only; `connect` + keep-alive (not `Client.run`)

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
- 28 additional gateway events in EventDispatcher: reactions, roles, bans, typing, webhooks, invites, voice state/server, presence, threads, user update, channel pins, guild emojis/stickers, bulk operations
- 31 new payload types in `delete_payloads.zig` for extended event support
- New models: `VoiceState`, `Invite`
- `Client.updatePresence()` for gateway presence/status updates (op 3)
- `Client.run()` and `Client.shutdown()` for managed reconnect loop
- `HttpClient.put()` convenience method
- 26 new REST API methods: reactions (6), typing indicator, guild roles (5), guild bans (3), kick member, message pins (3), modify current user, modify guild, delete guild, get gateway bot
- `Ban`, `GatewayBotResponse`, `SessionStartLimit` types
- Comprehensive root.zig re-exports: 35+ additional types (Intents, ShardManager, RateLimiter, EventDispatcher, HeaderMap, etc.)
- `ActivityType.jsonStringify` for proper integer serialization

### Fixed

- Resolved future compilation error caused by `std.StringHashMap` `deinit` signature change by implementing a custom `HeaderMap` based on `ArrayList`
- Fixed missing Gateway protocol flow (Hello → Identify → Ready → Heartbeat)
- Fixed TLS stream issue where `std.crypto.tls.Client` was copied by value, causing encryption sequence numbers to desynchronize and drop connections; corrected by pointerizing the TLS client
- Fixed `Cache.upsertMember` null user panic: now returns `error.MissingUser`
- Fixed rate limiter race condition: `global_remaining` atomically decremented in `waitForRateLimit()` before request execution
- Fixed `HttpClient.request()` not respecting rate limits: now calls `waitForRateLimit()` before sending
- Fixed `build.zig` circular self-import
- Fixed JSON parsing: all `parseFromSlice`/`parseFromValue` calls use `.ignore_unknown_fields = true` (90+ occurrences) to prevent `error.UnknownField` from API responses with extra fields
- Fixed JSON memory safety: all `parseFromSlice` calls in `client.zig` use `.allocate = .alloc_always` to prevent use-after-free when response body is freed
- Fixed all `parseFromValue` calls in `event_dispatcher.zig` use `.allocate = .alloc_always` to prevent dangling pointers in parsed event data
- Fixed `ShardManager` not passing intents to individual shards, causing IDENTIFY to always send `intents: 0`
- Fixed `ReadyPayload` fields (`v`, `guilds`) made optional for Fluxer API compatibility
- Fixed `Guild` required fields (`system_channel_flags`, `premium_tier`, `preferred_locale`, `premium_progress_bar_enabled`) made optional with defaults for partial Guild objects
- Fixed `Role.color` type (`u32` → `i32`) and `User.accent_color`/`avatar_color` type (`u32` → `i32`) to match Fluxer API `Int32`
- Fixed `User.traits` type (`?[]const u8` → `?[][]const u8`) to match Fluxer's array format
- Fixed `Permissions.fromString` handles empty string (returns default) and `Permissions.jsonParseFromValue` handles integer/null JSON values
- Fixed `Snowflake.parse` handles empty string and `Snowflake.jsonParseFromValue` handles null values
