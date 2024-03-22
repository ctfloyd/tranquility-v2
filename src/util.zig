const std = @import("std");

pub fn own_str(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    const my_str = try allocator.alloc(u8, str.len);
    @memcpy(my_str, str);
    return my_str;
}
