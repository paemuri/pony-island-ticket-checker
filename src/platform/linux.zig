const std = @import("std");
const Io = std.Io;

const cli = @import("../cli.zig");
const report = @import("../report.zig");
const linux_native = @import("../save/linux_native.zig");
const linux_proton = @import("../save/linux_proton.zig");

pub const help =
    \\      --linux-native    Read the Linux native prefs file
    \\      --linux-proton    Read the Linux Proton user.reg file
    \\
    \\If both --linux-native and --linux-proton are given, the last one wins.
;

pub const Source = enum {
    linux_native,
    linux_proton,
};

const Mode = enum {
    auto,
    forced,
};

pub fn parseSource(arg: []const u8) ?Source {
    if (std.mem.eql(u8, arg, "--linux-native")) return .linux_native;
    if (std.mem.eql(u8, arg, "--linux-proton")) return .linux_proton;
    return null;
}

pub fn run(init: std.process.Init, stdout: *Io.Writer, source: ?Source) !void {
    if (source) |selected| {
        switch (selected) {
            .linux_native => try runNative(init, stdout, .forced),
            .linux_proton => try runProton(init, stdout, .forced),
        }
    } else {
        try runNative(init, stdout, .auto);
        try runProton(init, stdout, .auto);
    }
}

fn runNative(init: std.process.Init, stdout: *Io.Writer, mode: Mode) !void {
    const arena = init.arena.allocator();

    const prefs_path = linux_native.path(arena, init.environ_map) catch |err| {
        std.debug.print(
            "{s}: failed to locate Linux native prefs: {s}\n",
            .{ cli.name, @errorName(err) },
        );
        cli.exitWithPause(init, 1);
    };

    const set = linux_native.read(init.io, arena, prefs_path) catch |err| switch (err) {
        error.FileNotFound => switch (mode) {
            .auto => return,
            .forced => {
                std.debug.print("{s}: Linux native prefs not found: {s}\n", .{ cli.name, prefs_path });
                cli.exitWithPause(init, 1);
            },
        },
        else => {
            std.debug.print(
                "{s}: failed to read Linux native prefs ({s}): {s}\n",
                .{ cli.name, prefs_path, @errorName(err) },
            );
            cli.exitWithPause(init, 1);
        },
    };

    try report.write(stdout, .linux_native, set);
    cli.exitWithPause(init, 0);
}

fn runProton(init: std.process.Init, stdout: *Io.Writer, mode: Mode) !void {
    const arena = init.arena.allocator();

    const set = linux_proton.read(init.io, arena, init.environ_map) catch |err| switch (err) {
        error.LinuxProtonSaveNotFound => switch (mode) {
            .auto => {
                std.debug.print("{s}: no Linux save found\n", .{cli.name});
                cli.exitWithPause(init, 1);
            },
            .forced => {
                std.debug.print("{s}: Linux Proton user.reg not found\n", .{cli.name});
                cli.exitWithPause(init, 1);
            },
        },
        else => {
            std.debug.print(
                "{s}: failed to read Linux Proton user.reg: {s}\n",
                .{ cli.name, @errorName(err) },
            );
            cli.exitWithPause(init, 1);
        },
    };

    try report.write(stdout, .linux_proton, set);
    cli.exitWithPause(init, 0);
}

test "parseSource recognizes Linux flags" {
    try std.testing.expectEqual(Source.linux_native, parseSource("--linux-native").?);
    try std.testing.expectEqual(Source.linux_proton, parseSource("--linux-proton").?);
    try std.testing.expect(parseSource("--native") == null);
}
