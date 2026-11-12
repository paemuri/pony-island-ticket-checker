const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;

const cli = @import("cli.zig");
const platform = switch (builtin.os.tag) {
    .linux => @import("platform/linux.zig"),
    .windows => @import("platform/windows.zig"),
    else => @compileError("unsupported operating system"),
};

const common_help =
    \\Check which Pony Island tickets are missing.
    \\
    \\Usage: pony-island-ticket-checker [OPTION]
    \\
    \\Options:
    \\  -h, --help            Print this help and exit
    \\  -v, --version         Print the version and exit
    \\
;

const help = common_help ++ platform.help;

const Config = struct {
    source: ?platform.Source = null,
};

pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        std.debug.print("{s}: {s}\n", .{ cli.name, @errorName(err) });
        cli.exitWithPause(init, 1);
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

    try platform.run(init, stdout, config.source);
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

        if (platform.parseSource(arg)) |source| {
            config.source = source;
        } else {
            usageError(init, "unknown argument: {s}", .{arg});
        }
    }

    return config;
}

fn printHelp(init: std.process.Init, stdout: *Io.Writer) noreturn {
    stdout.writeAll(help) catch {};
    stdout.writeAll("\n") catch {};
    stdout.flush() catch {};
    cli.exitWithPause(init, 0);
}

fn printVersion(init: std.process.Init, stdout: *Io.Writer) noreturn {
    stdout.print("{s} {s}\n", .{ cli.name, cli.version }) catch {};
    stdout.flush() catch {};
    cli.exitWithPause(init, 0);
}

fn usageError(
    init: std.process.Init,
    comptime fmt: []const u8,
    args: anytype,
) noreturn {
    std.debug.print(
        "{s}: " ++ fmt ++ "\nRun `" ++ cli.name ++ " --help` for usage.\n",
        .{cli.name} ++ args,
    );
    cli.exitWithPause(init, 2);
}
