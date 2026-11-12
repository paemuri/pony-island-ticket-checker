const std = @import("std");
const tickets = @import("../tickets.zig");

const max_file_size = 1024 * 1024;

pub fn path(
    allocator: std.mem.Allocator,
    env: *const std.process.Environ.Map,
) ![]const u8 {
    const base = if (env.get("XDG_CONFIG_HOME")) |xdg| blk: {
        if (xdg.len == 0) break :blk try homeConfig(allocator, env);
        break :blk xdg;
    } else try homeConfig(allocator, env);

    return std.fs.path.join(allocator, &.{
        base,
        "unity3d",
        "Daniel Mullins Games",
        "Pony Island",
        "prefs",
    });
}

fn homeConfig(
    allocator: std.mem.Allocator,
    env: *const std.process.Environ.Map,
) ![]const u8 {
    const home = env.get("HOME") orelse return error.HomeNotSet;
    return std.fs.path.join(allocator, &.{ home, ".config" });
}

pub fn read(
    io: std.Io,
    allocator: std.mem.Allocator,
    file_path: []const u8,
) !tickets.Set {
    const contents = try std.Io.Dir.cwd().readFileAlloc(
        io,
        file_path,
        allocator,
        .limited(max_file_size),
    );
    return parse(contents);
}

pub fn parse(contents: []const u8) tickets.Set {
    var set = tickets.Set.empty;
    var pos: usize = 0;

    // Manage the raw file content due to lack of XML lib.
    // The whole file should contain one wrapping tag (unity_prefs) and multiple
    // internal tags (pref). The latter should only contain simple values, and
    // not children tags or something more complex, so this should suffice for
    // now.
    while (std.mem.indexOfPos(u8, contents, pos, "<pref ")) |start| {
        const tag_end = std.mem.indexOfPos(u8, contents, start, "</pref>") orelse break;
        pos = tag_end + "</pref>".len;

        const body = contents[start + "<pref ".len .. tag_end];
        const gt = std.mem.indexOfScalar(u8, body, '>') orelse continue;

        const attrs = body[0..gt];
        const value = std.mem.trim(u8, body[gt + 1 ..], " \t\r\n");

        const name = attr(attrs, "name") orelse continue;
        const kind = attr(attrs, "type") orelse continue;
        if (!std.mem.eql(u8, kind, "int")) continue;
        if (!tickets.isTicketKey(name)) continue;

        const id = std.fmt.parseInt(u8, value, 10) catch continue;
        if (!tickets.isValid(id)) continue;

        set.set(id);
    }

    return set;
}

fn attr(attrs: []const u8, comptime name: []const u8) ?[]const u8 {
    const needle = name ++ "=\"";
    const index = std.mem.indexOf(u8, attrs, needle) orelse return null;
    const start = index + needle.len;
    const end = std.mem.indexOfScalarPos(u8, attrs, start, '"') orelse return null;
    return attrs[start..end];
}

test "parses ticket ids from native prefs" {
    const contents =
        \\<unity_prefs version_major="1" version_minor="1">
        \\  <pref name="tickets0" type="int">0</pref>
        \\  <pref name="tickets1" type="int">11</pref>
        \\  <pref name="tickets2_h939244832" type="int">20</pref>
        \\  <pref name="ticketsnumberof" type="int">3</pref>
        \\  <pref name="Screenmanager Resolution Width" type="int">1920</pref>
        \\</unity_prefs>
    ;

    const set = parse(contents);

    try std.testing.expect(set.isSet(0));
    try std.testing.expect(set.isSet(11));
    try std.testing.expect(set.isSet(20));
    try std.testing.expectEqual(@as(usize, 3), set.count());
}

test "ignores unused and unknown ticket ids" {
    const contents =
        \\<unity_prefs version_major="1" version_minor="1">
        \\  <pref name="tickets0" type="int">6</pref>
        \\  <pref name="tickets1" type="int">25</pref>
        \\  <pref name="tickets2" type="int">5</pref>
        \\</unity_prefs>
    ;

    const set = parse(contents);

    try std.testing.expect(!set.isSet(6));
    try std.testing.expect(!tickets.isValid(25));
    try std.testing.expect(set.isSet(5));
    try std.testing.expectEqual(@as(usize, 1), set.count());
}
