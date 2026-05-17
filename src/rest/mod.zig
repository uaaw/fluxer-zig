pub const errors = @import("errors.zig");
pub const response = @import("response.zig");
pub const request_builder = @import("request_builder.zig");
pub const bucket = @import("bucket.zig");
pub const rate_limiter = @import("rate_limiter.zig");
pub const client = @import("client.zig");

pub const RestError = errors.RestError;
pub const FluxerAPIError = errors.FluxerAPIError;
pub const fromStatus = errors.fromStatus;

pub const Response = response.Response;

pub const RequestBuilder = request_builder.RequestBuilder;

pub const Bucket = bucket.Bucket;
pub const BucketState = bucket.BucketState;

pub const RateLimiter = rate_limiter.RateLimiter;

pub const HttpClient = client.HttpClient;
pub const RequestOptions = client.RequestOptions;
pub const AuthType = client.AuthType;

test {
    _ = @import("errors.zig");
    _ = @import("response.zig");
    _ = @import("request_builder.zig");
    _ = @import("bucket.zig");
    _ = @import("rate_limiter.zig");
    _ = @import("client.zig");
}