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
