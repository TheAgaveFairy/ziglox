const std = @import("std");
const Token = @import("Token.zig");
const printerr = std.debug.print;

pub const Scanner = struct {
    source: []u8,
    tokens: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator, source: []u8, tokens: std.ArrayList(Token)) @This {
        return .{.source = source, .tokens = tokens};
    }
};
