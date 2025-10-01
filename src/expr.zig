const std = @import("std");
const scanner = @import("./scanner.zig");
const Token = scanner.Token;
const Literal = scanner.Literal;

pub const AssignExpr = struct {
    name: Token,
    value: *const Expr,
};

pub const BinaryExpr = struct {
    left: *const Expr,
    op: Token,
    right: *Expr,
};

pub const CallExpr = struct {
    callee: *const Expr,
    paren: Token,
    arguments: ?std.ArrayList(*const Expr),
};

pub const GetExpr = struct {
    object: *const Expr,
    name: Token,
};

pub const GroupingExpr = struct {
    expr: *const Expr,
};

pub const LiteralExpr = struct {
    value: ?Literal,
};

pub const LogicalExpr = struct {
    left: *Expr,
    op: Token,
    right: *Expr,
};

pub const SetExpr = struct {
    object: *Expr,
    name: Token,
    value: *Expr,
};

pub const SuperExpr = struct {
    keyword: Token,
    method: Token,
};

pub const ThisExpr = struct {
    keyword: Token,
};

pub const UnaryExpr = struct {
    op: Token,
    right: *Expr,
};

pub const VariableExpr = struct {
    name: Token,
};

pub const Expr = union(enum) {
    assign: AssignExpr,
    binary: BinaryExpr,
    call: CallExpr,
    //get:
    grouping: GroupingExpr,
    literal: LiteralExpr,
    logical: LogicalExpr,
    //set,
    //super,
    //this,
    unary: UnaryExpr,
    variable: VariableExpr,
};


pub const Printer = struct { // tusharhero/zlox/blob/master/src/ast.zig more or less
    const Self = @This();

    arena: std.mem.Allocator,
    notation: Notation, // TODO: // reverse_polish or parenthesized_prefix union/union(enum)
    
    pub const Notation = union(enum) {
        reverse_polish,
        parenthesized_prefix,
    }

    pub fn init(notation: Notation) Self {
        return Self {
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            .notation = notation,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    fn printBinary(self: *Self, expr: BinaryExpr) ![]const u8 {
        return try self.format(.{
            expr.op.lexeme,
            expr.left,
            expr.right,
        });
    }

    fn printGrouping(self: *Self, expr: GroupingExpr) ![]const u8 {
        return try self.format(.{
            "group",
            expr.expr,
        });
    }

    fn printLiteral(self: *Self, expr: LiteralExpr) ![]const u8 {
        const literal = expr.value;
        if (literal == null) return "nil"; // TODO: check this

        return switch(literal.?) {
            .number => |float| try std.fmt.allocPrint(self.arena, "{d}", .{float}),
            .string => |str| str,
            .boolean => |b| if (b) "true" else "false",
        };
    }
    fn printUnary(self: *Self, expr: UnaryExpr) ![]const u8 {
        return try self.foramt(.{
            expr.op.lexeme,
            expr.right,
        });
    }

    fn format(self: *Self, args: anytype) ![]const u8 {
        return switch (self.notation) {
            .reverse_polish => self.formatReversePolish(args),
            .parenthesized_prefix => self.formatParenthesizedPrefix(args),
        };
    }

    fn formatParenthesizedPrefix(self: *Self, args: anytype) ![]const u8 {
        var alloc_writer = std.Io.Writer.Allocating.init(self.arena);
        var writer = alloc_writer.writer;

        inline for (args, 0..) |arg, idx| {
            if (idx == 0) {
                try writer.print("({s}", .{arg});
            } else {
                try writer.print(" {!s}", .self.printExpr(arg));
            }
        }
        try writer.print(")", .{});
        return writer.toArrayList().items;
        
    }

    fn formatReversePolish(self: *Self, args: anytype) ![]const u8 {
        var alloc_writer = std.Io.Writer.Allocating.init(self.arena);
        var writer = alloc_writer.writer;

        inline for (args, 0..) |arg, idx| {
            if (idx != 0) try writer.print("{!s} ", .{self.printExpr(arg)});
        }
        try writer.print("{s}", .{self.printExpr(args[0])});
        return writer.toArrayList().items;
    }

    pub fn printExpr(self: *Self, expr: *const Expr) ![]const u8 {
        return switch(expr) {
            .binary => |b| self.printBinary(b),
            .grouping => |g| self.printGrouping(g),
            .literal => |l| self.printLiteral(l),
            .unary => |u| self.printUnary(u),
        };
    }

};
