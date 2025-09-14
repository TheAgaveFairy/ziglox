//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const printerr = std.debug.print;

const scanner = @import("scanner.zig");
const Scanner = scanner.Scanner;
const TokenType = scanner.TokenType;
const lox = @import("lox.zig");

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
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
    const filename = argv.ptr[1];
    lox.runFile(allocator, filename) catch |err| {
        return err;
    };
}

fn testRun(allocator: std.mem.Allocator, source: []const u8, expected: []const TokenType) !void {
    const buffer = try allocator.dupe(u8, source);
    defer allocator.free(buffer);

    var scan = try Scanner.init(allocator, buffer);
    defer scan.deinit();
    try scan.scanTokens();

    for (scan.tokens.items, 0..) |token, i| {
        try std.testing.expectEqual(expected[i], token.token_type);
    }
}

test "some tokens" {
    const source = "(){};";
    const expected = [_]TokenType{ .LEFT_PAREN, .RIGHT_PAREN, .LEFT_BRACE, .RIGHT_BRACE, .SEMICOLON, .EOF };
    try testRun(std.testing.allocator, source, &expected);
}
