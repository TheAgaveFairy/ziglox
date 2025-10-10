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
    right: *const Expr,
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
    left: *const Expr,
    op: Token,
    right: *const Expr,
};

pub const SetExpr = struct {
    object: *const Expr,
    name: Token,
    value: *const Expr,
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
    right: *const Expr,
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

    const PrinterError = error{ // recursive functions seem to want explicit error sets
        FormatError, // "i" messed up
        WriterError, // stdlib threw an error etc
    };

    arena: std.heap.ArenaAllocator,
    //allocator: std.mem.Allocator,
    notation: Notation,

    pub const Notation = union(enum) {
        reverse_polish,
        parenthesized_prefix,
    };

    pub fn init(notation: Notation) Self {
        //var self =
        return Self{
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            //.allocator = undefined,
            .notation = notation,
        };
        //self.allocator = self.arena.allocator();
        //return self;
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    fn printBinary(self: *Self, expr: BinaryExpr) anyerror![]const u8 {
        return try self.format(.{
            expr.op.lexeme,
            expr.left,
            expr.right,
        });
    }

    fn printGrouping(self: *Self, expr: GroupingExpr) anyerror![]const u8 {
        return try self.format(.{
            "group",
            expr.expr,
        });
    }

    fn printLiteral(self: *Self, expr: LiteralExpr) anyerror![]const u8 {
        const literal = expr.value;
        if (literal == null) return "nil"; // TODO: check this

        return switch (literal.?) {
            .number => |float| try std.fmt.allocPrint(self.arena.allocator(), "{d}", .{float}),
            .string => |str| str,
            .boolean => |b| if (b) "true" else "false",
        };
    }

    fn printUnary(self: *Self, expr: UnaryExpr) anyerror![]const u8 {
        return try self.format(.{
            expr.op.lexeme,
            expr.right,
        });
    }

    fn format(self: *Self, args: anytype) anyerror![]const u8 {
        return switch (self.notation) {
            .reverse_polish => try self.formatReversePolish(args),
            .parenthesized_prefix => try self.formatParenthesizedPrefix(args),
        };
    }

    fn formatParenthesizedPrefix(self: *Self, args: anytype) anyerror![]const u8 {
        var alloc_writer = std.Io.Writer.Allocating.init(self.arena.allocator());
        var writer = &alloc_writer.writer;

        inline for (args, 0..) |arg, idx| {
            if (idx == 0) {
                try writer.print("({s}", .{arg});
            } else {
                const temp = try self.printExpr(arg);
                try writer.print(" {s}", .{temp});
            }
        }
        try writer.print(")", .{});
        //const writer_items = std.Io.Writer.toArrayList(writer).items;
        return alloc_writer.toOwnedSlice();
    }

    fn formatReversePolish(self: *Self, args: anytype) anyerror![]const u8 {
        var alloc_writer = std.Io.Writer.Allocating.init(self.arena.allocator());
        var writer = &alloc_writer.writer;

        inline for (args, 0..) |arg, idx| {
            if (idx != 0) {
                const temp = try self.printExpr(arg);
                try writer.print("{s} ", .{temp});
            }
        }
        try writer.print("{s}", .{args[0]});
        return alloc_writer.toOwnedSlice();
    }

    pub fn printExpr(self: *Self, expr: *const Expr) anyerror![]const u8 {
        return switch (expr.*) {
            .binary => |b| self.printBinary(b),
            .grouping => |g| self.printGrouping(g),
            .literal => |l| self.printLiteral(l),
            .unary => |u| self.printUnary(u),
            else => unreachable,
        };
    }
};

test "allocating printer" {
    var alloc_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    var writer = &alloc_writer.writer;

    const args = .{ "69", 420 };

    inline for (args, 0..) |arg, idx| {
        if (idx == 0) {
            try writer.print("({s}", .{arg});
        } else {
            try writer.print(" {d}", .{arg});
        }
    }
    try writer.print(")", .{});
    const result = try alloc_writer.toOwnedSlice();
    defer std.testing.allocator.free(result);
    //std.debug.print("{s}\n", .{result});

    try std.testing.expectEqualStrings("(69 420)", result);
}

test "print grouping" {
    const testing_allocator = std.testing.allocator;
    const outside = try testing_allocator.create(Expr);
    defer testing_allocator.destroy(outside);
    const inside = try testing_allocator.create(Expr);
    defer testing_allocator.destroy(inside);

    inside.* = Expr{ .literal = LiteralExpr{
        .value = Literal{
            .number = 123,
        },
    } };

    outside.* = Expr{ .grouping = GroupingExpr{
        .expr = inside,
    } };

    var pp_printer = Printer.init(.parenthesized_prefix);
    var rpn_printer = Printer.init(.reverse_polish);

    const pp_res = try pp_printer.printGrouping(outside.grouping);
    try std.testing.expectEqualStrings("(group 123)", pp_res);
    const rpn_res = try rpn_printer.printGrouping(outside.grouping);
    try std.testing.expectEqualStrings("123 group", rpn_res);
}

test "ast printing" {
    const testing_allocator = std.testing.allocator;
    var slice: []u8 = try testing_allocator.alloc(u8, 3);
    defer testing_allocator.free(slice);
    slice[0] = 42; // *
    slice[1] = 45; // -
    slice[2] = 0; // no reason i did this

    const left_subnode = Expr{
        .literal = LiteralExpr{
            .value = Literal{
                .number = 123,
            },
        },
    };

    const left_node = Expr{
        .unary = UnaryExpr{
            .op = Token{
                .token_type = .MINUS,
                .literal = null,
                .line = 1,
                .lexeme = slice[1..2],
            },
            .right = &left_subnode,
        },
    };

    const right_subnode = Expr{ .literal = LiteralExpr{ .value = Literal{ .number = 45.67 } } };

    const right_node = Expr{ .grouping = GroupingExpr{
        .expr = &right_subnode,
    } };

    const root_node = Expr{
        .binary = BinaryExpr{
            .op = Token{
                .token_type = .STAR,
                .line = 1,
                .lexeme = slice[0..1],
                .literal = null, // test an actual value below
            },
            .left = &left_node,
            .right = &right_node,
        },
    };

    //std.debug.print("address of left node: {*}\n", .{&left_node});

    //var printer = Printer.init(.reverse_polish);
    var pp_printer = Printer.init(.parenthesized_prefix);
    defer pp_printer.deinit();
    var rpn_printer = Printer.init(.reverse_polish);
    defer rpn_printer.deinit();

    const pp_result = try pp_printer.printExpr(&root_node);
    std.debug.print("ParenthesizedPrefix\n\t>>>{s}\n", .{pp_result});
    const rpn_result = try rpn_printer.printExpr(&root_node);
    std.debug.print("ReversePolishNotation\n\t>>>{s}\n", .{rpn_result});
    try std.testing.expectEqualStrings("(* (- 123) (group 45.67))", pp_result);
}

test "print literal (simple)" { // TODO: call printExpr instead of printLiteral
    const some_number = Expr{
        .literal = LiteralExpr{
            .value = Literal{
                .number = 123,
            },
        },
    };
    const some_string = Expr{
        .literal = LiteralExpr{
            .value = Literal{
                .string = "testing",
            },
        },
    };
    const some_boolean = Expr{
        .literal = LiteralExpr{
            .value = Literal{
                .boolean = true,
            },
        },
    };

    var pp_printer = Printer.init(.parenthesized_prefix);

    const pp_number = try pp_printer.printLiteral(some_number.literal);
    try std.testing.expectEqualStrings(pp_number, "123");

    const pp_string = try pp_printer.printLiteral(some_string.literal);
    try std.testing.expectEqualStrings(pp_string, "testing");

    const pp_boolean = try pp_printer.printLiteral(some_boolean.literal);
    try std.testing.expectEqualStrings(pp_boolean, "true");

    var rpn_printer = Printer.init(.reverse_polish);

    const rpn_number = try rpn_printer.printLiteral(some_number.literal);
    try std.testing.expectEqualStrings(rpn_number, "123");

    const rpn_string = try rpn_printer.printLiteral(some_string.literal);
    try std.testing.expectEqualStrings(rpn_string, "testing");

    const rpn_boolean = try rpn_printer.printLiteral(some_boolean.literal);
    try std.testing.expectEqualStrings(rpn_boolean, "true");
}
