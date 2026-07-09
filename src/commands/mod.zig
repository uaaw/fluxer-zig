pub const default_prefix = @import("prefix.zig").default_prefix;
pub const Parsed = @import("prefix.zig").Parsed;
pub const parse = @import("prefix.zig").parse;
pub const matchCommand = @import("prefix.zig").matchCommand;

test {
    _ = @import("prefix.zig");
}
