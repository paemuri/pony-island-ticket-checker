const std = @import("std");

const max_file_size = 1024 * 1024;

pub const count = 25;
pub const unused_id = 6;

pub const Set = std.StaticBitSet(count);

pub const Missing = struct {
    ids: [count - 1]u8 = undefined,
    len: usize = 0,
};

pub fn isValid(id: u8) bool {
    return id < count and id != unused_id;
}

pub fn missing(set: Set) Missing {
    var result = Missing{};
    var id: usize = 0;

    while (id < count) : (id += 1) {
        if (id == unused_id) continue;
        if (!set.isSet(id)) {
            result.ids[result.len] = @intCast(id);
            result.len += 1;
        }
    }

    return result;
}

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
) !Set {
    const contents = try std.Io.Dir.cwd().readFileAlloc(
        io,
        file_path,
        allocator,
        .limited(max_file_size),
    );
    return parse(contents);
}

pub fn parse(contents: []const u8) Set {
    var set = Set.empty;
    var pos: usize = 0;

    // Parse the raw file content due to lack of XML lib.
    // The whole file should contain one wrapping tag (unity_prefs) and multiple
    // internal tags (pref). The latter should only contain simple values, and
    // not child tags or something more complex, so this should suffice for now.
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
        if (!isTicketKey(name)) continue;

        const id = std.fmt.parseInt(u8, value, 10) catch continue;
        if (!isValid(id)) continue;

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

// Only pref tags with name as /^ticket\d+$/, everything else should be ignored.
// Parsing raw content due to lack of regex lib.
fn isTicketKey(name: []const u8) bool {
    const prefix = "tickets";
    if (!std.mem.startsWith(u8, name, prefix)) return false;

    const rest = name[prefix.len..];
    var digits: usize = 0;
    while (digits < rest.len and std.ascii.isDigit(rest[digits])) : (digits += 1) {}

    if (digits == 0) return false;
    return digits == rest.len or rest[digits] == '_';
}
