const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;

pub const name = "pony-island-ticket-checker";
pub const version = "0.0.1";

pub fn exitWithPause(init: std.process.Init, code: u8) noreturn {
    if (builtin.os.tag == .windows) {
        std.debug.print("\nPress Enter to exit...\n", .{});
        var stdin_buffer: [256]u8 = undefined;
        var stdin_reader = Io.File.stdin().reader(init.io, &stdin_buffer);
        _ = stdin_reader.interface.takeDelimiter('\n') catch {};
    }
    std.process.exit(code);
}
