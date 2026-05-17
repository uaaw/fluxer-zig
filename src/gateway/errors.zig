const std = @import("std");

/// Error set for Gateway operations.
pub const GatewayError = error{
    ConnectionClosed,
    GatewayProtocolError,
    InvalidSession,
    UnknownEvent,
    MaxReconnectAttemptsExceeded,
    InvalidWebSocketAccept,
    MissingWebSocketAccept,
    InvalidOpcode,
};

/// Represents a gateway close code.
pub const CloseCode = enum(u16) {
    normal = 1000,
    going_away = 1001,
    protocol_error = 1002,
    unsupported_data = 1003,
    no_status_received = 1005,
    abnormal_closure = 1006,
    invalid_frame_payload = 1007,
    policy_violation = 1008,
    message_too_big = 1009,
    mandatory_extension = 1010,
    internal_server_error = 1011,
    service_restart = 1012,
    try_again_later = 1013,
    bad_gateway = 1014,
    tls_handshake = 1015,
    // Fluxer-specific close codes
    authentication_failed = 4004,
    already_authenticated = 4005,
    invalid_seq = 4007,
    rate_limited = 4008,
    session_timed_out = 4009,
    invalid_shard = 4010,
    sharding_required = 4011,
    invalid_api_version = 4012,
    invalid_intents = 4013,
    disallowed_intents = 4014,
};

test "GatewayError error set" {
    const err: GatewayError = error.ConnectionClosed;
    try std.testing.expect(err == error.ConnectionClosed);
}

test "CloseCode enum values" {
    try std.testing.expectEqual(@as(u16, 1000), @intFromEnum(CloseCode.normal));
    try std.testing.expectEqual(@as(u16, 4004), @intFromEnum(CloseCode.authentication_failed));
}