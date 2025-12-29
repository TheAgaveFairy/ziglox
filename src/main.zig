const std = @import("std");
const printerr = std.debug.print;

const scanner = @import("scanner.zig");
const lox = @import("lox.zig");

const Scanner = scanner.Scanner;
const TokenType = scanner.TokenType;

// just for testing support
const expr = @import("expr.zig");

const parser = @import("parser.zig");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try stdout.flush(); // Don't forget to flush!

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
    lox.runPrompt(allocator) catch |err| switch (err) {
        error.EndOfStream => {
            printerr("Thanks for using this!\n", .{});
        },
        else => return err,
    };
}

fn testRun(allocator: std.mem.Allocator, source: []const u8, expected: []const TokenType) !void {
    const buffer = try allocator.dupe(u8, source);
    defer allocator.free(buffer);

    var scan = Scanner.init(allocator, buffer);
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

test "test parser" {
    var allocator = std.testing.allocator;
    // WE DONT HAVE STATEMENTS YET, etc
    //const source =
    //    \\var min = 2;
    //    \\var max = 3;
    //    \\var average = (min + max) / 2;
    //    \\print "thing here";
    //;
    const source = 
        //\\2 + 3;
        //\\!true;
        \\(3 + 2) / 5 + 7;
    ;
    const buffer = try allocator.dupe(u8, source);
    defer allocator.free(buffer);

    var scan = Scanner.init(allocator, buffer);
    defer scan.deinit();

    try scan.scanTokens();

    //printerr("\n\n\n", .{});
    //for (scan.tokens.items) |*token| {
    //    token.toString();
    //}

    var p = parser.Parser.init(scan.tokens);
    const root_expr = p.parse() catch |err| {
        printerr("Error parsing test source. Failing. {t}.\n", .{err});
        try std.testing.expect(false);
    }; // returns optional result

    var printer = expr.Printer.init(.parenthesized_prefix);
    if (root_expr) |root| {
        const ast_string = try printer.printExpr(root);
        printerr("{s}\n", .{ast_string});
    } else {
        printerr("Error parsing test source. Failing.\n", .{});
        try std.testing.expect(false);
    }

    try std.testing.expect(true);
}

// always last
test "others" {
    _ = expr;
    std.testing.refAllDecls(@This());
}
