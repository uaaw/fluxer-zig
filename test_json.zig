const std = @import("std");

test "optional array json serialization" {
    const body = struct {
        shard: ?[2]u16 = null,
    }{
        .shard = .{ 0, 1 },
    };
    
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try std.json.stringify(body, .{}, buf.writer());
    
    std.debug.print("JSON output: {s}\n", .{buf.items});
    try std.testing.expectEqualStrings("{\"shard\":[0,1]}", buf.items);
}
