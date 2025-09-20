const std = @import("std");
const printerr = std.debug.print;

const Scanner = @import("scanner.zig").Scanner;

pub fn run(allocator: std.mem.Allocator, source: []u8) !void {
    var scanner = Scanner.init(allocator, source);
    defer scanner.deinit();
    try scanner.scanTokens();

    printerr("Found tokens: ", .{});
    for (scanner.tokens.items) |*token| {
        _ = switch (token.token_type) {
            .STRING, .NUMBER, .IDENTIFIER => printerr("{s}: \"{s}\", ", .{ @tagName(token.token_type), token.lexeme }),
            //.STRING, .NUMBER, .IDENTIFIER => {
            //    token.toString();
            //    printerr(", ", .{});
            //},
            //try std.fmt.parseFloat(f64, token.lexeme);
            else => printerr("{s}, ", .{@tagName(token.token_type)}),
        };
    }
}

pub fn runPrompt(allocator: std.mem.Allocator) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    //const stdin = std.io.getStdIn().reader();
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    var stdin = &stdin_reader.interface;

    while (true) {
        try stdout.print("\n>>>", .{});
        try stdout.flush();
        //const result = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize)) orelse break;
        const result = try stdin.takeDelimiterExclusive('\n');

        printerr("got: {s}, which is {d} chars.\n", .{ result, result.len });
        run(allocator, result) catch {}; // don't want to kill REPL
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
