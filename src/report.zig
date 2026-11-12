const std = @import("std");
const tickets = @import("tickets.zig");

pub const Source = enum {
    linux_native,
    linux_proton,
    windows,
};

pub fn write(writer: *std.Io.Writer, source: Source, set: tickets.Set) !void {
    const missing = tickets.missing(set);

    try writer.print("{d} missing ticket(s).", .{missing.len});

    if (missing.len != 0) {
        try writer.writeAll(" Ticket ID(s):\n");
        for (missing.ids[0..missing.len]) |id| {
            try writer.print("- {d}\n", .{id});
        }
        try writer.writeAll(
            \\
            \\Check the following pages for more info on how to get the tickets:
            \\- https://paemuri.com/projects/pony-island-ticket-checker
            \\- https://steamcommunity.com/sharedfiles/filedetails?id=3837647268#9484876
        );
    }

    try writer.print("\n\nSource: {s}.\n", .{sourceLabel(source)});
    try writer.flush();
}

fn sourceLabel(source: Source) []const u8 {
    return switch (source) {
        .linux_native => "Linux native prefs",
        .linux_proton => "Linux Proton user.reg",
        .windows => "Windows registry",
    };
}

fn fullSet() tickets.Set {
    var set = tickets.Set.empty;
    for (0..tickets.count) |id| {
        if (id != tickets.unused_id) set.set(id);
    }
    return set;
}

fn expectReport(source: Source, set: tickets.Set, expected: []const u8) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try write(&writer, source, set);

    try std.testing.expectEqualStrings(expected, writer.buffered());
}

test "two missing tickets" {
    var set = fullSet();
    set.unset(11);
    set.unset(20);

    try expectReport(.linux_native, set,
        \\2 missing ticket(s). Ticket ID(s):
        \\- 11
        \\- 20
        \\
        \\Check the following pages for more info on how to get the tickets:
        \\- https://paemuri.com/projects/pony-island-ticket-checker
        \\- https://steamcommunity.com/sharedfiles/filedetails?id=3837647268#9484876
        \\
        \\Source: Linux native prefs.
        \\
    );
}

test "one missing ticket" {
    var set = fullSet();
    set.unset(11);

    try expectReport(.linux_native, set,
        \\1 missing ticket(s). Ticket ID(s):
        \\- 11
        \\
        \\Check the following pages for more info on how to get the tickets:
        \\- https://paemuri.com/projects/pony-island-ticket-checker
        \\- https://steamcommunity.com/sharedfiles/filedetails?id=3837647268#9484876
        \\
        \\Source: Linux native prefs.
        \\
    );
}

test "no missing tickets and source labels" {
    try expectReport(.linux_native, fullSet(),
        \\0 missing ticket(s).
        \\
        \\Source: Linux native prefs.
        \\
    );

    try expectReport(.linux_proton, fullSet(),
        \\0 missing ticket(s).
        \\
        \\Source: Linux Proton user.reg.
        \\
    );

    try expectReport(.windows, fullSet(),
        \\0 missing ticket(s).
        \\
        \\Source: Windows registry.
        \\
    );
}
