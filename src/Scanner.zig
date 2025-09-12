const std = @import("std");
const printerr = std.debug.print;

pub const Scanner = struct {
    source: []u8,
    tokens: std.ArrayList(Token),
    start: usize,
    current: usize,
    line: usize,

    pub fn init(allocator: std.mem.Allocator, source: []u8) !@This() {
        return .{
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
            .start = 0,
            .current = 0,
            .line = 1,
        };
    }

    pub fn deinit(self: *@This()) !void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *@This()) !?std.ArrayList(Token) {
        while (!self.isAtEnd()) {
            //self.start = self.current;
            self.scanToken() catch |err| {
                _ = err;
                continue;
            };
        }
        try self.tokens.append(Token(.EOF, "", self.line));
        return null;
    }

    fn scanToken(self: @This()) !void {
        const c = self.advance();
        const token: TokenType = switch (c) {
            '(' => .LEFT_PAREN,
            ')' => .RIGHT_PAREN,
            '{' => .LEFT_BRACE,
            '}' => .RIGHT_BRACE,
            ',' => .COMMA,
            '.' => .DOT,
            '-' => .MINUS,
            '+' => .PLUS,
            ';' => .SEMICOLON,
            '*' => .STAR,
            // TODO: '/' will be a special case to deal with uniquely

            '!' => if (self.match('=')) .BANG_EQUAL else .BANG,
            '=' => if (self.match('=')) .EQUAL_EQUAL else .EQUAL,
            '<' => if (self.match('=')) .LESS_EQUAL else .LESS,
            '>' => if (self.match('=')) .GREATER_EQUAL else .GREATER,

            else => {
                printerr("{s}: Unexpected character", .{self.line});
                return error.UnexpectedCharacter;
            },
        };
        try self.addToken(token);
    }

    fn isAtEnd(self: *@This()) bool {
        return (self.current >= self.source.len);
    }

    fn advance(self: *@This()) u8 {
        const char = self.source.ptr[self.current];
        self.current += 1;
        return char;
    }

    fn match(self: *@This(), expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source.ptr[self.current] != expected) return false;
        self.current += 1;
        return true;
    }

    fn addToken(self: *@This(), token_type: TokenType) !void {
        const lexeme = self.source.ptr[self.start..self.current];
        try self.tokens.append(.{ token_type, lexeme, self.line });
    }
};

pub const TokenType = enum {
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

pub const Token = struct {
    token_type: TokenType,
    lexeme: []u8,
    //literal: []u8, // TODO: not the right type for now, possibly can omit
    line: usize,

    pub fn init(token_type: TokenType, lexeme: []u8, line: usize) @This() {
        return .{ .token_type = token_type, .lexeme = lexeme, .line = line };
    }

    pub fn toString(self: *Token) []u8 {
        printerr("{s} {s} line: {d}", .{ self.token_type, self.lexeme, self.line });
    }
};
