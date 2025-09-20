const std = @import("std");
const scanner = @import("./scanner.zig");
const Token = scanner.Token;

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
    value: []u8,
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
