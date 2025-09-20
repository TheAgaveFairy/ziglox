const std = @import("std");

const scanner = @import("./scanner.zig");
const Token = scanner.Token;
const TokenType = scanner.TokenType;
const Literal = scanner.Literal;

const expr = @import("./expr.zig");
const Expr = expr.Expr;

const ParseError = error {
    ExpectedRightParen,
    ExpectedLeftParen,
    ExpectedSemicolon,
    ExpectedVariableName,
    ExpectedRightBrace,
    ExpectedLeftBrace,
    ExpectedFunctionName,
    TooManyArgs,
}; // tushyagupta81 github

pub const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator, // ArenaAllocator would be good here
    //to_free: std.ArrayList(*Token);
    tokens: std.ArrayList(Token),
    current: usize = 0,

    fn expression(self: *Self) ParseError!*Expr {
        return self.equality();
    }

    fn equality(self: *Self) ParseError!*Expr {
        var expr: Expr = try self.comparison();

        while(self.match(.BANG_EQUAL) or self.match(.EQUAL_EQUAL)) {
            const op = self.previous();
            const right = try self.comparison();
            //expr = Expr.b // TODO: 
        }
        return expr; // TODO: fix
    }

    fn comparison(self: *Self) ParseError!*Expr {
        var left = try self.term();

        while(self.match(.{.GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL})) {
            const op = self.previous();
            const right = self.term();
            const be = try self.allocator.create(Expr);
            be.* = Expr {
                .binary = .{
                    .left = left,
                    .op = op,
                    .right = right,
                }
            };
            left = be;
        }
        return left;
    }
    
    fn term(self: *Self) ParseError!*Expr {
        var left = try self.factor();
        while (self.match(.{.MINUS, .PLUS})) {
            const op = self.previous();
            const right = self.factor();
            const be = try self.allocator.create(Expr);
            be.* = Expr {
                .binary = {
                    .left = left,
                    .op = op,
                    .right = right,
                };
            };
            left = be;
        }
        return left;
    }

    fn match(self: *Self, token_types: []const TokenType) bool {
        // token_types sent as ".{.TOKEN_TYPE, ...}" anon array literal
        inline for (token_types) |tt| {
            if (self.check(tt)) {
                _ = self.advance;
                return true;
            }
        }
        return false;
    }
    
    fn check(self: *Self, tt: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().token_type == tt;
    }

    fn isAtEnd(self: *Self) bool {
        return self.peek().token_type == .EOF;
    }

    fn peek(self: *Self) Token {
        return self.tokens.items[self.current];
    }
    
    fn previous(self: *Self) Token {
        return self.tokens.items[self.current - 1];
    }

    fn advance(self: *Self) Token { // "consumes"
        if (!self.isAtEnd()) self.current += 1;
        return self.previous();
    }
};
