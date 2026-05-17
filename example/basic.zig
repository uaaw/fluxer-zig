const std = @import("std");
const fluxer = @import("fluxer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try fluxer.Client.init(allocator, .{
        .token = "your_token_here",
    });
    defer client.deinit();

    const user = try client.getCurrentUser();
    defer user.deinit();

    std.log.info("Logged in as {s}", .{user.value.username});
}