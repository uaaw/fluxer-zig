const std = @import("std");

/// Default message-command prefix.
pub const default_prefix = "!";

/// Result of parsing a prefix command from message content.
///
/// Slices borrow from the input `content` passed to `parse`; they are not allocated.
/// `command` preserves the case as written after the prefix. Use `matchCommand` for
/// case-insensitive name comparison.
pub const Parsed = struct {
    command: []const u8,
    args: []const u8,
};

/// Parses `content` as `{prefix}{command}[ {args...}]`.
///
/// Returns null when:
/// - `prefix` is empty
/// - `content` does not start with `prefix`
/// - no non-whitespace command name follows the prefix (incomplete, e.g. `"!"` or `"! "`)
///
/// The command name is the first whitespace-delimited token after the prefix.
/// Leading whitespace on the remainder is stripped into `args` (may be empty).
/// Case of the command name is preserved; matching should use `matchCommand`.
pub fn parse(content: []const u8, prefix: []const u8) ?Parsed {
    if (prefix.len == 0) return null;
    if (!std.mem.startsWith(u8, content, prefix)) return null;

    const after_prefix = content[prefix.len..];
    if (after_prefix.len == 0) return null;

    var end: usize = 0;
    while (end < after_prefix.len) : (end += 1) {
        if (std.ascii.isWhitespace(after_prefix[end])) break;
    }
    if (end == 0) return null;

    const command = after_prefix[0..end];
    const args = std.mem.trimLeft(u8, after_prefix[end..], " \t\r\n");
    return .{ .command = command, .args = args };
}

/// Returns true if `parsed.command` equals `name` case-insensitively (ASCII).
pub fn matchCommand(parsed: Parsed, name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(parsed.command, name);
}

test "parse !ping yields command ping and empty args" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const parsed = parse("!ping", default_prefix) orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("ping", parsed.command);
    try std.testing.expectEqualStrings("", parsed.args);
}

test "parse !ping foo bar yields args" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const parsed = parse("!ping foo bar", default_prefix) orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("ping", parsed.command);
    try std.testing.expectEqualStrings("foo bar", parsed.args);
}

test "parse without prefix returns null" {
    const allocator = std.testing.allocator;
    _ = allocator;

    try std.testing.expect(parse("ping", default_prefix) == null);
}

test "matchCommand is case-insensitive" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const parsed = parse("!PING", default_prefix) orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("PING", parsed.command);
    try std.testing.expect(matchCommand(parsed, "ping"));
    try std.testing.expect(matchCommand(parsed, "PING"));
    try std.testing.expect(!matchCommand(parsed, "pong"));
}

test "parse ignores incomplete prefix-only input" {
    const allocator = std.testing.allocator;
    _ = allocator;

    try std.testing.expect(parse("!", default_prefix) == null);
    try std.testing.expect(parse("! ", default_prefix) == null);
    try std.testing.expect(parse("!\t", default_prefix) == null);
    try std.testing.expect(parse("", default_prefix) == null);
}

test "parse supports custom prefix and trims leading args whitespace" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const parsed = parse("?help   more  detail", "?") orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("help", parsed.command);
    try std.testing.expectEqualStrings("more  detail", parsed.args);
    try std.testing.expect(matchCommand(parsed, "HELP"));
}

test "parse rejects empty prefix" {
    const allocator = std.testing.allocator;
    _ = allocator;

    try std.testing.expect(parse("!ping", "") == null);
}
