//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const printerr = std.debug.print;

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
    runFile(allocator, filename) catch |err| {
        return err;
    };
}

fn run(allocator: std.mem.Allocator, source: []u8) !void {
    _ = allocator;
    _ = source;
}

fn runPrompt(allocator: std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    while (true) {
        try stdout.print(">>>", .{});
        try bw.flush();
        const buffer: [1024]u8 = undefined;
        const result = try stdin.readUntilDelimiterOrEof(buffer, "\n");
        printerr("got: {s}, which is {} chars.\n", .{ result, result.len });
        run(allocator, buffer) catch |err| return err; // TODO: don't want to kill REPL tho
    }
}

fn runFile(allocator: std.mem.Allocator, filename: []u8) !void {
    printerr("Filename received: {s}\n", .{filename});
    const content: []u8 = try std.fs.cwd().readFileAlloc(allocator, filename, std.math.maxInt(usize));
    defer allocator.free(content);
    try run(allocator, content);
}

// not sure we'll keep this implementation of error reporting
fn showError(line: usize, msg: []u8) void {
    report(line, "", msg);
}

fn report(line: usize, where: []u8, msg: []u8) void {
    printerr("[line {d}] Error {s}: {s}.\n", .{ line, where, msg });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
