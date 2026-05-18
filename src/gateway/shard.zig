const std = @import("std");
const builtin = @import("builtin");
const payload = @import("payload.zig");
const heartbeat = @import("heartbeat.zig");
const websocket = @import("../websocket/mod.zig");
const errors = @import("errors.zig");

/// TLS stream wrapper that adapts `std.crypto.tls.Client` to the `AnyReader`/`AnyWriter` interface.
/// Holds a pointer to the TLS client so that read/write sequence numbers stay synchronized.
const TLSStream = struct {
    tcp: std.net.Stream,
    client: *std.crypto.tls.Client,

    pub fn read(self: *TLSStream, buffer: []u8) !usize {
        return self.client.read(self.tcp, buffer);
    }

    pub fn write(self: *TLSStream, bytes: []const u8) !usize {
        return self.client.write(self.tcp, bytes);
    }

    pub const Reader = std.io.GenericReader(*TLSStream, anyerror, read);
    pub const Writer = std.io.GenericWriter(*TLSStream, anyerror, write);

    pub fn reader(self: *TLSStream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *TLSStream) Writer {
        return .{ .context = self };
    }
};

/// Fluxer Gateway WebSocket URL.
/// Uses API version 1 and JSON encoding as required by the fluxer spec.
pub const gateway_url = "wss://gateway.fluxer.app/?v=1&encoding=json";

/// Heartbeat interval in milliseconds (fluxer spec: 41250ms).
const heartbeat_interval_ms: u64 = 41250;

/// Connection timeout in milliseconds (fluxer spec: 45000ms).
const timeout_ms: u64 = 45000;

/// Shard connection state.
pub const ShardStatus = enum {
    disconnected,
    connecting,
    identifying,
    ready,
    resuming,
};

/// A single gateway shard.
pub const Shard = struct {
    id: u16,
    total_shards: u16,
    status: ShardStatus,
    token: []const u8,
    hb: heartbeat.Heartbeat,
    allocator: std.mem.Allocator,

    // Network state
    stream: ?std.net.Stream,
    tls_client: ?std.crypto.tls.Client,
    receive_thread: ?std.Thread,
    heartbeat_thread: ?std.Thread,
    running: std.atomic.Value(bool),
    receive_mutex: std.Thread.Mutex,

    // Reconnect state
    reconnect_attempts: u32 = 0,
    max_reconnect_attempts: u32 = 5,
    reconnect_delay_ms: u64 = 5000,

    // Session state for resume
    session_id: ?[]const u8 = null,
    sequence: ?u64 = null,

    // Event dispatch callback for EventDispatcher integration
    on_dispatch: ?*const fn (*Shard, payload.GatewayPayload) void = null,
    dispatch_ctx: ?*anyopaque = null,

    // Identify configuration
    intents: u32 = 0,
    properties: payload.IdentifyProperties = .{
        .os = "linux",
        .browser = "fluxer-zig",
        .device = "fluxer-zig",
    },

    pub fn init(allocator: std.mem.Allocator, id: u16, total_shards: u16, token: []const u8) Shard {
        return .{
            .id = id,
            .total_shards = total_shards,
            .status = .disconnected,
            .token = token,
            .hb = heartbeat.Heartbeat.init(heartbeat_interval_ms),
            .allocator = allocator,
            .stream = null,
            .tls_client = null,
            .receive_thread = null,
            .heartbeat_thread = null,
            .running = std.atomic.Value(bool).init(false),
            .receive_mutex = .{},
        };
    }

    /// Releases all resources owned by the shard.
    pub fn deinit(self: *Shard) void {
        self.disconnect();
        if (self.session_id) |sid| {
            self.allocator.free(sid);
            self.session_id = null;
        }
    }

    /// Processes an incoming gateway payload.
    /// Handles fluxer-specific opcodes such as `GatewayError`.
    pub fn handlePayload(self: *Shard, op: payload.GatewayOpcode, data: ?std.json.Value) !void {
        if (!builtin.is_test) {
            std.log.debug("handlePayload received op={s}", .{@tagName(op)});
        }
        switch (op) {
            .hello => {
                self.status = .identifying;

                var extracted_interval: u64 = heartbeat_interval_ms;
                if (data) |d| {
                    if (d.object.get("heartbeat_interval")) |hi| {
                        if (hi == .integer) {
                            extracted_interval = @intCast(hi.integer);
                        }
                    }
                }
                self.hb.interval_ms = extracted_interval;

                if (self.session_id != null and self.sequence != null) {
                    if (self.sendResume()) |resume_body| {
                        self.sendPayloadBody(.resume_session, resume_body) catch |err| {
                            if (!builtin.is_test) std.log.err("sendPayloadBody resume failed: {s}", .{@errorName(err)});
                        };
                    } else |err| {
                        if (!builtin.is_test) std.log.warn("sendResume failed, falling back to identify: {s}", .{@errorName(err)});
                        const identify_body = self.sendIdentify();
                        self.sendPayloadBody(.identify, identify_body) catch |spb_err| {
                            if (!builtin.is_test) std.log.err("sendPayloadBody identify failed: {s}", .{@errorName(spb_err)});
                        };
                    }
                } else {
                    const identify_body = self.sendIdentify();
                    self.sendPayloadBody(.identify, identify_body) catch |err| {
                        if (!builtin.is_test) std.log.err("sendPayloadBody identify failed: {s}", .{@errorName(err)});
                    };
                }

                self.startHeartbeat();
            },
            .heartbeat_ack => {
                // Server acknowledged our heartbeat.
                self.hb.markAck(std.time.milliTimestamp());
            },
            .reconnect => {
                // Server requests reconnect.
                self.status = .resuming;
            },
            .invalid_session => {
                // Session invalidated; re-identify.
                self.status = .identifying;
            },
            .gateway_error => {
                // Fluxer-specific opcode 12: error processing gateway message.
                // Log the error and decide whether to reconnect based on payload.
                if (!builtin.is_test) {
                    if (data) |d| {
                        std.log.err("GatewayError received: {}", .{d});
                    } else {
                        std.log.err("GatewayError received with no data", .{});
                    }
                }
                // For fluxer, most gateway errors are recoverable; trigger reconnect.
                self.status = .resuming;
            },
            // LAZY_REQUEST (op 14) is a send-only opcode in the fluxer spec;
            // the client should never receive it from the server.
            .lazy_request => {
                if (!builtin.is_test) {
                    std.log.warn("Unexpected LAZY_REQUEST (op 14) received from server; ignoring", .{});
                }
            },
            else => {
                // Dispatch and other opcodes are handled elsewhere.
            },
        }
    }

    /// Returns true if the shard should reconnect.
    pub fn shouldReconnect(self: Shard) bool {
        return self.status == .resuming;
    }

    /// Returns true if the heartbeat has timed out.
    pub fn isTimedOut(self: Shard) bool {
        return self.hb.isTimedOut(std.time.milliTimestamp());
    }

    /// Initiates a connection to the gateway.
    /// Parses the WebSocket URL, performs TCP connect and TLS handshake,
    /// sends HTTP upgrade, verifies 101 response, and starts the receive thread.
    pub fn connect(self: *Shard) !void {
        self.receive_mutex.lock();
        defer self.receive_mutex.unlock();

        if (self.stream != null) {
            return error.AlreadyConnected;
        }

        self.status = .connecting;

        // Parse wss:// URL
        const url = gateway_url;
        const host_start = "wss://".len;
        const path_start = std.mem.indexOfScalarPos(u8, url, host_start, '/') orelse url.len;
        const host = url[host_start..path_start];
        const path = url[path_start..];

        // TCP connect
        const stream = std.net.tcpConnectToHost(self.allocator, host, 443) catch |err| {
            self.status = .disconnected;
            if (!builtin.is_test) {
                std.log.err("Failed to TCP connect to {s}: {s}", .{ host, @errorName(err) });
            }
            return err;
        };
        errdefer stream.close();

        // TLS handshake using OS CA bundle
        var ca_bundle: std.crypto.Certificate.Bundle = .{};
        defer ca_bundle.deinit(self.allocator);
        ca_bundle.rescan(self.allocator) catch |err| {
            if (!builtin.is_test) {
                std.log.warn("Failed to rescan OS CA bundle: {s}. Continuing with empty bundle.", .{@errorName(err)});
            }
        };
        var tls_client = std.crypto.tls.Client.init(stream, ca_bundle, host) catch |err| {
            stream.close();
            self.status = .disconnected;
            if (!builtin.is_test) {
                std.log.err("TLS handshake with {s} failed: {s}", .{ host, @errorName(err) });
            }
            return err;
        };

        // Build HTTP upgrade request
        var key_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&key_bytes);
        var key_b64_buf: [24]u8 = undefined;
        const key_b64 = std.base64.standard.Encoder.encode(&key_b64_buf, &key_bytes);

        var req_buf: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&req_buf);
        const req_writer = fbs.writer();
        try req_writer.print("GET {s} HTTP/1.1\r\n", .{path});
        try req_writer.print("Host: {s}\r\n", .{host});
        try req_writer.writeAll("Upgrade: websocket\r\n");
        try req_writer.writeAll("Connection: Upgrade\r\n");
        try req_writer.print("Sec-WebSocket-Key: {s}\r\n", .{key_b64});
        try req_writer.writeAll("Sec-WebSocket-Version: 13\r\n");
        try req_writer.writeAll("\r\n");

        tls_client.writeAll(stream, fbs.getWritten()) catch |err| {
            stream.close();
            self.status = .disconnected;
            return err;
        };

        // Read HTTP response until \r\n\r\n via TLS
        var resp_buf: [4096]u8 = undefined;
        var resp_len: usize = 0;
        while (resp_len < resp_buf.len) {
            const n = tls_client.read(stream, resp_buf[resp_len..]) catch |err| {
                stream.close();
                self.status = .disconnected;
                return err;
            };
            if (n == 0) break;
            resp_len += n;
            if (resp_len >= 4 and std.mem.eql(u8, resp_buf[resp_len - 4 .. resp_len], "\r\n\r\n")) {
                break;
            }
        }

        if (!std.mem.startsWith(u8, resp_buf[0..resp_len], "HTTP/1.1 101")) {
            stream.close();
            self.status = .disconnected;
            return error.WebSocketUpgradeFailed;
        }

        // Sec-WebSocket-Accept validation (RFC 6455)
        const accept_suffix = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        var accept_input: [60]u8 = undefined;
        @memcpy(accept_input[0..24], key_b64);
        @memcpy(accept_input[24..60], accept_suffix);
        var accept_hash: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(&accept_input, &accept_hash, .{});
        var expected_accept: [28]u8 = undefined;
        const expected_str = std.base64.standard.Encoder.encode(&expected_accept, &accept_hash);
        // Extract Sec-WebSocket-Accept from response
        const accept_header = "Sec-WebSocket-Accept: ";
        if (std.mem.indexOf(u8, resp_buf[0..resp_len], accept_header)) |idx| {
            const start = idx + accept_header.len;
            const end = std.mem.indexOfScalarPos(u8, &resp_buf, start, '\r') orelse resp_len;
            if (!std.mem.eql(u8, resp_buf[start..end], expected_str)) {
                stream.close();
                self.status = .disconnected;
                return error.InvalidWebSocketAccept;
            }
        } else {
            stream.close();
            self.status = .disconnected;
            return error.MissingWebSocketAccept;
        }

        self.stream = stream;
        self.tls_client = tls_client;
        self.status = .connecting;
        self.running.store(true, .monotonic);
        const recv_thread = std.Thread.spawn(.{}, Shard.receiveLoop, .{self}) catch |err| {
            stream.close();
            self.stream = null;
            self.tls_client = null;
            self.status = .disconnected;
            return err;
        };
        self.receive_thread = recv_thread;

        self.resetReconnectState();
    }

    /// Disconnects from the gateway and cleans up resources.
    pub fn disconnect(self: *Shard) void {
        self.running.store(false, .monotonic);

        if (self.heartbeat_thread) |t| {
            t.join();
            self.heartbeat_thread = null;
        }

        self.receive_mutex.lock();
        if (self.stream) |s| {
            _ = sendCloseFrameNoLock(self) catch {};
            if (self.tls_client) |*tls| {
                _ = tls.writeAllEnd(s, &.{}, true) catch {};
                self.tls_client = null;
            }
            s.close();
            self.stream = null;
        }
        self.receive_mutex.unlock();

        if (self.receive_thread) |t| {
            t.join();
            self.receive_thread = null;
        }

        self.status = .disconnected;
    }

    fn sendCloseFrameNoLock(self: *Shard) !void {
        if (self.stream) |s| {
            if (self.tls_client) |*tls| {
                var tls_stream = TLSStream{ .tcp = s, .client = tls };
                const writer = tls_stream.writer();
                try websocket.serializeClose(writer.any(), @intFromEnum(errors.CloseCode.normal), null);
            } else {
                const writer = s.writer();
                try websocket.serializeClose(writer.any(), @intFromEnum(errors.CloseCode.normal), null);
            }
        }
    }

    /// Sends a raw text frame over the WebSocket connection.
    pub fn sendRaw(self: *Shard, text: []const u8) !void {
        self.receive_mutex.lock();
        defer self.receive_mutex.unlock();
        if (self.stream) |s| {
            if (self.tls_client) |*tls| {
                var tls_stream = TLSStream{ .tcp = s, .client = tls };
                const writer = tls_stream.writer();
                try websocket.serializeText(writer.any(), text);
            } else {
                const writer = s.writer();
                try websocket.serializeText(writer.any(), text);
            }
        } else {
            return error.NotConnected;
        }
    }

    /// Sends a GatewayPayload over the WebSocket connection.
    pub fn sendPayload(self: *Shard, gp: payload.GatewayPayload) !void {
        var json_str = std.ArrayList(u8).init(self.allocator);
        defer json_str.deinit();
        try std.json.stringify(gp, .{}, json_str.writer());
        try self.sendRaw(json_str.items);
    }

    /// Sends a gateway payload with a typed body struct serialized as JSON.
    /// Builds a JSON string shaped like GatewayPayload without allocating a std.json.Value tree.
    pub fn sendPayloadBody(self: *Shard, op: payload.GatewayOpcode, body: anytype) !void {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        var writer = buf.writer();
        try writer.print("{{\"op\":{d},\"d\":", .{@intFromEnum(op)});
        try std.json.stringify(body, .{}, writer);
        try writer.writeAll("}");
        if (!builtin.is_test) {
            std.log.debug("sendPayloadBody op={s} json={s}", .{ @tagName(op), buf.items });
        }
        try self.sendRaw(buf.items);
    }

    /// Heartbeat loop. Runs in a dedicated thread.
    pub fn heartbeatLoop(self: *Shard) void {
        const jitter = std.crypto.random.uintLessThan(u64, self.hb.interval_ms);
        std.time.sleep(jitter * std.time.ns_per_ms);

        while (self.running.load(.monotonic)) {
            if (!self.hb.last_ack) {
                self.status = .resuming;
                self.running.store(false, .monotonic);
                break;
            }

            self.hb.last_ack = false;
            const hb_payload = payload.GatewayPayload{
                .op = .heartbeat,
                .d = if (self.sequence) |seq| std.json.Value{ .integer = @intCast(seq) } else std.json.Value{ .null = {} },
            };
            self.sendPayload(hb_payload) catch |err| {
                switch (err) {
                    error.NotConnected => return,
                    else => {
                        if (!builtin.is_test) std.log.err("Failed to send heartbeat: {s}", .{@errorName(err)});
                    },
                }
            };
            self.hb.markSent(std.time.milliTimestamp());

            std.time.sleep(self.hb.interval_ms * std.time.ns_per_ms);
        }
    }

    fn startHeartbeat(self: *Shard) void {
        if (builtin.is_test) return;
        if (self.heartbeat_thread != null) return;
        const hb_thread = std.Thread.spawn(.{}, Shard.heartbeatLoop, .{self}) catch |err| {
            std.log.err("failed to spawn heartbeat thread: {s}", .{@errorName(err)});
            return;
        };
        self.heartbeat_thread = hb_thread;
    }

    /// WebSocket receive loop. Runs in a dedicated thread.
    /// Parses frames, handles control frames, and dispatches text payloads.
    pub fn receiveLoop(self: *Shard) void {
        self.receive_mutex.lock();
        const stream_opt = self.stream;
        const tls_client_ptr: ?*std.crypto.tls.Client = if (self.tls_client) |*tls| tls else null;
        self.receive_mutex.unlock();

        const stream = stream_opt orelse {
            self.status = .disconnected;
            return;
        };

        var buffer: [4096]u8 = undefined;
        var tls_stream: ?TLSStream = if (tls_client_ptr) |ptr| TLSStream{ .tcp = stream, .client = ptr } else null;
        while (self.running.load(.monotonic)) {
            const reader = if (tls_stream) |*ts| ts.reader().any() else stream.reader().any();

            if (!builtin.is_test) {
                std.log.debug("receiveLoop waiting for frame...", .{});
            }

            var frame = websocket.parseFrame(reader, self.allocator, &buffer) catch |err| {
                self.status = .resuming;
                switch (err) {
                    error.EndOfStream,
                    error.ConnectionResetByPeer,
                    error.BrokenPipe,
                    error.NotOpenForReading,
                    error.ConnectionTimedOut,
                    => break,
                    else => {
                        if (!builtin.is_test) {
                            std.log.err("frame parse error: {s}", .{@errorName(err)});
                        }
                        break;
                    },
                }
            };
            defer frame.deinit();

            if (!builtin.is_test) {
                std.log.debug("receiveLoop received frame opcode={s} payload_len={d}", .{@tagName(frame.opcode), frame.payload.len});
            }

            switch (frame.opcode) {
                .text => {
                    self.handleFramePayload(frame.payload) catch |err| {
                        if (!builtin.is_test) {
                            std.log.err("payload handle error: {s}", .{@errorName(err)});
                        }
                    };
                },
                .ping => {
                    self.receive_mutex.lock();
                    if (self.stream) |s| {
                        if (self.tls_client) |*tls| {
                            var ping_tls_stream = TLSStream{ .tcp = s, .client = tls };
                            const writer = ping_tls_stream.writer();
                            websocket.serializeFrame(writer.any(), .pong, frame.payload) catch {};
                        } else {
                            const writer = s.writer();
                            websocket.serializeFrame(writer.any(), .pong, frame.payload) catch {};
                        }
                    }
                    self.receive_mutex.unlock();
                },
                .pong => {
                    // Heartbeat ack or keepalive
                },
                .close => {
                    const close_code = if (frame.payload.len >= 2)
                        std.mem.readInt(u16, frame.payload[0..2], .big)
                    else
                        null;
                    self.processCloseCode(close_code) catch |err| {
                        if (!builtin.is_test) std.log.err("processCloseCode error: {s}", .{@errorName(err)});
                    };
                    // Echo close code back (RFC 6455)
                    self.receive_mutex.lock();
                    defer self.receive_mutex.unlock();
                    if (self.stream) |s| {
                        if (self.tls_client) |*tls| {
                            var close_tls_stream = TLSStream{ .tcp = s, .client = tls };
                            const writer = close_tls_stream.writer();
                            const code_to_echo = close_code orelse @intFromEnum(errors.CloseCode.normal);
                            websocket.serializeClose(writer.any(), code_to_echo, null) catch {};
                        } else {
                            const writer = s.writer();
                            const code_to_echo = close_code orelse @intFromEnum(errors.CloseCode.normal);
                            websocket.serializeClose(writer.any(), code_to_echo, null) catch {};
                        }
                    }
                    self.status = .disconnected;
                    break;
                },
                else => {},
            }
        }

        self.receive_mutex.lock();
        if (self.stream) |s| {
            s.close();
            self.stream = null;
        }
        self.tls_client = null;
        self.receive_mutex.unlock();
        self.status = .disconnected;
    }

    fn handleFramePayload(self: *Shard, payload_data: []const u8) !void {
        var parsed = try std.json.parseFromSlice(payload.GatewayPayload, self.allocator, payload_data, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.s) |seq| {
            self.sequence = seq;
        }

        if (parsed.value.t) |t| {
            if (std.mem.eql(u8, t, "READY")) {
                if (parsed.value.d) |d| {
                    if (d.object.get("session_id")) |sid| {
                        if (sid == .string) {
                            if (self.session_id) |old| {
                                self.allocator.free(old);
                            }
                            self.session_id = try self.allocator.dupe(u8, sid.string);
                        }
                    }
                }
                self.status = .ready;
            }
        }

        if (self.on_dispatch) |cb| {
            cb(self, parsed.value);
        }

        self.handlePayload(parsed.value.op, parsed.value.d) catch |err| {
            if (!builtin.is_test) {
                std.log.err("handlePayload error for op={s}: {s}", .{ @tagName(parsed.value.op), @errorName(err) });
            }
        };
    }

    /// Processes a close code from the server and decides whether to reconnect.
    /// This logic was previously inside the old receiveLoop; it is now a helper.
    pub fn processCloseCode(self: *Shard, close_code: ?u16) !void {
        if (close_code) |code| {
            if (code == 1000) {
                // Normal closure
                self.status = .disconnected;
                self.session_id = null;
                self.sequence = null;
            } else {
                // Abnormal closure, attempt reconnect
                try self.tryReconnect();
            }
        } else {
            // Abnormal termination without close code
            try self.tryReconnect();
        }
    }

    /// Attempts to reconnect with exponential backoff.
    pub fn tryReconnect(self: *Shard) !void {
        self.reconnect_attempts += 1;
        if (self.reconnect_attempts > self.max_reconnect_attempts) {
            return error.MaxReconnectAttemptsExceeded;
        }

        const multiplier = std.math.pow(u64, 2, self.reconnect_attempts - 1);
        const delay: u64 = @min(self.reconnect_delay_ms * multiplier, 60000);
        std.time.sleep(delay * std.time.ns_per_ms);

        if (self.session_id != null and self.sequence != null) {
            self.status = .resuming;
        } else {
            self.status = .identifying;
        }
    }

    /// Resets reconnect state after a successful connection.
    pub fn resetReconnectState(self: *Shard) void {
        self.reconnect_attempts = 0;
    }

    /// Builds the IDENTIFY payload body.
    pub fn sendIdentify(self: *Shard) payload.IdentifyBody {
        return payload.IdentifyBody{
            .token = self.token,
            .properties = self.properties,
            .intents = self.intents,
            .shard = .{ self.id, self.total_shards },
        };
    }

    /// Builds the RESUME payload body.
    pub fn sendResume(self: *Shard) !payload.ResumeBody {
        return payload.ResumeBody{
            .token = self.token,
            .session_id = self.session_id orelse return error.NoSessionId,
            .seq = self.sequence orelse return error.NoSequence,
        };
    }

    /// Sends a PRESENCE_UPDATE (op 3) to the gateway.
    pub fn updatePresence(self: *Shard, presence: payload.PresenceUpdate) !void {
        try self.sendPayloadBody(.presence_update, presence);
    }
};

test "shard gateway url is fluxer spec" {
    try std.testing.expectEqualStrings("wss://gateway.fluxer.app/?v=1&encoding=json", gateway_url);
}

test "shard heartbeat interval is 41250ms" {
    try std.testing.expectEqual(@as(u64, 41250), heartbeat_interval_ms);
}

test "shard timeout is 45000ms" {
    try std.testing.expectEqual(@as(u64, 45000), timeout_ms);
}

test "shard init" {
    const shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    try std.testing.expectEqual(@as(u16, 0), shard.id);
    try std.testing.expectEqual(@as(u16, 1), shard.total_shards);
    try std.testing.expectEqual(ShardStatus.disconnected, shard.status);
    try std.testing.expectEqual(@as(u32, 0), shard.reconnect_attempts);
}

test "shard handles gateway_error" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    // Simulate receiving GatewayError opcode.
    try shard.handlePayload(.gateway_error, null);
    try std.testing.expect(shard.shouldReconnect());
}

test "shard handles lazy_request as unexpected" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    // LAZY_REQUEST is send-only; receiving it should be ignored gracefully.
    try shard.handlePayload(.lazy_request, null);
    try std.testing.expect(!shard.shouldReconnect());
}

test "shard processCloseCode normal close" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.status = .ready;
    shard.session_id = "test_session";
    shard.sequence = 42;
    try shard.processCloseCode(1000);
    try std.testing.expectEqual(ShardStatus.disconnected, shard.status);
    try std.testing.expect(shard.session_id == null);
    try std.testing.expect(shard.sequence == null);
}

test "shard processCloseCode abnormal close triggers reconnect" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.status = .ready;
    shard.session_id = "test_session";
    shard.sequence = 42;
    try shard.processCloseCode(1001);
    try std.testing.expectEqual(ShardStatus.resuming, shard.status);
    try std.testing.expectEqual(@as(u32, 1), shard.reconnect_attempts);
}

test "shard processCloseCode no close code triggers reconnect" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.status = .ready;
    try shard.processCloseCode(null);
    try std.testing.expectEqual(ShardStatus.identifying, shard.status);
    try std.testing.expectEqual(@as(u32, 1), shard.reconnect_attempts);
}

test "shard tryReconnect exceeds max" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.reconnect_attempts = 5;
    const result = shard.tryReconnect();
    try std.testing.expectError(error.MaxReconnectAttemptsExceeded, result);
}

test "shard resetReconnectState" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.reconnect_attempts = 3;
    shard.resetReconnectState();
    try std.testing.expectEqual(@as(u32, 0), shard.reconnect_attempts);
}

test "shard sendIdentify" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.intents = 1;
    const identify = shard.sendIdentify();
    try std.testing.expectEqualStrings("test_token", identify.token);
    try std.testing.expectEqual(@as(u32, 1), identify.intents);
    try std.testing.expectEqual(@as(u16, 0), identify.shard.?[0]);
}

test "shard sendResume success" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.session_id = "sess_123";
    shard.sequence = 99;
    const body = try shard.sendResume();
    try std.testing.expectEqualStrings("test_token", body.token);
    try std.testing.expectEqualStrings("sess_123", body.session_id);
    try std.testing.expectEqual(@as(u64, 99), body.seq);
}

test "shard sendResume missing session" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    const result = shard.sendResume();
    try std.testing.expectError(error.NoSessionId, result);
}

test "shard handlePayload hello attempts identify when disconnected" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    // handlePayload(.hello) now catches send errors so that startHeartbeat is always invoked.
    try shard.handlePayload(.hello, null);
    try std.testing.expectEqual(ShardStatus.identifying, shard.status);
    shard.disconnect();
}

test "shard handlePayload hello attempts resume with session" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.session_id = try std.testing.allocator.dupe(u8, "sess_123");
    shard.sequence = 42;
    // handlePayload(.hello) catches send errors and falls back to identify if resume fails.
    try shard.handlePayload(.hello, null);
    try std.testing.expectEqual(ShardStatus.identifying, shard.status);
    shard.disconnect();
    if (shard.session_id) |sid| std.testing.allocator.free(sid);
    shard.session_id = null;
}

test "shard sendPayload when disconnected" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    const gp = payload.GatewayPayload{ .op = .heartbeat };
    const result = shard.sendPayload(gp);
    try std.testing.expectError(error.NotConnected, result);
}

test "shard sendPayloadBody when disconnected" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    const body = payload.IdentifyBody{
        .token = "test_token",
        .properties = .{ .os = "linux", .browser = "test", .device = "test" },
        .intents = 0,
    };
    const result = shard.sendPayloadBody(.identify, body);
    try std.testing.expectError(error.NotConnected, result);
}

test "shard handleFramePayload sets ready on READY" {
    const json =
        \\{"op":0,"t":"READY","d":{"v":1,"user":{"id":"123456789012345678","username":"testbot","discriminator":null,"bot":true},"session_id":"abc123","guilds":[]}}
    ;
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    try shard.handleFramePayload(json);
    try std.testing.expectEqual(ShardStatus.ready, shard.status);
    try std.testing.expectEqualStrings("abc123", shard.session_id.?);
    if (shard.session_id) |sid| std.testing.allocator.free(sid);
    shard.session_id = null;
}

var dispatch_called: bool = false;
var dispatch_payload: ?payload.GatewayPayload = null;

fn testDispatchCallback(shard: *Shard, gp: payload.GatewayPayload) void {
    _ = shard;
    dispatch_called = true;
    dispatch_payload = gp;
}

test "shard full gateway flow" {
    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.on_dispatch = testDispatchCallback;
    dispatch_called = false;
    dispatch_payload = null;

    // 1. Simulate receiving HELLO
    const hello_json =
        \\{"op":10,"d":{"heartbeat_interval":41250}}
    ;
    // handleFramePayload parses JSON and calls handlePayload(.hello)
    // In test mode, sendPayloadBody returns error.NotConnected because
    // there is no active WebSocket stream. The error is caught inside
    // handleFramePayload, so the call itself succeeds.
    try shard.handleFramePayload(hello_json);
    try std.testing.expectEqual(ShardStatus.identifying, shard.status);

    // 2. Simulate receiving READY
    const ready_json =
        \\{"op":0,"t":"READY","d":{"v":1,"user":{"id":"123456789012345678","username":"testbot","discriminator":null,"bot":true},"session_id":"abc123","guilds":[]}}
    ;
    try shard.handleFramePayload(ready_json);
    try std.testing.expectEqual(ShardStatus.ready, shard.status);
    try std.testing.expectEqualStrings("abc123", shard.session_id.?);

    // 3. on_dispatch should have been called for both HELLO and READY frames.
    // Even though handlePayload(.hello) failed with NotConnected, on_dispatch
    // fires before handlePayload, so the callback was invoked.
    try std.testing.expect(dispatch_called);
    try std.testing.expect(dispatch_payload != null);

    if (shard.session_id) |sid| std.testing.allocator.free(sid);
    shard.session_id = null;
}

test "shard receiveLoop parses text frame" {
    var fds: [2]i32 = undefined;
    const rc = std.os.linux.socketpair(std.os.linux.AF.UNIX, std.os.linux.SOCK.STREAM, 0, &fds);
    try std.testing.expectEqual(@as(usize, 0), rc);
    defer {
        _ = std.os.linux.close(fds[0]);
        _ = std.os.linux.close(fds[1]);
    }

    const read_stream = std.net.Stream{ .handle = fds[0] };
    const write_stream = std.net.Stream{ .handle = fds[1] };

    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.on_dispatch = testDispatchCallback;
    dispatch_called = false;
    dispatch_payload = null;

    shard.stream = read_stream;
    shard.running.store(true, .monotonic);

    // Write a WebSocket text frame with a simple JSON payload
    const json_payload =
        \\{"op":0,"t":"MESSAGE_CREATE","d":{"id":"1","channel_id":"2","author":{"id":"3","username":"test"},"content":"hello","timestamp":"2024-01-01T00:00:00.000Z","tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}}
    ;
    var frame_buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&frame_buf);
    try websocket.serializeText(fbs.writer().any(), json_payload);
    const frame_bytes = fbs.getWritten();

    const writer = write_stream.writer();
    try writer.writeAll(frame_bytes);
    _ = std.os.linux.shutdown(fds[1], 1); // SHUT_WR

    // Run receiveLoop synchronously (it will read the frame and then hit EOF)
    shard.receiveLoop();

    try std.testing.expect(dispatch_called);
    try std.testing.expect(dispatch_payload != null);
    try std.testing.expectEqual(ShardStatus.disconnected, shard.status);

    // shard.receiveLoop already closed fds[0] and set stream to null
    shard.stream = null;
}

test "shard handlePayload hello sends identify when connected" {
    var fds: [2]i32 = undefined;
    const rc = std.os.linux.socketpair(std.os.linux.AF.UNIX, std.os.linux.SOCK.STREAM, 0, &fds);
    try std.testing.expectEqual(@as(usize, 0), rc);
    defer {
        _ = std.os.linux.close(fds[0]);
        _ = std.os.linux.close(fds[1]);
    }

    const read_stream = std.net.Stream{ .handle = fds[0] };
    const write_stream = std.net.Stream{ .handle = fds[1] };

    var shard = Shard.init(std.testing.allocator, 0, 1, "test_token");
    shard.stream = read_stream;
    shard.status = .connecting;

    // Simulate receiving HELLO
    try shard.handlePayload(.hello, null);
    try std.testing.expectEqual(ShardStatus.identifying, shard.status);

    // Read the WebSocket frame from the socket
    var buf: [4096]u8 = undefined;
    const n = try write_stream.reader().read(&buf);
    try std.testing.expect(n > 0);

    // Parse the WebSocket frame to unmask the payload
    var fbs = std.io.fixedBufferStream(buf[0..n]);
    var frame_buffer: [4096]u8 = undefined;
    var frame = try websocket.parseFrame(fbs.reader().any(), std.testing.allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(websocket.Opcode.text, frame.opcode);

    // Verify the unmasked payload contains identify JSON
    const json_start = std.mem.indexOf(u8, frame.payload, "{\"op\":2") orelse {
        std.debug.print("unmasked payload: {s}\n", .{frame.payload});
        return error.IdentifyNotFound;
    };
    try std.testing.expect(json_start < frame.payload.len);

    shard.stream = null; // Prevent disconnect from closing fds[0] again
}