const std = @import("std");

const util = @import("util.zig");

const tranquility_token = @import("token.zig");
const Token = tranquility_token.Token;
const TokenType = tranquility_token.TokenType;

const tranquility_span = @import("span.zig");
const Span = tranquility_span.Span;

// Compile-time constant.
const MAX_FILE_SIZE_BYTES = 1 * 1024 * 1024 * 1024; // 1 GB
pub const Lexer = struct {
    const this = @This();

    allocator: std.mem.Allocator,
    file_path: []const u8,
    characters: []const u8,
    tokens: std.ArrayList(Token),
    line_number: u32,

    span_start: u32,
    span_end: u32,
    input_buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, file_path: []const u8) !Lexer {
        var tokens = std.ArrayList(Token).init(allocator);
        var input_buffer = std.ArrayList(u8).init(allocator);

        return Lexer{
            .allocator = allocator,
            .file_path = try util.own_str(allocator, file_path),
            .characters = undefined,
            .tokens = tokens,
            .input_buffer = input_buffer,
            .line_number = 1,
            .span_start = 1,
            .span_end = 0,
        };
    }

    pub fn read_file(self: *this) !void {
        self.characters = try std.fs.cwd().readFileAlloc(self.allocator, self.file_path, MAX_FILE_SIZE_BYTES);
    }

    pub fn tokenize(self: *this) !void {
        if (self.tokens.items.len > 0) {
            std.debug.print("Already tokenized, will not tokenize again.\n", .{});
            return;
        }

        std.debug.print("Begininng tokenization on a character stream of size ({}).\n", .{self.characters.len});
        for (self.characters) |char| {
            try switch (char) {
                ' ' => {
                    try self.emit_token_from_buffer();
                    self.bump_span();
                },
                ';', '(', ')', '[', ']', '+', '=' => {
                    try self.emit_token_from_buffer();
                    try self.emit_literal_token(char);
                },
                '\n' => {
                    try self.emit_token_from_buffer();
                    self.new_line();
                },
                '\r' => continue, // pretend it isn't even there!
                else => self.push_char(char),
            };
        }
        try self.emit_token_from_buffer();
    }

    pub fn dump(self: *this) void {
        for (self.tokens.items) |token| {
            token.dump();
        }
    }

    pub fn deinit(self: *this) void {
        self.allocator.free(self.file_path);
        self.allocator.free(self.characters);
        self.input_buffer.deinit();
        self.free_tokens();
    }

    fn free_tokens(self: *this) void {
        for (self.tokens.items) |token| {
            token.deinit();
        }
        self.tokens.deinit();
    }

    fn push_char(self: *this, char: u8) !void {
        try self.input_buffer.append(char);
        self.count_span();
    }

    fn emit_literal_token(self: *this, char: u8) !void {
        const token = switch (char) {
            ';' => self.make_token(TokenType.Semicolon),
            '(' => self.make_token(TokenType.Left_Parenthesis),
            ')' => self.make_token(TokenType.Right_Parenthesis),
            '[' => self.make_token(TokenType.Left_Bracket),
            ']' => self.make_token(TokenType.Right_Bracket),
            '+' => self.make_token(TokenType.Plus),
            '=' => self.make_token(TokenType.Equals),
            else => unreachable,
        };
        try self.emit_token(token);
    }

    fn emit_token_from_buffer(self: *this) !void {
        if (self.input_buffer.capacity <= 0) {
            return;
        }

        const token_value = try self.input_buffer.toOwnedSlice();
        var token: Token = undefined;
        if (std.mem.eql(u8, token_value, "var")) {
            token = self.make_token(TokenType.Var);
        } else {
            token = try self.make_token_with_value(TokenType.Identifier, token_value);
        }
        try self.emit_token(token);

        defer {
            if (token.token_type != TokenType.Identifier) {
                self.allocator.free(token_value);
            }
            self.input_buffer.clearAndFree();
        }
    }

    fn emit_token(self: *this, token: Token) !void {
        try self.tokens.append(token);
        self.span_start = self.span_end + 1;
    }

    fn make_token_with_value(self: *this, token_type: TokenType, value: []u8) !Token {
        return try Token.initValue(
            self.allocator,
            token_type,
            self.line_number,
            self.make_span(),
            value,
        );
    }

    fn make_token(self: *this, token_type: TokenType) Token {
        return Token.init(token_type, self.line_number, self.make_span());
    }

    fn make_span(self: *this) Span {
        return .{ .start = self.span_start, .end = self.span_end };
    }

    fn new_line(self: *this) void {
        self.line_number += 1;
        self.span_start = 1;
        self.span_end = 0;
    }

    fn count_span(self: *this) void {
        self.span_end += 1;
    }

    fn bump_span(self: *this) void {
        self.span_start += 1;
        self.span_end += 1;
    }
};
