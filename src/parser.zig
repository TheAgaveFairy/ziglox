const std = @import("std");
const printerr = std.debug.print;

const scanner = @import("./scanner.zig");
const Token = scanner.Token;
const TokenType = scanner.TokenType;
const Literal = scanner.Literal;

const expr = @import("./expr.zig");
const Expr = expr.Expr;

const lox = @import("./lox.zig");

const ParseError = error{
    ExpectedRightParen,
    ExpectedLeftParen,
    ExpectedSemicolon,
    ExpectedVariableName,
    ExpectedRightBrace,
    ExpectedLeftBrace,
    ExpectedFunctionName,
    TooManyArgs,
    EndOfFile, // TODO:
    ExpectedExpression,
}; // tushyagupta81 github

pub const Parser = struct {
    const Self = @This();

    //allocator: std.mem.Allocator, // ArenaAllocator would be good here
    arena: std.heap.ArenaAllocator,
    //to_free: std.ArrayList(*Token);
    tokens: std.ArrayList(Token),
    current: usize = 0,

    pub fn init(tokens: std.ArrayList(Token)) Self {
        return Self{
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            .tokens = tokens,
            .current = 0,
        };
    }

    pub fn deinit(self: *Self) void { // TODO: i forgor the origin of the tokens
        //self.tokens.deinit(self.arena.allocator());
        _ = self;
        return;
    }

    pub fn parse(self: *Self) !?*Expr {
        const result = self.expression() catch |err| {
            printerr("parser got an error: {any}\n", .{err});
            return null; // TODO: why are they doing this this way?
        };
        return result;
    }

    fn expression(self: *Self) (ParseError || std.mem.Allocator.Error)!*Expr {
        return self.equality();
    }

    fn equality(self: *Self) (ParseError || std.mem.Allocator.Error)!*Expr {
        var left = try self.comparison();
        var alloc = self.arena.allocator();

        while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            const op = self.previous();
            const right = try self.comparison();
            const temp_be = try alloc.create(Expr);
            temp_be.* = Expr{
                .binary = expr.BinaryExpr{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = temp_be;
        }
        return left; // TODO: fix
    }

    fn comparison(self: *Self) (ParseError || std.mem.Allocator.Error)!*Expr {
        var left = try self.term();
        var alloc = self.arena.allocator();

        while (self.match(&.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
            const op = self.previous();
            const right = try self.term();
            const be = try alloc.create(Expr);
            be.* = Expr{ .binary = .{
                .left = left,
                .op = op,
                .right = right,
            } };
            left = be;
        }
        return left;
    }

    fn term(self: *Self) (ParseError || std.mem.Allocator.Error)!*Expr {
        var left = try self.factor();
        var alloc = self.arena.allocator();

        while (self.match(&.{ .MINUS, .PLUS })) {
            const op = self.previous();
            const right = try self.factor();
            const be = try alloc.create(Expr);
            be.* = Expr{
                .binary = expr.BinaryExpr{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = be;
        }
        return left;
    }

    fn factor(self: *Self) (ParseError || std.mem.Allocator.Error)!*Expr {
        var left = try self.unary();
        var alloc = self.arena.allocator();

        while (self.match(&.{ .SLASH, .STAR })) {
            const op = self.previous();
            const right = try self.unary();
            const be = try alloc.create(Expr); // be = (b)inary (e)xpr
            be.* = Expr{
                .binary = expr.BinaryExpr{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = be;
        }
        return left;
    }

    fn unary(self: *Self) (ParseError || std.mem.Allocator.Error)!*Expr {
        var alloc = self.arena.allocator();
        if (self.match(&.{ .BANG, .MINUS })) {
            const op = self.previous();
            const right = try self.unary();
            const ue = try alloc.create(Expr);
            ue.* = Expr{ .unary = expr.UnaryExpr{
                .op = op,
                .right = right,
            } };
            return ue;
        } else if (self.match(&.{ .STAR, .SLASH, .PLUS, .GREATER, .LESS, .GREATER_EQUAL, .LESS_EQUAL, .BANG_EQUAL, .EQUAL_EQUAL })) {
            printerr("1) Expected expression after unary token.\n", .{}); // TODO: handle errors better
            try self.handleParseError(self.peek(), "1-2) Expected expression after unary token.");
            return ParseError.ExpectedExpression;
        }

        return try self.primary();
    }

    fn primary(self: *Self) (ParseError || std.mem.Allocator.Error)!*Expr {
        var alloc = self.arena.allocator();

        if (self.match(&.{.FALSE})) {
            const lit = try alloc.create(Expr);
            lit.* = Expr{ .literal = expr.LiteralExpr{ .value = Literal{
                .boolean = false,
            } } };
            return lit;
        } else if (self.match(&.{.TRUE})) {
            const lit = try alloc.create(Expr);
            lit.* = Expr{ .literal = expr.LiteralExpr{ .value = Literal{
                .boolean = true,
            } } };
            return lit;
        } else if (self.match(&.{.NIL})) {
            const lit = try alloc.create(Expr);
            lit.* = Expr{ .literal = expr.LiteralExpr{
                .value = null,
            } };
            return lit;
        } else if (self.match(&.{ .NUMBER, .STRING })) {
            const prev = self.previous();
            const lit = try alloc.create(Expr);
            lit.* = Expr{ .literal = expr.LiteralExpr{
                .value = prev.literal,
            } };
            return lit;
        } else if (self.match(&.{.LEFT_PAREN})) {
            const left = try self.expression();
            _ = try self.consume(.RIGHT_PAREN, ParseError.ExpectedRightParen);
            const group = try alloc.create(Expr);
            group.* = Expr{ .grouping = expr.GroupingExpr{
                .expr = left,
            } };
            return group;
        }
        try self.handleParseError(self.peek(), "Expected expression.");
        return ParseError.ExpectedExpression;
    }

    fn match(self: *Self, comptime token_types: []const TokenType) bool {
        // token_types sent as ".{.TOKEN_TYPE, ...}" anon array literal
        inline for (token_types) |tt| {
            if (self.check(tt)) {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    fn consume(self: *Self, token_type: TokenType, err: ParseError) ParseError!Token {
        if (self.check(token_type)) return self.advance();
        return err;
    }

    fn handleParseError(self: *Self, token: Token, message: []const u8) error{ OutOfMemory, WriteFailed }!void { // TODO: clarify role
        var allocator = self.arena.allocator();
        const temp_buf = try allocator.dupe(u8, " at end");
        const msg_buf = try allocator.dupe(u8, message);
        defer allocator.free(temp_buf);
        defer allocator.free(msg_buf);

        if (token.token_type == TokenType.EOF) {
            lox.report(token.line, temp_buf, msg_buf);
        } else {
            var alloc_writer = std.Io.Writer.Allocating.init(self.arena.allocator());
            var writer = &alloc_writer.writer;
            try writer.print(" at '", .{});
            try writer.print("{s}'", .{token.lexeme});
            const temp = alloc_writer.toOwnedSlice();
            lox.report(token.line, temp, message);
        }
    }

    fn synchronize(self: *Self) void { // TODO: confirm this signature and if it should return anything (error or null etc)
        _ = self.advance(); // consumes
        while (!self.isAtEnd()) { // go on ahead until we find the next statement
            if (self.previous().token_type == .SEMICOLON) return;

            _ = switch (self.peek().token_type) { // statement start signifiers
                .CLASS => null,
                .FUN => null,
                .VAR => null,
                .FOR => null,
                .IF => null,
                .WHILE => null,
                .PRINT => null,
                .RETURN => null,
                else => return,
            };
            _ = self.advance();
        }
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
