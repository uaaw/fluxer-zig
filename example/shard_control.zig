const std = @import("std");
const fluxer = @import("fluxer");



pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();


    var sm = try fluxer.gateway.ShardManager.init(
        allocator,
        2,
        "TOKEN",
        fluxer.gateway.Intents.guildMessages().value,
    );
    defer sm.deinit();


    try sm.startAll();
    defer sm.stopAll();


    const statuses = try sm.shardStatus();
    defer allocator.free(statuses);
    for (statuses, 0..) |status, i| {
        std.log.info("Shard {}: {}", .{ i, status });
    }
}