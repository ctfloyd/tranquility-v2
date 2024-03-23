const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

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
