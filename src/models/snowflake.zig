const std = @import("std");

/// Fluxer snowflake identifier.
pub const Snowflake = struct {
    value: u64,

    /// Discord epoch in milliseconds (January 1, 2015).
    pub const Epoch: u64 = 1420070400000;

    /// Creates a Snowflake from a raw u64 value.
    pub fn fromU64(id: u64) Snowflake {
        return .{ .value = id };
    }

    /// Returns the raw u64 value.
    pub fn toU64(self: Snowflake) u64 {
        return self.value;
    }

    /// Returns the timestamp component of the snowflake in milliseconds.
    pub fn timestamp(self: Snowflake) u64 {
        return (self.value >> 22) + Epoch;
    }

    /// Returns the worker ID component.
    pub fn workerId(self: Snowflake) u64 {
        return (self.value >> 17) & 0x1F;
    }

    /// Returns the process ID component.
    pub fn processId(self: Snowflake) u64 {
        return (self.value >> 12) & 0x1F;
    }

    /// Returns the increment component.
    pub fn increment(self: Snowflake) u64 {
        return self.value & 0xFFF;
    }

    /// Parses a Snowflake from a decimal string.
    pub fn parse(str: []const u8) !Snowflake {
        if (str.len == 0) return error.InvalidCharacter;
        return .{ .value = try std.fmt.parseInt(u64, str, 10) };
    }

    /// Formats the Snowflake as a decimal string.
    pub fn format(
        self: Snowflake,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}", .{self.value});
    }

    /// Returns true if two snowflakes are equal.
    pub fn eql(self: Snowflake, other: Snowflake) bool {
        return self.value == other.value;
    }

    /// Returns a hash value suitable for hash maps.
    pub fn hash(self: Snowflake) u64 {
        return self.value;
    }

    /// Parses a Snowflake from JSON (expects a string).
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Snowflake {
        const token = try source.nextAllocMax(allocator, .alloc_always, options.max_value_len orelse std.math.maxInt(u32));
        defer {
            switch (token) {
                .allocated_number, .allocated_string => |slice| allocator.free(slice),
                else => {},
            }
        }
        const slice = switch (token) {
            .string, .allocated_string => |s| s,
            else => return error.UnexpectedToken,
        };
        return try parse(slice);
    }

    /// Parses a Snowflake from an already-parsed JSON value.
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !Snowflake {
        _ = allocator;
        _ = options;
        switch (source) {
            .string => |s| return try parse(s),
            .null => return Snowflake.fromU64(0),
            else => return error.UnexpectedToken,
        }
    }

    /// Serializes the Snowflake to JSON as a string.
    pub fn jsonStringify(self: Snowflake, jw: anytype) !void {
        var buf: [32]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, "{d}", .{self.value}) catch unreachable;
        try jw.write(str);
    }
};

test "snowflake timestamp" {
    const sf = Snowflake.fromU64(175928847299117063);
    try std.testing.expectEqual(@as(u64, 1462015105796), sf.timestamp());
    try std.testing.expectEqual(@as(u64, 1), sf.workerId());
    try std.testing.expectEqual(@as(u64, 0), sf.processId());
}

test "snowflake parse and format" {
    const sf = try Snowflake.parse("175928847299117063");
    try std.testing.expectEqual(@as(u64, 175928847299117063), sf.toU64());

    var buf: [64]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{}", .{sf});
    try std.testing.expectEqualStrings("175928847299117063", s);
}

test "snowflake json" {
    const allocator = std.testing.allocator;
    const json = "\"175928847299117063\"";
    const parsed = try std.json.parseFromSlice(Snowflake, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 175928847299117063), parsed.value.toU64());

    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try std.json.stringify(parsed.value, .{}, fbs.writer());
    try std.testing.expectEqualStrings("\"175928847299117063\"", fbs.getWritten());
}