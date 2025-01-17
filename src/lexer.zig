const std = @import("std");
const util = @import("util.zig");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Span = @import("span.zig").Span;

// Compile-time constant.
const MAX_FILE_SIZE_BYTES = 1 * 1024 * 1024 * 1024; // 1 GB
pub const Lexer = struct {
    const Self = @This();

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

        // NOTE: Take ownership of the memory for the file path given to us.
        // Even though the pointer is constant, the memory could still be
        // modified from underneath us. Not necessarily a problem now, but
        // it could lead to TOCTOU errors down the road.
        const own_file_path = util.own_str(allocator, file_path);

        return Lexer{
            .allocator = allocator,
            .file_path = own_file_path,
            .characters = undefined,
            .tokens = tokens,
            .input_buffer = input_buffer,
            .line_number = 1,
            .span_start = 1,
            .span_end = 0,
        };
    }

    pub fn read_file(self: *Self) !void {
        // NOTE: readFileAlloc(...) returns a heap-allocated u8 slice that we
        // are responsible for cleaning up.
        self.characters = try std.fs.cwd().readFileAlloc(self.allocator, self.file_path, MAX_FILE_SIZE_BYTES);
    }

    pub fn tokenize(self: *Self) !void {
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

    pub fn dump(self: Self) void {
        for (self.tokens.items) |token| {
            token.dump();
        }
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.file_path);
        self.allocator.free(self.characters);
        self.input_buffer.deinit();
        self.free_tokens();
    }

    fn free_tokens(self: *Self) void {
        for (self.tokens.items) |*token| {
            token.deinit();
        }
        self.tokens.deinit();
    }

    fn push_char(self: *Self, char: u8) !void {
        try self.input_buffer.append(char);
        self.count_span();
    }

    fn emit_literal_token(self: *Self, char: u8) !void {
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

    fn emit_token_from_buffer(self: *Self) !void {
        if (self.input_buffer.capacity <= 0) {
            return;
        }

        // NOTE: toOwnedSlice() returns a pointer to memory on the heap, so
        // it is safe to give to a token to hold onto. The token will cleanup
        // Self memory when it's deinit() method is called.
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

    fn emit_token(self: *Self, token: Token) !void {
        try self.tokens.append(token);
        self.span_start = self.span_end + 1;
    }

    fn make_token_with_value(self: *Self, token_type: TokenType, value: []u8) !Token {
        return try Token.initValue(
            self.allocator,
            token_type,
            self.line_number,
            self.make_span(),
            value,
        );
    }

    fn make_token(self: Self, token_type: TokenType) Token {
        return Token.init(token_type, self.line_number, self.make_span());
    }

    fn make_span(self: Self) Span {
        return .{ .start = self.span_start, .end = self.span_end };
    }

    fn new_line(self: *Self) void {
        self.line_number += 1;
        self.span_start = 1;
        self.span_end = 0;
    }

    fn count_span(self: *Self) void {
        self.span_end += 1;
    }

    fn bump_span(self: *Self) void {
        self.span_start += 1;
        self.span_end += 1;
    }
};
