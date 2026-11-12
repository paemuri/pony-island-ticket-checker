const std = @import("std");

pub const Source = enum {
    linux_native,
    linux_proton,
    windows_registry,
};

pub fn write(writer: *std.Io.Writer, source: Source, missing: []const u8) !void {
    try writer.print("{d} missing ticket(s).", .{missing.len});

    if (missing.len != 0) {
        try writer.writeAll(" Ticket ID(s):\n");
        for (missing) |id| {
            try writer.print("- {d}\n", .{id});
        }
        try writer.writeAll(
            \\
            \\Check the following pages for more info on how to get the tickets:
            \\- https://paemuri.com/projects/pony-island-ticket-checker
            \\- https://steamcommunity.com/sharedfiles/filedetails?id=3837647268#9484876
        );
    }

    try writer.print("\n\nSource: {s}\n", .{sourceLabel(source)});
}

fn sourceLabel(source: Source) []const u8 {
    return switch (source) {
        .linux_native => "Linux native prefs",
        .linux_proton => "Linux Proton user.reg",
        .windows_registry => "Windows registry",
    };
}
