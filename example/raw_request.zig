const std = @import("std");
const fluxer = @import("fluxer");



pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();


    var client = try fluxer.Client.init(allocator, .{
        .token = "YOUR_TOKEN",
    });
    defer client.deinit();


    var response = try client.request(.GET, "/users/@me", .{});
    defer response.deinit();

    std.log.info("Status: {}", .{response.status});
    std.log.info("Body: {s}", .{response.body});
}