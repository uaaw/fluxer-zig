const std = @import("std");

/// Error set for REST API operations.
pub const RestError = error{
    HttpError,
    JsonError,
    RateLimited,
    Unauthorized,
    Forbidden,
    NotFound,
    ServerError,
    UnknownError,
};

/// Represents an error response from the Fluxer API.
pub const FluxerAPIError = struct {
    code: i32,
    message: []const u8,
    errors: ?std.json.Value,

    /// Allocates memory. Caller owns returned memory.
    pub fn deinit(self: *FluxerAPIError, allocator: std.mem.Allocator) void {
        if (self.errors) |errors| {
            errors.deallocate(allocator);
        }
    }
};

/// Converts an HTTP status code to the appropriate RestError.
/// The body parameter is accepted for potential future use (e.g., parsing Discord error codes).
pub fn fromStatus(status: std.http.Status, _: ?[]const u8) RestError {
    switch (status.class()) {
        .informational, .success, .redirect => return RestError.UnknownError,
        .client_error => {
            switch (status) {
                .unauthorized => return RestError.Unauthorized,
                .forbidden => return RestError.Forbidden,
                .not_found => return RestError.NotFound,
                .too_many_requests => return RestError.RateLimited,
                else => return RestError.HttpError,
            }
        },
        .server_error => return RestError.ServerError,
    }
}

test "fromStatus maps status codes correctly" {
    try std.testing.expectEqual(RestError.Unauthorized, fromStatus(.unauthorized, null));
    try std.testing.expectEqual(RestError.Forbidden, fromStatus(.forbidden, null));
    try std.testing.expectEqual(RestError.NotFound, fromStatus(.not_found, null));
    try std.testing.expectEqual(RestError.RateLimited, fromStatus(.too_many_requests, null));
    try std.testing.expectEqual(RestError.ServerError, fromStatus(.internal_server_error, null));
    try std.testing.expectEqual(RestError.HttpError, fromStatus(.bad_request, null));
    try std.testing.expectEqual(RestError.UnknownError, fromStatus(.ok, null));
}

test "FluxerAPIError fields" {
    const err = FluxerAPIError{
        .code = 50001,
        .message = "Unauthorized",
        .errors = null,
    };
    try std.testing.expectEqual(@as(i32, 50001), err.code);
    try std.testing.expectEqualStrings("Unauthorized", err.message);
    try std.testing.expectEqual(@as(?std.json.Value, null), err.errors);
}