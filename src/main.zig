const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;

const tickets = @import("tickets.zig");
const report = @import("report.zig");
const linux_native = @import("save/linux_native.zig");
const linux_proton = @import("save/linux_proton.zig");

const name = "pony-island-ticket-checker";
const version = "0.0.1";

const help =
    \\Check which Pony Island tickets are missing.
    \\
    \\Usage: pony-island-ticket-checker [OPTION]
    \\
    \\Options:
    \\  -h, --help            Print this help and exit
    \\  -v, --version         Print the version and exit
    \\      --linux-native    Read the Linux native prefs file
    \\      --linux-proton    Read the Linux Proton user.reg file
;

const Config = struct {
    linux_native: bool = false,
    linux_proton: bool = false,
};

pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        std.debug.print("{s}: {s}\n", .{ name, @errorName(err) });
        exitWithPause(init, 1);
    };
}

fn run(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    const args = try init.minimal.args.toSlice(arena);
    const config = parseArgs(args, init, stdout);

    if (builtin.os.tag == .windows) {
        // TODO Implement it!
        try stdout.print("0 missing tickets.\n", .{});
        try stdout.flush();
        exitWithPause(init, 0);
    }

    if (config.linux_proton) {
        const set = linux_proton.read(io, arena, init.environ_map) catch |err| switch (err) {
            error.LinuxProtonSaveNotFound => {
                std.debug.print("{s}: Linux Proton user.reg not found\n", .{name});
                exitWithPause(init, 1);
            },
            else => {
                std.debug.print(
                    "{s}: failed to read Linux Proton user.reg: {s}\n",
                    .{ name, @errorName(err) },
                );
                exitWithPause(init, 1);
            },
        };

        try writeReport(init, stdout, .linux_proton, set);
    }

    const prefs_path = linux_native.path(arena, init.environ_map) catch |err| {
        std.debug.print(
            "{s}: failed to locate Linux native prefs: {s}\n",
            .{ name, @errorName(err) },
        );
        exitWithPause(init, 1);
    };

    const set = linux_native.read(io, arena, prefs_path) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("{s}: Linux native prefs not found: {s}\n", .{ name, prefs_path });
            exitWithPause(init, 1);
        },
        else => {
            std.debug.print(
                "{s}: failed to read Linux native prefs ({s}): {s}\n",
                .{ name, prefs_path, @errorName(err) },
            );
            exitWithPause(init, 1);
        },
    };

    try writeReport(init, stdout, .linux_native, set);
}

fn writeReport(
    init: std.process.Init,
    stdout: *Io.Writer,
    source: report.Source,
    set: tickets.Set,
) !void {
    const result = tickets.missing(set);
    try report.write(stdout, source, result.ids[0..result.len]);
    try stdout.flush();
    exitWithPause(init, 0);
}

fn parseArgs(
    args: []const [:0]const u8,
    init: std.process.Init,
    stdout: *Io.Writer,
) Config {
    var config = Config{};
    var i: usize = 1;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or
            std.mem.eql(u8, arg, "--help") or
            std.mem.eql(u8, arg, "help"))
        {
            printHelp(init, stdout);
        }

        if (std.mem.eql(u8, arg, "-v") or
            std.mem.eql(u8, arg, "--version") or
            std.mem.eql(u8, arg, "version"))
        {
            printVersion(init, stdout);
        }

        if (std.mem.eql(u8, arg, "--linux-native")) {
            if (builtin.os.tag == .windows) {
                usageError(init, "unknown argument: {s}", .{arg});
            }
            config.linux_native = true;
        } else if (std.mem.eql(u8, arg, "--linux-proton")) {
            if (builtin.os.tag == .windows) {
                usageError(init, "unknown argument: {s}", .{arg});
            }
            config.linux_proton = true;
        } else {
            usageError(init, "unknown argument: {s}", .{arg});
        }
    }

    if (config.linux_native and config.linux_proton) {
        usageError(init, "--linux-native and --linux-proton cannot be used together", .{});
    }

    return config;
}

fn printHelp(init: std.process.Init, stdout: *Io.Writer) noreturn {
    stdout.writeAll(help) catch {};
    stdout.writeAll("\n") catch {};
    stdout.flush() catch {};
    exitWithPause(init, 0);
}

fn printVersion(init: std.process.Init, stdout: *Io.Writer) noreturn {
    stdout.print("{s} {s}\n", .{ name, version }) catch {};
    stdout.flush() catch {};
    exitWithPause(init, 0);
}

fn usageError(
    init: std.process.Init,
    comptime fmt: []const u8,
    args: anytype,
) noreturn {
    std.debug.print(
        "{s}: " ++ fmt ++ "\nRun `" ++ name ++ " --help` for usage.\n",
        .{name} ++ args,
    );
    exitWithPause(init, 2);
}

fn exitWithPause(init: std.process.Init, code: u8) noreturn {
    if (builtin.os.tag == .windows) {
        std.debug.print("\nPress Enter to exit...\n", .{});
        var stdin_buffer: [256]u8 = undefined;
        var stdin_reader = Io.File.stdin().reader(init.io, &stdin_buffer);
        _ = stdin_reader.interface.takeDelimiter('\n') catch {};
    }
    std.process.exit(code);
}
