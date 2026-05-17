pub const Opcode = @import("frame.zig").Opcode;
pub const Frame = @import("frame.zig").Frame;
pub const parseFrame = @import("frame.zig").parseFrame;
pub const serializeFrame = @import("frame.zig").serializeFrame;
pub const serializeText = @import("frame.zig").serializeText;
pub const serializeClose = @import("frame.zig").serializeClose;

test {
    _ = @import("frame.zig");
}