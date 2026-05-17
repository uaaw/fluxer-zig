# Architecture Overview

This document describes the high-level architecture of the `fluxer-zig` library, a Zig client library for the Fluxer chat platform API.

## Design Goals

- Target Zig 0.13+
- Explicit allocator usage for memory safety
- Thread-based concurrency with non-blocking I/O
- Support both WebSocket (Gateway) and REST API
- Modular design with clear separation of concerns
- JSON-based communication

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         User Code                            │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      Client (client.zig)                     │
│  - High-level facade integrating Gateway + HTTP + Cache        │
│  - Event dispatch to user-provided handlers                    │
│  - Lifecycle management (connect, reconnect, shutdown)       │
└─────────────────────────────────────────────────────────────┘
             │                      │                  │
             ▼                      ▼                  ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Gateway          │  │ REST             │  │ Cache            │
│ (gateway/)       │  │ (rest/)          │  │ (cache/)         │
│ - WebSocket      │  │ - REST requests  │  │ - In-memory      │
│   connection     │  │ - Rate limiting  │  │   object store   │
│ - Heartbeat      │  │ - Request/       │  │ - Guilds, users, │
│ - Payload RX/TX  │  │   Response       │  │   channels, msgs │
└──────────────────┘  └──────────────────┘  └──────────────────┘
             │                      │                  │
             ▼                      ▼                  ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Shard Manager    │  │ Rate Limiter     │  │ Models           │
│ (shard_manager.zig)│ │ (rest/rate_      │  │ (models/*.zig)   │
│ - Shard allocation│  │  limiter.zig)  │  │ - Structs, enums │
│ - Session resume   │  │ - Bucket tracker│  │ - JSON           │
│ - Identify queue   │  │ - Queue + delay │  │   (de)serialize  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
             │                      │
             ▼                      ▼
┌──────────────────┐  ┌──────────────────┐
│ Event Dispatcher │  │ TLS / TCP        │
│ (gateway/event_  │  │ (std.net + TLS)  │
│  dispatcher.zig) │  │ - std.net        │
│ - Parse payload  │  │ - std.crypto.tls │
│ - Route events   │  │ - std.http.Client│
│ - User callbacks │  │                  │
└──────────────────┘  └──────────────────┘
             │
             ▼
┌──────────────────┐
│ WebSocket        │
│ (websocket/)     │
│ - RFC 6455 frame │
│   parser/        │
│   serializer     │
└──────────────────┘
```

## Module Breakdown

### 1. client.zig (Client)
The primary entry point for library users. Provides a unified interface over the gateway and HTTP layers.

Responsibilities:
- Initialize and own the allocator passed by the user
- Configure intents (gateway event subscriptions)
- Start/stop the gateway connection and background tasks
- Expose high-level helpers: `sendMessage`, `getGuild`, etc.
- Dispatch events to user-registered handlers
- Own optional Cache and ShardManager instances

### 2. gateway/ (Gateway)
Manages the WebSocket connection to the Fluxer Gateway.

Files:
- `gateway/mod.zig` — Public re-exports
- `gateway/shard.zig` — Single WebSocket connection, receive loop, reconnect logic
- `gateway/shard_manager.zig` — Orchestrates multiple shards
- `gateway/heartbeat.zig` — Heartbeat timing, ACK monitoring, zombie detection
- `gateway/payload.zig` — Gateway payload structs (opcodes, IDENTIFY, RESUME, etc.)
- `gateway/event_dispatcher.zig` — Routes dispatch events to user handlers and integrates cache
- `gateway/ready_payload.zig` — READY event data model
- `gateway/delete_payloads.zig` — Delete event payloads (MessageDelete, GuildDelete, etc.)
- `gateway/intents.zig` — Gateway intent bitflags
- `gateway/errors.zig` — Gateway-specific error set and close codes

Responsibilities:
- Open and maintain a WebSocket connection via `websocket/`
- Send heartbeats and validate heartbeat ACKs
- Serialize outgoing payloads and deserialize incoming payloads
- Handle close codes and reconnections (with exponential backoff)
- Expose a stream of parsed gateway events
- Integrate with the shard manager for multi-shard bots

### 3. gateway/shard_manager.zig (ShardManager)
Manages multiple gateway shards for large-scale bots.

Responsibilities:
- Manage a fixed number of shards passed at initialization
- Spawn and monitor per-shard gateway tasks
- Map guild IDs to their responsible shard
- Provide a unified view of all shard statuses
- Note: Dynamic shard-count calculation, IDENTIFY rate-limit coordination, and rebalance are planned but not yet implemented

### 4. rest/ (REST Client)
Low-level and mid-level REST API client.

Files:
- `rest/mod.zig` — Public re-exports
- `rest/client.zig` — `HttpClient` with high-level helpers (`getChannel`, `sendMessage`, etc.)
- `rest/request_builder.zig` — Fluent `RequestBuilder` for advanced users to construct raw requests independently (not used by high-level helpers)
- `rest/rate_limiter.zig` — Per-route rate limit compliance with bucket tracking
- `rest/bucket.zig` — Individual bucket state and metadata
- `rest/response.zig` — HTTP response wrapper with status, headers, body, and `json()` helper
- `rest/errors.zig` — `RestError` error set and `fromStatus` mapping

Responsibilities:
- Build and execute HTTP requests (GET, POST, PATCH, DELETE)
- Inject authorization headers and user-agent
- Integrate with the rate limiter before every request
- Handle retries on transient failures
- Return parsed model structs or raw JSON where appropriate

### 5. rest/rate_limiter.zig (RateLimiter)
Per-route rate limit compliance.

Responsibilities:
- Track rate limit buckets keyed by major parameters (route + guild_id, channel_id, etc.)
- Maintain remaining/reset/reset-after metadata per bucket
- Queue requests that exceed the current limit and delay them
- Handle global rate limits (429 responses)

### 6. cache/ (Cache)
Optional in-memory cache of gateway-derived objects.

Files:
- `cache/mod.zig` — Public re-exports (`Cache`, `CacheOptions`)
- `cache/cache.zig` — In-memory store backed by `std.AutoHashMap`

Responsibilities:
- Store guilds, channels, users, roles, messages, voice states
- Update entries on gateway events (create, update, delete)
- Provide lookup by ID with O(1) or O(log n) complexity
- Allow users to disable caching or configure limits (e.g., max cached messages)
- Memory is backed by the same explicit allocator
- All operations are protected by an internal `std.Thread.Mutex`
- Note: `Cache.deinit()` releases the HashMap containers only; any dynamically allocated slices held inside cached model structs (e.g., `Guild.roles`) are not recursively freed in the current implementation

### 7. gateway/event_dispatcher.zig (Event Dispatcher)
Routing layer between gateway payloads and user code.

Responsibilities:
- Map opcode + event name to internal event structs
- Maintain a registry of user event handlers via a VTable (`EventHandler.VTable`)
- Invoke handlers on the gateway thread; users should offload heavy work to separate `std.Thread.spawn` calls
- Integrate with Cache: upsert/remove cached objects on relevant events
- Support raw gateway payload and raw REST response callbacks

### 8. models/ (Models)
Data structures representing API entities.

Files:
- `models/mod.zig` — Public re-exports
- `models/snowflake.zig` — 64-bit Snowflake ID with timestamp extraction helpers
- `models/user.zig` — User struct (id, username, avatar, bot flag, etc.)
- `models/guild.zig` — Guild struct (name, owner_id, verification_level, roles, features, etc.)
- `models/channel.zig` — Channel struct (type, guild_id, name, position, etc.)
- `models/message.zig` — Message struct (id, channel_id, author, content, embeds, etc.)
- `models/guild_member.zig` — GuildMember struct (user, nick, roles, joined_at, etc.)
- `models/permissions.zig` — Permission bitflags and helper functions

Responsibilities:
- Define structs for all API objects (User, Guild, Channel, Message, etc.)
- Standard library auto-serialization is the default; custom `jsonParse`/`jsonStringify` only when needed
- Define enums for constants (channel types, permissions, intents, opcodes)
- Keep models pure (no I/O, no hidden allocations)

### 9. websocket/ (WebSocket)
RFC 6455 compliant WebSocket frame parser and serializer.

Files:
- `websocket/mod.zig` — Public re-exports (`Frame`, `Opcode`, `parseFrame`, `serializeFrame`, `serializeText`, `serializeClose`)
- `websocket/frame.zig` — Frame parsing/serialization, masking, close frames

Responsibilities:
- Parse incoming WebSocket frames from a `std.io.AnyReader`
- Serialize outgoing text, binary, ping, pong, and close frames
- Handle payload length encoding (7/16/64-bit) per RFC 6455
- Apply and unapply XOR masking for client-to-server frames
- Use a caller-provided buffer for small payloads; heap-allocate only when necessary
- TLS encryption is implemented via `std.crypto.tls.Client` in `gateway/shard.zig`. The TLS handshake uses the OS CA bundle (`std.crypto.Certificate.Bundle.rescan`), and all WebSocket frames are read/written through the TLS layer.

### 10. root.zig (Library Root)
Public re-exports and library entry point.

Responsibilities:
- Declare the library version
- Re-export all public modules (`models`, `rest`, `gateway`, `cache`, `websocket`)
- Re-export `Client` and `ClientOptions` for library consumers

## Data Flow

### Gateway Receive Path
```
Shard.receiveLoop ──► websocket.parseFrame ──► GatewayPayload
                                                      │
                                                      ▼
                                          gateway/event_dispatcher.zig
                                            EventDispatcher.dispatch
                                                      │
                                    ┌─────────────────┴─────────────────┐
                                    ▼                                   ▼
                              Cache.update                        User Handler
                              (upsert/remove)                     (VTable callbacks)
```

### HTTP Request Path
```
Client.getChannel ──► HttpClient.request ──► RequestOptions
                                                       │
                                                       ▼
                                           rest/rate_limiter.zig
                                                RateLimiter.submit
                                                       │
                                                       ▼
                                                std.http.Client
                                                       │
                                                       ▼
                                                  Fluxer API
```

### Gateway Send Path (User → HTTP)
```
User ──► Client.createMessage ──► HttpClient.post ──► HttpClient.request
                                                              │
                                                              ▼
                                                     rest/rate_limiter.zig
                                                          RateLimiter
                                                              │
                                                              ▼
                                                       std.http.Client
                                                              │
                                                              ▼
                                                         Fluxer API
```

## Concurrency Model

Zig 0.13+ uses thread-based concurrency:
- The `Client` spawns a dedicated `std.Thread` for the gateway receive loop via `Shard.receiveLoop`
- Each shard runs its own read/write loop on separate threads
- HTTP requests use `std.http.Client` and block the calling thread until completion
- User event handlers run synchronously on the gateway thread; heavy handlers should spawn their own `std.Thread` to avoid blocking the receive loop
- All shared state (cache, rate limiter) is protected by `std.Thread.Mutex`

Memory safety is ensured by:
- Every public API accepting an explicit `std.mem.Allocator`
- No hidden global allocators
- Clear ownership: who allocates, who frees

## Memory Management Strategy

`fluxer-zig` follows a strict explicit-memory policy:

- **init/deinit pairing**: Every struct that allocates during initialization provides a corresponding `deinit`.
  Examples: `Client.init` ↔ `Client.deinit`, `Cache.init` ↔ `Cache.deinit`, `HttpClient.init` ↔ `HttpClient.deinit`.

- **errdefer for rollback**: Complex initialization sequences use `errdefer` to free partial allocations on failure.
  Example in `Client.init`: `token` is duplicated first; if `HttpClient.init` fails, `errdefer allocator.free(token)` runs before the error propagates.

- **Allocator ownership**: The top-level `Client` owns the user-supplied allocator and passes it down to subsystems (HttpClient, Cache, ShardManager). Subsystems do not own the allocator itself, but they use it for their internal allocations and must clean them up in `deinit`.

- **Slice ownership rules**: Functions that return newly allocated slices (e.g., `std.fmt.allocPrint`, `std.json.stringifyAlloc`) document ownership. Callers must `defer free` or explicitly transfer ownership.

- **Response lifecycle**: `rest/response.zig` owns its body buffer and headers; callers must call `response.deinit()` when done.

- **Frame payload lifecycle**: `websocket/frame.zig` uses a stack buffer for small payloads and heap-allocates only when necessary. `Frame.deinit()` frees only when `owned == true`, making caller cleanup safe in both cases.

## Error Handling Strategy

- Use Zig error unions (`!T`) for all fallible operations.
- Define domain-specific error sets rather than a single catch-all:
  - `RestError` (`rest/errors.zig`): Covers HTTP-level failures (`HttpError`, `Unauthorized`, `Forbidden`, `NotFound`, `RateLimited`, `ServerError`, `JsonError`).
  - `GatewayError` (`gateway/errors.zig`): Covers WebSocket and gateway-level failures (`ConnectionClosed`, `InvalidSession`, `MaxReconnectAttemptsExceeded`, `InvalidWebSocketAccept`, `InvalidOpcode`).

- **Retry strategy**:
  - `ConnectionClosed` / `ConnectionResetByPeer`: The shard triggers `tryReconnect()` with exponential backoff (max 5 attempts, capped at 60s).
  - `RateLimited` (`429`): The `RateLimiter.submit` waits for `retry-after` seconds before re-issuing the request.
  - `InvalidSession`: The shard resets `session_id` and re-identifies instead of resuming.
  - HTTP `5xx` (`ServerError`): Not automatically retried by the REST client in the current implementation; callers must handle retries if needed.

- **Error propagation rules**:
  - Transient network errors are absorbed by the gateway/retry layers where possible.
  - Fatal errors (e.g., `MaxReconnectAttemptsExceeded`) propagate to the caller.
  - Invalid payloads are logged and skipped to keep the connection alive.

## JSON Strategy

- Standard library auto-serialization (`std.json`) is the default; custom `jsonParse`/`jsonStringify` are used only when necessary.
- Use `std.json` for parsing; unknown fields are ignored by default to prevent breakage on API additions.
- Gateway payloads use a standard envelope struct with `op`, `d`, `s`, `t` fields.

## Extensibility

- Users can provide custom event handler structs with callbacks via the `EventHandler` VTable.
- Cache can be replaced or wrapped by implementing the same interface.
- HTTP client can be configured with custom TLS context or proxy settings.
- Additional shards can be hot-added via the shard manager.

## Design Decisions

### Why a custom WebSocket implementation?
Zig's standard library does not include a WebSocket client. We implemented an RFC 6455 compliant frame parser/serializer in `websocket/` to retain full control over framing, masking, and close-handshake behavior without external dependencies.

### Why a VTable-based EventHandler?
Zig does not have language-level interfaces. A VTable (`EventHandler.VTable`) is the idiomatic Zig interface pattern: it gives compile-time type safety for the concrete handler struct while enabling runtime polymorphism via function pointers.

### Why per-route rate limiting?
Discord/Fluxer APIs apply rate limits per route (method + major parameter). The `RateLimiter` tracks independent `Bucket` instances per route, inspired by the eris `SequentialBucket` design. This ensures compliance without unnecessary throttling across unrelated endpoints.

### Why std.Thread-based concurrency?
Zig 0.13 removed `async/await`. All concurrency is implemented with `std.Thread` plus `std.Thread.Mutex` for shared state. This is explicit, predictable, and works on all supported targets.

### Why std.json as the default?
Zig 0.13's `std.json` is sufficiently powerful for API client work. We use auto-parsing (`std.json.parseFromSlice`) by default and only write custom `jsonParse`/`jsonStringify` when the JSON shape deviates from the struct layout (e.g., Snowflake string↔integer coercion).

## Low-Level Design

This section describes the low-level layers that power the high-level APIs. All high-level APIs are thin wrappers over these primitives, and advanced users may interact with them directly.

### RawHTTP Module (rest/)

Provides direct access to raw HTTP request/response plumbing.

Responsibilities:
- `RequestBuilder` constructs method, URL, headers, and body freely
- `Response` exposes status, headers, raw body, and a `json()` helper
- `HttpClient.request(method, path, options)` hits the Fluxer API directly without high-level wrappers
- Used internally by all REST helpers; exposed for power users

### RawGateway Module (gateway/)

Provides direct access to raw Gateway payloads and manual shard control.

Responsibilities:
- `Shard.sendRaw(payload)` transmits raw JSON/Opcode payloads
- `EventDispatcher` exposes raw gateway payload and raw REST callbacks via the VTable
- `Shard.connect()`, `Shard.disconnect()`, `Shard.status()` offer manual lifecycle control
- Used internally by the event dispatcher; exposed for power users

### REST Client Internal Structure

```
HttpClient -> RequestOptions -> RateLimiter -> std.http.Client -> Fluxer API
```

- `HttpClient` implements high-level methods (`getChannel`, `sendMessage`, etc.)
- Every high-level method wraps `request()` with pre-filled path and body via `RequestOptions`
- `RequestBuilder` (low-level) lets advanced users construct requests independently; it is not used by the high-level helpers

### Gateway Client Internal Structure

```
ShardManager -> Shard -> Heartbeat -> websocket/ -> std.net / std.crypto.tls
```

- `Shard` manages a single WebSocket connection
- `ShardManager` orchestrates lifecycle across multiple shards
- `Heartbeat` runs per-shard and handles jitter, ACK monitoring, and zombie detection
- `websocket/` handles RFC 6455 framing below the shard layer

### RateLimiter Internal Structure

Per-route bucket management inspired by eris SequentialBucket.

Responsibilities:
- `RateLimiter.submit(request)` enqueues the request internally
- `RateLimiter.bucketState(route)` exposes bucket metadata for inspection
- Tracks `x-ratelimit-limit`, `x-ratelimit-remaining`, `x-ratelimit-reset`, `x-ratelimit-reset-after`
- Handles global rate limits (429 with `x-ratelimit-global`)

### Cache Internal Structure

Fine-grained cache control for performance tuning.

Responsibilities:
- Toggle caching on/off at initialization
- Partial caching: disable specific events so only selected payloads are cached
- Pluggable backend interface: users can swap the default in-memory store
- `CacheOptions` controls `enabled`, `message_limit`, and `disabled_events`
- Member keys are composed from `guild_id` and `user_id` for unique lookup