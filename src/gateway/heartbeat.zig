const std = @import("std");

/// Default heartbeat interval in milliseconds.
/// Fluxer uses 41250 ms; Discord uses 45000 ms.
pub const default_interval_ms: u64 = 41250;

/// Heartbeat timeout in milliseconds (fluxer spec).
pub const timeout_ms: u64 = 45000;

/// Heartbeat state tracking.
pub const Heartbeat = struct {
    interval_ms: u64,
    last_sent_ms: ?i64,
    last_ack_ms: ?i64,

    pub fn init(interval_ms: u64) Heartbeat {
        return .{
            .interval_ms = interval_ms,
            .last_sent_ms = null,
            .last_ack_ms = null,
        };
    }

    /// Returns true if a heartbeat should be sent now.
    pub fn shouldSend(self: Heartbeat, now_ms: i64) bool {
        const last = self.last_sent_ms orelse return true;
        return @as(u64, @intCast(now_ms - last)) >= self.interval_ms;
    }

    /// Returns true if the heartbeat ack has timed out.
    pub fn isTimedOut(self: Heartbeat, now_ms: i64) bool {
        const last = self.last_ack_ms orelse return false;
        return @as(u64, @intCast(now_ms - last)) > timeout_ms;
    }

    pub fn markSent(self: *Heartbeat, now_ms: i64) void {
        self.last_sent_ms = now_ms;
    }

    pub fn markAck(self: *Heartbeat, now_ms: i64) void {
        self.last_ack_ms = now_ms;
    }
};

test "default interval is 41250ms" {
    try std.testing.expectEqual(@as(u64, 41250), default_interval_ms);
}

test "timeout is 45000ms" {
    try std.testing.expectEqual(@as(u64, 45000), timeout_ms);
}

test "heartbeat should send immediately" {
    var hb = Heartbeat.init(41250);
    try std.testing.expect(hb.shouldSend(0));
}

test "heartbeat should send after interval" {
    var hb = Heartbeat.init(41250);
    hb.markSent(0);
    try std.testing.expect(!hb.shouldSend(41249));
    try std.testing.expect(hb.shouldSend(41250));
    try std.testing.expect(hb.shouldSend(50000));
}

test "heartbeat timeout detection" {
    var hb = Heartbeat.init(41250);
    // No ack yet -> not timed out
    try std.testing.expect(!hb.isTimedOut(99999));

    hb.markAck(0);
    try std.testing.expect(!hb.isTimedOut(44999));
    try std.testing.expect(hb.isTimedOut(45001));
}