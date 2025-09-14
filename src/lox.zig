const std = @import("std");
const printerr = std.debug.print;

const Scanner = @import("scanner.zig").Scanner;

pub fn run(allocator: std.mem.Allocator, source: []u8) !void {
    var scanner = try Scanner.init(allocator, source);
    defer scanner.deinit();
    try scanner.scanTokens();

    printerr("Found tokens: ", .{});
    for (scanner.tokens.items) |token| {
        _ = switch (token.token_type) {
            .STRING, .NUMBER, .IDENTIFIER => printerr("{s}: \"{s}\", ", .{ @tagName(token.token_type), token.lexeme }),
            //try std.fmt.parseFloat(f64, token.lexeme);
            else => printerr("{s}, ", .{@tagName(token.token_type)}),
        };
    }
}

pub fn runPrompt(allocator: std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    while (true) {
        try stdout.print(">>>", .{});
        try bw.flush();
        const buffer: [1024]u8 = undefined;
        const result = try stdin.readUntilDelimiterOrEof(buffer, "\n");
        //printerr("got: {s}, which is {d} chars.\n", .{ result, result.len });
        run(allocator, result) catch |err| {
            _ = err;
            continue;
        }; // don't want to kill REPL
    }
}

pub fn runFile(allocator: std.mem.Allocator, filename: []u8) !void {
    printerr("Filename received: {s}\n", .{filename});
    const content: []u8 = try std.fs.cwd().readFileAlloc(allocator, filename, std.math.maxInt(usize));
    defer allocator.free(content);
    try run(allocator, content);
}

// not sure we'll keep this implementation of error reporting
pub fn showError(line: usize, msg: []u8) void {
    report(line, "", msg);
}

pub fn report(line: usize, where: []u8, msg: []u8) void {
    printerr("[line {d}] Error {s}: {s}.\n", .{ line, where, msg });
}
