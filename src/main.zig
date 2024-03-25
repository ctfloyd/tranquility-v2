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

fn test_ast(allocator: std.mem.Allocator) void {
    var program = ast.Program.init(allocator);

    var block = ast.BlockStatement.init(allocator);
    var one_literal: Expression = .{ .Literal = ast.Literal.init(allocator, Value.init(1)) };
    var two_literal: Expression = .{ .Literal = ast.Literal.init(allocator, Value.init(2)) };
    var three_literal: Expression = .{ .Literal = ast.Literal.init(allocator, Value.init(3)) };
    var one_be: Expression = .{ .BinaryExpression = ast.BinaryExpression.init(allocator, ast.BinaryOperation.Plus, one_literal, two_literal) };
    var two_be: Expression = .{ .BinaryExpression = ast.BinaryExpression.init(allocator, ast.BinaryOperation.Plus, one_be, three_literal) };
    var rs: AstNode = .{ .ReturnStatement = ast.ReturnStatement.init(allocator, two_be) };
    block.append_child(rs);

    var fdcl: AstNode = .{ .FunctionDeclaration = ast.FunctionDeclaration.init(allocator, "foo", .{ .BlockStatement = block }) };
    std.debug.print("created block\n", .{});
    program.append_child(fdcl);
    var ce = .{ .Expression = .{ .CallExpression = ast.CallExpression.init(allocator, "foo") } };
    program.append_child(ce);

    var interpreter = Interpreter.init(allocator);
    var scope_node: ast.ScopeNode = .{ .Program = program };
    var result = interpreter.run(&scope_node);

    var result_str = result.to_string(allocator);
    std.debug.print("Interpreter returned {s}\n", .{result_str});

    program.dump(allocator, 0);

    defer {
        allocator.free(result_str);
        program.deinit();
        block.deinit();
        //interpreter.deinit();
        //one_literal.deinit();
        //two_literal.deinit();
        //three_literal.deinit();
        //'fdcl.deinit();
        //ce.deinit();
        //one_be.deinit();
        //two_be.deinit();
        rs.deinit();
    }
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
