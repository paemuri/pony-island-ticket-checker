const std = @import("std");
const tickets = @import("../tickets.zig");

const max_file_size = 4 * 1024 * 1024;

pub fn read(
    io: std.Io,
    allocator: std.mem.Allocator,
    env: *const std.process.Environ.Map,
) !tickets.Set {
    const home = env.get("HOME") orelse return error.HomeNotSet;

    if (try readFrom(io, allocator, home, ".steam/steam/steamapps/compatdata/405640/pfx/user.reg")) |set| {
        return set;
    }

    if (env.get("XDG_DATA_HOME")) |data_home| {
        if (data_home.len != 0) {
            if (try readFrom(io, allocator, data_home, "Steam/steamapps/compatdata/405640/pfx/user.reg")) |set| {
                return set;
            }
        }
    }

    if (try readFrom(io, allocator, home, ".local/share/Steam/steamapps/compatdata/405640/pfx/user.reg")) |set| {
        return set;
    }

    if (try readFrom(
        io,
        allocator,
        home,
        ".var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/405640/pfx/user.reg",
    )) |set| {
        return set;
    }

    return error.LinuxProtonSaveNotFound;
}

fn readFrom(
    io: std.Io,
    allocator: std.mem.Allocator,
    base: []const u8,
    suffix: []const u8,
) !?tickets.Set {
    const file_path = try std.fs.path.join(allocator, &.{ base, suffix });
    const contents = std.Io.Dir.cwd().readFileAlloc(
        io,
        file_path,
        allocator,
        .limited(max_file_size),
    ) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    return parse(contents);
}

pub fn parse(contents: []const u8) tickets.Set {
    var set = tickets.Set.empty;
    var in_section = false;
    var lines = std.mem.splitScalar(u8, contents, '\n');

    // Wine's text registry. Tickets are stored as
    // /"tickets\d+_h\d+"=dword:[0-9a-f]{8}/.
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        if (trimmed[0] == '[') {
            in_section = std.mem.indexOf(u8, trimmed, "Daniel Mullins Games") != null and
                std.mem.indexOf(u8, trimmed, "Pony") != null;
            continue;
        }

        if (!in_section) continue;
        if (trimmed[0] != '"') continue;

        const quote_end = std.mem.indexOfScalarPos(u8, trimmed, 1, '"') orelse continue;
        const key = trimmed[1..quote_end];
        if (!tickets.isTicketKey(key)) continue;

        const value_start = std.mem.indexOfPos(u8, trimmed, quote_end + 1, "=dword:") orelse continue;
        const hex_start = value_start + "=dword:".len;
        if (hex_start >= trimmed.len) continue;

        const id = std.fmt.parseInt(u8, trimmed[hex_start..], 16) catch continue;
        if (!tickets.isValid(id)) continue;

        set.set(id);
    }

    return set;
}

test "parses ticket ids from Proton user.reg" {
    const contents =
        \\WINE REGISTRY Version 2
        \\
        \\[Software\Daniel Mullins Games\Pony Island] 1760000000
        \\"tickets0_h939244834"=dword:00000000
        \\"tickets1_h939244835"=dword:0000000b
        \\"tickets2_h939244832"=dword:00000014
        \\"ticketsnumberof_h3252926712"=dword:00000003
        \\
        \\[Software\Something Else] 1760000001
        \\"tickets3_h1"=dword:00000005
    ;

    const set = parse(contents);

    try std.testing.expect(set.isSet(0));
    try std.testing.expect(set.isSet(11));
    try std.testing.expect(set.isSet(20));
    try std.testing.expect(!set.isSet(5));
    try std.testing.expectEqual(@as(usize, 3), set.count());
}

test "parses PonyIsland section" {
    const contents =
        \\WINE REGISTRY Version 2
        \\
        \\[Software\Daniel Mullins Games\PonyIsland] 1760000000
        \\"tickets0_h1"=dword:00000014
        \\
        \\[Software\Something Else] 1760000001
        \\"tickets1_h2"=dword:00000005
    ;

    const set = parse(contents);

    try std.testing.expect(set.isSet(20));
    try std.testing.expect(!set.isSet(5));
    try std.testing.expectEqual(@as(usize, 1), set.count());
}

test "ignores unused and unknown ticket ids" {
    const contents =
        \\WINE REGISTRY Version 2
        \\
        \\[Software\Daniel Mullins Games\Pony Island] 1760000000
        \\"tickets0_h1"=dword:00000006
        \\"tickets1_h2"=dword:00000019
    ;

    const set = parse(contents);

    try std.testing.expect(!set.isSet(6));
    try std.testing.expect(!tickets.isValid(25));
    try std.testing.expectEqual(@as(usize, 0), set.count());
}
