const std = @import("std");

const tranquility_lexer = @import("lexer.zig");
const Lexer = tranquility_lexer.Lexer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var lexer = try Lexer.init(allocator, "hello_world.js");
    defer lexer.deinit();

    try run(&lexer);
}

fn run(lexer: *Lexer) !void {
    try lexer.*.read_file();
    try lexer.*.tokenize();
    lexer.*.dump();
}
