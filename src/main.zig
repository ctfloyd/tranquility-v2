const std = @import("std");

const ast = @import("ast.zig");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Value = @import("value.zig").Value;
const JsObject = @import("object.zig").JsObject;
const Interpreter = @import("interpreter.zig").Interpreter;
const Expression = @import("ast.zig").Expression;
const AstNode = @import("ast.zig").AstNode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    //var lexer = try Lexer.init(allocator, "hello_world.js");
    //defer lexer.deinit();
    //try test_lexer(&lexer);
    //test_values(allocator);

    test_ast(allocator);
}

fn make(a: std.mem.Allocator, comptime T: type, value: T) *T {
    var t = a.create(T) catch @panic("OOM");
    t.* = value;
    return t;
}

fn test_ast(a: std.mem.Allocator) void {
    var program = make(a, ast.Program, ast.Program.init(a));
    defer a.destroy(program);
    defer program.deinit();

    var block = make(a, ast.ScopeNode, .{ .BlockStatement = ast.BlockStatement.init(a) });
    defer a.destroy(block);
    defer block.deinit();

    var one_value = make(a, Value, Value.init(1));
    defer a.destroy(one_value);
    var one_literal = make(a, ast.Expression, .{ .Literal = ast.Literal.init(one_value) });
    defer a.destroy(one_literal);

    var two_value = make(a, Value, Value.init(2));
    defer a.destroy(two_value);
    var two_literal = make(a, ast.Expression, .{ .Literal = ast.Literal.init(two_value) });
    defer a.destroy(two_literal);

    var three_value = make(a, Value, Value.init(3));
    defer a.destroy(three_value);
    var three_literal = make(a, ast.Expression, .{ .Literal = ast.Literal.init(three_value) });
    defer a.destroy(three_literal);

    var one_be = make(a, ast.Expression, .{ .BinaryExpression = ast.BinaryExpression.init(a, ast.BinaryOperation.Plus, one_literal, two_literal) });
    defer a.destroy(one_be);

    var two_be = make(a, ast.Expression, .{ .BinaryExpression = ast.BinaryExpression.init(a, ast.BinaryOperation.Plus, one_be, three_literal) });
    defer a.destroy(two_be);

    var rs = make(a, ast.AstNode, .{ .ReturnStatement = ast.ReturnStatement.init(two_be) });
    defer a.destroy(rs);

    block.append_child(rs);

    var fdcl = make(a, ast.AstNode, .{ .FunctionDeclaration = ast.FunctionDeclaration.init(a, "foo", block) });
    defer a.destroy(fdcl);
    program.append_child(fdcl);

    var ce = make(a, ast.AstNode, .{ .Expression = .{ .CallExpression = ast.CallExpression.init("foo") } });
    defer a.destroy(ce);
    program.append_child(ce);

    var interpreter = Interpreter.init(a);
    defer interpreter.deinit();
    var scope_node: ast.ScopeNode = .{ .Program = program.* };

    var maybe_result = interpreter.run(&scope_node);
    defer interpreter.maybe_cleanup_value(maybe_result);

    if (maybe_result != null) {
        var result_str = maybe_result.?.to_string(a);
        defer a.free(result_str);
        std.debug.print("Interpreter returned {s}\n", .{result_str});
    } else {
        std.debug.print("Interpreter returned an empty value.\n", .{});
    }

    program.dump(a, 0);
}

fn test_values(allocator: std.mem.Allocator) void {
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

    var obj = JsObject.init(allocator);
    defer obj.deinit();
    obj.put("property_one", v1);
    obj.put("property_two", v2);

    const v3 = Value.init(&obj);
    const str3 = v3.to_string(allocator);
    defer allocator.free(str3);
    std.debug.print("Value {s}\n", .{str3});
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

fn test_lexer(lexer: *Lexer) !void {
    try lexer.*.read_file();
    try lexer.*.tokenize();
    lexer.dump();
}
