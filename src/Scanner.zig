const std = @import("std");
const printerr = std.debug.print;
const ascii = std.ascii;

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

    pub fn deinit(self: *@This()) void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *@This()) !void {
        while (!self.isAtEnd()) {
            self.start = self.current;
            self.scanToken() catch |err| {
                printerr("Error scanning tokens: {}\n", .{err});
                continue;
            };
        }
        try self.tokens.append(Token.init(.EOF, "", self.line));
    }

    fn scanToken(self: *@This()) !void {
        const c = self.advance(); // consumes
        const token: ?TokenType = switch (c) {
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
            // TODO: '/' will be a special case to deal with uniquely b/c comments

            '!' => if (self.match('=')) .BANG_EQUAL else .BANG,
            '=' => if (self.match('=')) .EQUAL_EQUAL else .EQUAL,
            '<' => if (self.match('=')) .LESS_EQUAL else .LESS,
            '>' => if (self.match('=')) .GREATER_EQUAL else .GREATER,

            // comments
            '/' => blk: {
                if (self.match('/')) { // we've found a comment to ignore
                    while (self.peek(0) != '\n' and !self.isAtEnd()) {
                        _ = self.advance(); // just ignore it all
                    }
                    break :blk null;
                } else {
                    break :blk .SLASH;
                }
            },

            // whitespace
            ' ', '\t', '\r' => null,
            '\n' => blk: {
                self.line += 1;
                break :blk null;
            },

            // default
            else => {
                printerr("{d}: Unexpected character", .{self.line});
                //break :blk null;
                return error.UnexpectedCharacter;
            },
        };
        if (token) |t| try self.addToken(t);
    }

    fn isAtEnd(self: *@This()) bool {
        return (self.current >= self.source.len);
    }

    fn advance(self: *@This()) u8 {
        const char = self.source.ptr[self.current];
        self.current += 1;
        return char;
    }

    fn peek(self: *@This(), offset: usize) u8 {
        if (self.isAtEnd()) return 0;
        return self.source.ptr[self.current + offset];
    }

    /// a variation on peek
    fn match(self: *@This(), expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source.ptr[self.current] != expected) return false;
        self.current += 1;
        return true;
    }

    fn addToken(self: *@This(), token_type: TokenType) !void {
        const lexeme = self.source.ptr[self.start..self.current];
        const token = Token.init(token_type, lexeme, self.line);
        try self.tokens.append(token);
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
        printerr("{s} {s} line: {d}", .{ @tagName(self.token_type), self.lexeme, self.line });
    }
};
