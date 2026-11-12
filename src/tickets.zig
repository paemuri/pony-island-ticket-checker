const std = @import("std");

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

// Only pref tags with name as /^ticket\d+_?$/, everything else should be ignored.
// Parsing raw content due to lack of regex lib.
pub fn isTicketKey(name: []const u8) bool {
    const prefix = "tickets";
    if (!std.mem.startsWith(u8, name, prefix)) return false;

    const rest = name[prefix.len..];
    var digits: usize = 0;
    while (digits < rest.len and std.ascii.isDigit(rest[digits])) : (digits += 1) {}

    if (digits == 0) return false;
    return digits == rest.len or rest[digits] == '_';
}
