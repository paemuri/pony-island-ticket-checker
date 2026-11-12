const std = @import("std");
const tickets = @import("../tickets.zig");

const HKEY = std.os.windows.HKEY;
const LSTATUS = std.os.windows.LSTATUS;
const hkey_current_user = std.os.windows.HKEY_CURRENT_USER;

const key_read: u32 = 0x20019;
const key_wow64_32_key: u32 = 0x0200;

const reg_dword: u32 = 4;
const error_more_data: LSTATUS = 234;
const error_no_more_items: LSTATUS = 259;

extern "advapi32" fn RegOpenKeyExW(
    h_key: HKEY,
    sub_key: [*:0]const u16,
    options: u32,
    desired: u32,
    result: *HKEY,
) callconv(.c) LSTATUS;

extern "advapi32" fn RegEnumValueW(
    h_key: HKEY,
    index: u32,
    name: [*]u16,
    name_len: *u32,
    reserved: ?*u32,
    value_type: ?*u32,
    data: ?[*]u8,
    data_len: ?*u32,
) callconv(.c) LSTATUS;

extern "advapi32" fn RegQueryValueExW(
    h_key: HKEY,
    name: [*:0]const u16,
    reserved: ?*u32,
    value_type: ?*u32,
    data: ?[*]u8,
    data_len: ?*u32,
) callconv(.c) LSTATUS;

extern "advapi32" fn RegCloseKey(h_key: HKEY) callconv(.c) LSTATUS;

pub fn read() !tickets.Set {
    const subkeys = [_][*:0]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("Software\\Daniel Mullins Games\\Pony Island"),
        std.unicode.utf8ToUtf16LeStringLiteral("Software\\Daniel Mullins Games\\PonyIsland"),
    };
    const accesses = [_]u32{
        key_read,
        key_read | key_wow64_32_key,
    };

    for (subkeys) |subkey| {
        for (accesses) |access| {
            var key: HKEY = undefined;
            if (RegOpenKeyExW(hkey_current_user, subkey, 0, access, &key) != 0) {
                continue;
            }
            defer _ = RegCloseKey(key);
            return readKey(key);
        }
    }

    return error.WindowsKeyNotFound;
}

fn readKey(key: HKEY) !tickets.Set {
    var set = tickets.Set.empty;
    var index: u32 = 0;

    while (true) : (index += 1) {
        var name_buffer: [256]u16 = undefined;
        var name_len: u32 = @intCast(name_buffer.len);

        const status = RegEnumValueW(
            key,
            index,
            &name_buffer,
            &name_len,
            null,
            null,
            null,
            null,
        );

        if (status == error_no_more_items) break;
        if (status == error_more_data) continue;
        if (status != 0) return error.WindowsEnumFailed;

        if (name_len >= name_buffer.len) continue;
        if (name_len > 0 and name_buffer[name_len - 1] == 0) name_len -= 1;
        name_buffer[name_len] = 0;

        var name_utf8_buffer: [1024]u8 = undefined;
        const name_utf8_len = std.unicode.wtf16LeToWtf8(
            &name_utf8_buffer,
            name_buffer[0..name_len],
        );
        const value_name = name_utf8_buffer[0..name_utf8_len];
        if (!tickets.isTicketKey(value_name)) continue;

        var data: [4]u8 = undefined;
        var data_len: u32 = @intCast(data.len);
        var value_type: u32 = 0;

        const query_status = RegQueryValueExW(
            key,
            @ptrCast(&name_buffer),
            null,
            &value_type,
            &data,
            &data_len,
        );
        if (query_status != 0) continue;
        if (value_type != reg_dword or data_len != @as(u32, data.len)) continue;

        const value = std.mem.readInt(u32, &data, .little);
        const id = std.math.cast(u8, value) orelse continue;
        if (!tickets.isValid(id)) continue;

        set.set(id);
    }

    return set;
}
