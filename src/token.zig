const std = @import("std");
const util = @import("util.zig");
const Span = @import("span.zig").Span;

pub const TokenType = enum {
    Var,
    Let,
    Const,
    Left_Parenthesis,
    Right_Parenthesis,
    Semicolon,
    Identifier,
    Left_Bracket,
    Right_Bracket,
    Plus,
    Equals,
};

pub const Token = struct {
    const this = @This();

    token_type: TokenType,
    line_number: u32,
    span: Span,

    allocator: ?std.mem.Allocator,
    value: ?[]const u8,

    pub fn init(token_type: TokenType, line_number: u32, span: Span) Token {
        return Token{
            .token_type = token_type,
            .line_number = line_number,
            .span = span,
            .allocator = null,
            .value = null,
        };
    }

    // Takes ownership of the value passed to us. Does not store its own copy.
    pub fn initValue(allocator: std.mem.Allocator, token_type: TokenType, line_number: u32, span: Span, value: []const u8) !Token {
        var token = Token.init(token_type, line_number, span);
        token.allocator = allocator;
        token.value = value;
        return token;
    }

    pub fn dump(self: *const this) void {
        std.debug.print("Token[type = {s}, line = {}, start = {}, end = {}, value = {?s}]\n", .{
            @tagName(self.token_type),
            self.line_number,
            self.span.start,
            self.span.end,
            self.value,
        });
    }

    pub fn deinit(self: *const this) void {
        if (self.value != null and self.allocator != null) {
            self.allocator.?.free(self.value.?);
        }
    }
};
