const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var lexer = try Lexer.init(allocator, "hello_world.js");
    defer lexer.deinit();

    try run(&lexer);

    test_value_i32(allocator, 1234);
    test_value_bool(allocator, true);
    test_value_double(allocator, 1234.5678);
    test_value_string(allocator, "test");

    const v1 = Value.init(3);
    const str = v1.to_string(allocator);
    defer allocator.free(str);
    std.debug.print("Value {s}\n", .{str});

    const v2 = Value.init(3.14);
    const str2 = v2.to_string(allocator);
    defer allocator.free(str2);
    std.debug.print("Value {s}\n", .{str2});

    var obj = Object.init(allocator);
    defer obj.deinit();
    obj.put("property_one", v1);
    obj.put("property_two", v2);

    const v3 = Value.init(&obj);
    const str3 = v3.to_string(allocator);
    defer allocator.free(str3);
    std.debug.print("Value {s}\n", .{str3});

    lexer.dump();
}

fn test_value_i32(alloc: std.mem.Allocator, value: i32) void {
    const v1 = Value.init(value);
    const str = v1.to_string(alloc);
    defer alloc.free(str);
    std.debug.print("Value {s}\n", .{str});
}

fn test_value_bool(alloc: std.mem.Allocator, value: bool) void {
    const v1 = Value.init(value);
    const str = v1.to_string(alloc);
    defer alloc.free(str);
    std.debug.print("Value {s}\n", .{str});
}

fn test_value_double(alloc: std.mem.Allocator, value: f64) void {
    const v1 = Value.init(value);
    const str = v1.to_string(alloc);
    defer alloc.free(str);
    std.debug.print("Value {s}\n", .{str});
}

fn test_value_string(alloc: std.mem.Allocator, value: []const u8) void {
    const v1 = Value.init(value);
    const str = v1.to_string(alloc);
    defer alloc.free(str);
    std.debug.print("Value {s}\n", .{str});
}

fn run(lexer: *Lexer) !void {
    try lexer.*.read_file();
    try lexer.*.tokenize();
}
