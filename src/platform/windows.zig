const std = @import("std");
const Io = std.Io;

const cli = @import("../cli.zig");
const report = @import("../report.zig");
const windows = @import("../save/windows.zig");

pub const help = "";

pub const Source = enum {};

pub fn parseSource(_: []const u8) ?Source {
    return null;
}

pub fn run(init: std.process.Init, stdout: *Io.Writer, _: ?Source) !void {
    const set = windows.read() catch |err| switch (err) {
        error.WindowsKeyNotFound => {
            std.debug.print("{s}: Windows registry key not found\n", .{cli.name});
            cli.exitWithPause(init, 1);
        },
        else => {
            std.debug.print(
                "{s}: failed to read Windows registry: {s}\n",
                .{ cli.name, @errorName(err) },
            );
            cli.exitWithPause(init, 1);
        },
    };

    try report.write(stdout, .windows, set);
    cli.exitWithPause(init, 0);
}
