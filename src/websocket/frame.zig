const std = @import("std");

/// WebSocket frame opcodes per RFC 6455.
pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

/// A parsed WebSocket frame.
/// Allocates memory only when the payload exceeds the caller-provided buffer.
pub const Frame = struct {
    fin: bool,
    rsv1: bool,
    rsv2: bool,
    rsv3: bool,
    opcode: Opcode,
    masked: bool,
    payload: []const u8,
    allocator: std.mem.Allocator,
    owned: bool,

    /// Releases owned payload memory.
    pub fn deinit(self: *Frame) void {
        if (self.owned) {
            self.allocator.free(self.payload);
        }
    }
};

/// Parse a single WebSocket frame from `reader`.
/// `buffer` is used for small payloads; larger payloads are heap-allocated with `allocator`.
/// Allocates memory only when payload_len > buffer.len.
/// Caller must call `frame.deinit()` to free any allocated payload.
pub fn parseFrame(
    reader: std.io.AnyReader,
    allocator: std.mem.Allocator,
    buffer: []u8,
) !Frame {
    const b0 = try reader.readByte();
    const b1 = try reader.readByte();

    const fin = (b0 & 0x80) != 0;
    const rsv1 = (b0 & 0x40) != 0;
    const rsv2 = (b0 & 0x20) != 0;
    const rsv3 = (b0 & 0x10) != 0;
    const opcode: Opcode = @enumFromInt(b0 & 0x0F);
    switch (@intFromEnum(opcode)) {
        0x0, 0x1, 0x2, 0x8, 0x9, 0xA => {},
        else => return error.InvalidOpcode,
    }

    const masked = (b1 & 0x80) != 0;
    var payload_len: u64 = b1 & 0x7F;

    if (payload_len == 126) {
        payload_len = try reader.readInt(u16, .big);
    } else if (payload_len == 127) {
        payload_len = try reader.readInt(u64, .big);
    }

    const payload_len_usize = std.math.cast(usize, payload_len) orelse return error.PayloadTooLarge;

    var mask_key: [4]u8 = undefined;
    if (masked) {
        const mask_n = try reader.readAll(&mask_key);
        if (mask_n != 4) return error.EndOfStream;
    }

    const owned = payload_len_usize > buffer.len;
    const payload = if (owned)
        try allocator.alloc(u8, payload_len_usize)
    else
        buffer[0..payload_len_usize];

    const n = try reader.readAll(payload);
    if (n != payload.len) return error.EndOfStream;

    if (masked) {
        for (payload, 0..) |*byte, i| {
            byte.* ^= mask_key[i % 4];
        }
    }

    return Frame{
        .fin = fin,
        .rsv1 = rsv1,
        .rsv2 = rsv2,
        .rsv3 = rsv3,
        .opcode = opcode,
        .masked = masked,
        .payload = payload,
        .allocator = allocator,
        .owned = owned,
    };
}

/// Serialize a frame to `writer`.
/// For client->server, always sets FIN=1, MASK=1, and generates a random mask key.
pub fn serializeFrame(
    writer: std.io.AnyWriter,
    opcode: Opcode,
    payload: []const u8,
) !void {
    const b0: u8 = 0x80 | @as(u8, @intFromEnum(opcode));
    try writer.writeByte(b0);

    const len = payload.len;
    if (len < 126) {
        try writer.writeByte(0x80 | @as(u8, @intCast(len)));
    } else if (len < 65536) {
        try writer.writeByte(0x80 | 126);
        var len_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &len_bytes, @intCast(len), .big);
        try writer.writeAll(&len_bytes);
    } else {
        try writer.writeByte(0x80 | 127);
        var len_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &len_bytes, len, .big);
        try writer.writeAll(&len_bytes);
    }

    var mask_key: [4]u8 = undefined;
    std.crypto.random.bytes(&mask_key);
    try writer.writeAll(&mask_key);

    for (payload, 0..) |byte, i| {
        try writer.writeByte(byte ^ mask_key[i % 4]);
    }
}

/// Serialize a text frame (convenience wrapper).
pub fn serializeText(writer: std.io.AnyWriter, text: []const u8) !void {
    try serializeFrame(writer, .text, text);
}

/// Serialize a close frame with optional status code and reason.
/// Reason must not exceed 123 bytes so that total payload <= 125.
pub fn serializeClose(
    writer: std.io.AnyWriter,
    code: ?u16,
    reason: ?[]const u8,
) !void {
    if (code) |c| {
        var payload: [125]u8 = undefined;
        std.mem.writeInt(u16, payload[0..2], c, .big);
        if (reason) |r| {
            if (r.len > 123) return error.ReasonTooLong;
            @memcpy(payload[2..][0..r.len], r);
            try serializeFrame(writer, .close, payload[0..2 + r.len]);
        } else {
            try serializeFrame(writer, .close, payload[0..2]);
        }
    } else {
        try serializeFrame(writer, .close, &[_]u8{});
    }
}

test "serialize and parse text frame roundtrip" {
    const allocator = std.testing.allocator;

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    const text = "Hello, WebSocket!";
    try serializeText(writer, text);

    fbs.reset();
    const reader = fbs.reader().any();

    var frame_buffer: [64]u8 = undefined;
    var frame = try parseFrame(reader, allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(Opcode.text, frame.opcode);
    try std.testing.expect(frame.masked);
    try std.testing.expectEqualStrings(text, frame.payload);
    try std.testing.expect(!frame.owned);
}

test "serialize and parse large payload with allocation" {
    const allocator = std.testing.allocator;

    const payload = try allocator.alloc(u8, 300);
    defer allocator.free(payload);
    @memset(payload, 'A');

    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    try serializeFrame(writer, .binary, payload);

    fbs.reset();
    const reader = fbs.reader().any();

    var frame_buffer: [64]u8 = undefined;
    var frame = try parseFrame(reader, allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(Opcode.binary, frame.opcode);
    try std.testing.expect(frame.owned);
    try std.testing.expectEqual(@as(usize, 300), frame.payload.len);
    try std.testing.expectEqualStrings(payload, frame.payload);
}

test "masking is applied and unmasked correctly" {
    const allocator = std.testing.allocator;

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    const original = "mask test";
    try serializeText(writer, original);

    // 中間バッファの生データを確認: payload部分はマスクされていることを確認
    const written = fbs.getWritten();
    // b0 = 0x81 (FIN + text), b1 = 0x80 | len
    const payload_len = written[1] & 0x7F;
    // mask key starts at byte 2
    const mask_key = written[2..6];
    const masked_payload = written[6..][0..payload_len];
    var unmasked: [9]u8 = undefined;
    for (masked_payload, 0..) |b, i| {
        unmasked[i] = b ^ mask_key[i % 4];
    }
    try std.testing.expectEqualStrings(original, &unmasked);

    fbs.reset();
    const reader = fbs.reader().any();

    var frame_buffer: [64]u8 = undefined;
    var frame = try parseFrame(reader, allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expectEqualStrings(original, frame.payload);
}

test "serialize and parse close frame with code and reason" {
    const allocator = std.testing.allocator;

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    try serializeClose(writer, 1000, "going away");

    fbs.reset();
    const reader = fbs.reader().any();

    var frame_buffer: [64]u8 = undefined;
    var frame = try parseFrame(reader, allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(Opcode.close, frame.opcode);
    try std.testing.expectEqual(@as(usize, 12), frame.payload.len); // 2 bytes code + 10 bytes reason
    const code = std.mem.readInt(u16, frame.payload[0..2], .big);
    try std.testing.expectEqual(@as(u16, 1000), code);
    try std.testing.expectEqualStrings("going away", frame.payload[2..]);
}

test "serialize and parse close frame without code" {
    const allocator = std.testing.allocator;

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    try serializeClose(writer, null, null);

    fbs.reset();
    const reader = fbs.reader().any();

    var frame_buffer: [64]u8 = undefined;
    var frame = try parseFrame(reader, allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expectEqual(Opcode.close, frame.opcode);
    try std.testing.expectEqual(@as(usize, 0), frame.payload.len);
}

test "parse ping and return pong" {
    const allocator = std.testing.allocator;

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    const ping_data = "ping";
    try serializeFrame(writer, .ping, ping_data);

    fbs.reset();
    const reader = fbs.reader().any();

    var frame_buffer: [64]u8 = undefined;
    var frame = try parseFrame(reader, allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expectEqual(Opcode.ping, frame.opcode);
    try std.testing.expectEqualStrings(ping_data, frame.payload);
}

test "parse frame with extended payload length 16bit" {
    const allocator = std.testing.allocator;

    const payload = try allocator.alloc(u8, 200);
    defer allocator.free(payload);
    @memset(payload, 'x');

    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    try serializeFrame(writer, .text, payload);

    fbs.reset();
    const reader = fbs.reader().any();

    var frame_buffer: [100]u8 = undefined;
    var frame = try parseFrame(reader, allocator, &frame_buffer);
    defer frame.deinit();

    try std.testing.expect(frame.owned);
    try std.testing.expectEqual(@as(usize, 200), frame.payload.len);
    try std.testing.expectEqualStrings(payload, frame.payload);
}

test "serializeClose reason too long" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer().any();

    const long_reason = "a" ** 124;
    const result = serializeClose(writer, 1000, long_reason);
    try std.testing.expectError(error.ReasonTooLong, result);
}