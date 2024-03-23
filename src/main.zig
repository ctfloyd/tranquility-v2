const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Value = @import("value.zig").Value;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var lexer = try Lexer.init(allocator, "hello_world.js");
    defer lexer.deinit();

    try run(&lexer);

    test_value_i32(1234);
    test_value_bool(true);
    test_value_double(1234.5678);
    test_value_string("test");

    const v1 = Value.init(3);
    std.debug.print("Value {s}\n", .{v1.to_string()});

    const v2 = Value.init(3.14);
    std.debug.print("Value {s}\n", .{v2.to_string()});
}

fn test_value_i32(value: i32) void {
    const v1 = Value.init(value);
    std.debug.print("Value {s}\n", .{v1.to_string()});
}

fn test_value_bool(value: bool) void {
    const v2 = Value.init(value);
    std.debug.print("Value {s}\n", .{v2.to_string()});
}

fn test_value_double(value: f64) void {
    const v3 = Value.init(value);
    std.debug.print("Value {s}\n", .{v3.to_string()});
}

fn test_value_string(value: []const u8) void {
    const v3 = Value.init(value);
    std.debug.print("Value {s}\n", .{v3.to_string()});
}

fn run(lexer: *Lexer) !void {
    try lexer.*.read_file();
    try lexer.*.tokenize();
    lexer.*.dump();
}
