const std = @import("std");

pub fn own_str(allocator: std.mem.Allocator, str: []const u8) []const u8 {
    const my_str = allocator.alloc(u8, str.len) catch @panic("OOM");
    @memcpy(my_str, str);
    return my_str;
}

pub fn concat(allocator: std.mem.Allocator, comptime num_args: comptime_int, args: anytype) []const u8 {
    return std.fmt.allocPrint(allocator, "{s}" ** num_args, args) catch @panic("OOM");
}

pub fn move(allocator: std.mem.Allocator, comptime T: type, value: T) *T {
    const my_obj = allocator.create(T) catch @panic("OOM");
    my_obj.* = value;
    return my_obj;
}

pub fn number_to_string(allocator: std.mem.Allocator, value: anytype) []const u8 {
    return switch (@typeInfo(@TypeOf(value))) {
        .Int, .Float => number_to_string_unsafe(allocator, value),
        .ComptimeInt, .ComptimeFloat => |v| {
            const coerced_value: i128 = v;
            return number_to_string_unsafe(allocator, coerced_value);
        },
        else => unreachable,
    };
}

fn number_to_string_unsafe(allocator: std.mem.Allocator, value: anytype) []const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value}) catch @panic("OOM");
}
