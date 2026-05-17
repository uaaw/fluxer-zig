const std = @import("std");

/// A simple key-value header map that does not depend on std.StringHashMap's deinit signature.
pub const HeaderMap = struct {
    entries: std.ArrayList(Entry),
    allocator: std.mem.Allocator,

    pub const Entry = struct {
        name: []const u8,
        value: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) HeaderMap {
        return .{
            .entries = std.ArrayList(Entry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HeaderMap) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.name);
            self.allocator.free(entry.value);
        }
        self.entries.deinit();
    }

    pub fn put(self: *HeaderMap, name: []const u8, value: []const u8) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        try self.entries.append(.{ .name = name_copy, .value = value_copy });
    }

    pub fn get(self: HeaderMap, name: []const u8) ?[]const u8 {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) return entry.value;
        }
        return null;
    }

    pub fn iterator(self: HeaderMap) std.ArrayList(Entry).Iterator {
        return self.entries.iterator();
    }
};

test "HeaderMap put and get" {
    const allocator = std.testing.allocator;
    var map = HeaderMap.init(allocator);
    defer map.deinit();

    try map.put("Content-Type", "application/json");
    try map.put("Authorization", "Bearer token");

    try std.testing.expectEqualStrings("application/json", map.get("Content-Type").?);
    try std.testing.expectEqualStrings("Bearer token", map.get("Authorization").?);
    try std.testing.expect(map.get("Missing") == null);
}

test "HeaderMap iterator" {
    const allocator = std.testing.allocator;
    var map = HeaderMap.init(allocator);
    defer map.deinit();

    try map.put("X-Header", "value");

    var it = map.iterator();
    const entry = it.next().?;
    try std.testing.expectEqualStrings("X-Header", entry.name);
    try std.testing.expectEqualStrings("value", entry.value);
    try std.testing.expect(it.next() == null);
}

test "HeaderMap deinit frees memory" {
    const allocator = std.testing.allocator;
    var map = HeaderMap.init(allocator);
    try map.put("Name", "Value");
    map.deinit();
}
