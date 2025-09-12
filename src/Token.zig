const std = @import("std");
const printerr = std.debug.print;

const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE, // ( ) { }
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR, // , . - + ; / *

    // One or two character tokens.
    BANG,
    BANG_EQUAL, // ! !=
    EQUAL,
    EQUAL_EQUAL, // = ==
    GREATER,
    GREATER_EQUAL, // > >=
    LESS,
    LESS_EQUAL, // < <=

    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,

    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    EOF,
};

const Token = struct {
    token_type: TokenType,
    lexeme: []u8,
    literal: []u8, // TODO: not the right type for now
    line: usize,

    pub fn init(token_type: TokenType, lexeme: []u8, literal: []u8, line: usize) @This() {
        return .{ .token_type = token_type, .lexeme = lexeme, .literal = literal, .line = line };
    }

    pub fn toString(self: *Token) []u8 {
        printerr("{s} {s} {s}", .{ self.token_type, self.lexeme, self.literal });
    }
};

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try bw.flush(); // Don't forget to flush!

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    if (argv.len < 2) {
        printerr("Usage: ./main -scriptname\n", .{});
        return error.argcError;
    }
}
