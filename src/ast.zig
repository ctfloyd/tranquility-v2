const std = @import("std");
const util = @import("util.zig");
const move = util.move;

const Object = @import("object.zig").Object;
const Value = @import("value.zig").Value;
const Interpreter = @import("interpreter.zig").Interpreter;
const Function = @import("function.zig").Function;

pub const AstNode = union(enum) {
    ScopeNode: ScopeNode,
    Expression: Expression,
    FunctionDeclaration: FunctionDeclaration,
    ReturnStatement: ReturnStatement,

    pub fn execute(self: *AstNode, interpreter: *Interpreter) Value {
        return switch (self.*) {
            inline else => |*an| an.execute(interpreter),
        };
    }

    pub fn deinit(self: AstNode) void {
        switch (self) {
            inline else => |expr| expr.deinit(),
        }
    }

    pub fn dump(self: AstNode, allocator: std.mem.Allocator, indent: u32) void {
        return switch (self) {
            inline else => |an| an.dump(allocator, indent),
        };
    }
};

pub const ScopeNode = union(enum) {
    Program: Program,
    BlockStatement: BlockStatement,

    pub fn deinit(self: ScopeNode) void {
        switch (self) {
            inline else => |sn| sn.deinit(),
        }
    }

    pub fn execute(self: *ScopeNode, interpreter: *Interpreter) Value {
        return switch (self.*) {
            inline else => |*sn| sn.execute(interpreter),
        };
    }

    pub fn clone(self: ScopeNode) ScopeNode {
        return switch (self) {
            inline else => |sn| sn.clone(),
        };
    }

    pub fn clone_ast_node(self: ScopeNode) AstNode {
        return switch (self) {
            inline else => |sn| sn.clone_ast_node(),
        };
    }

    pub fn dump(self: ScopeNode, allocator: std.mem.Allocator, indent: u32) void {
        return switch (self) {
            inline else => |sn| sn.dump(allocator, indent),
        };
    }
};

pub const Expression = union(enum) {
    BinaryExpression: BinaryExpression,
    CallExpression: CallExpression,
    Literal: Literal,

    pub fn deinit(self: Expression) void {
        switch (self) {
            inline else => |expr| expr.deinit(),
        }
    }

    pub fn execute(self: *Expression, interpreter: *Interpreter) Value {
        return switch (self.*) {
            inline else => |*expr| expr.execute(interpreter),
        };
    }

    pub fn clone(self: Expression) Expression {
        return switch (self) {
            inline else => |expr| expr.clone(),
        };
    }

    pub fn clone_ast_node(self: Expression) AstNode {
        return switch (self) {
            inline else => |expr| expr.clone_ast_node(),
        };
    }

    pub fn dump(self: Expression, allocator: std.mem.Allocator, indent: u32) void {
        return switch (self) {
            inline else => |expr| expr.dump(allocator, indent),
        };
    }
};

pub const BinaryOperation = union(enum) {
    Plus,
    Minus,
};

// An 'interface' of an element that can contain a scope.
pub const AbstractScopeNode = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    children: *std.ArrayList(AstNode),

    pub fn init(allocator: std.mem.Allocator) AbstractScopeNode {
        const children = allocator.create(std.ArrayList(AstNode)) catch @panic("OOM");
        children.* = std.ArrayList(AstNode).init(allocator);

        return .{ .allocator = allocator, .children = children };
    }

    pub fn deinit(self: Self) void {
        for (self.children.items) |child| {
            switch (child) {
                inline else => |c| c.deinit(),
            }
        }
        self.children.deinit();
        self.allocator.destroy(self.children);
    }

    pub fn append_child(self: *Self, child: AstNode) void {
        self.children.append(child) catch @panic("OOM");
    }

    pub fn clone(self: Self) AbstractScopeNode {
        const children = self.allocator.create(std.ArrayList(AstNode)) catch @panic("OOM");
        children.* = std.ArrayList(AstNode).init(self.allocator);

        for (self.children.items) |child| {
            var child_clone = switch (child) {
                inline else => |c| c.clone_ast_node(),
            };
            children.append(child_clone) catch @panic("OOM");
        }

        return .{ .allocator = self.allocator, .children = children };
    }

    pub fn execute(self: *Self, delegate: *ScopeNode, interpreter: *Interpreter) Value {
        _ = self;
        return interpreter.run(delegate);
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        for (self.children.items) |child| {
            switch (child) {
                inline else => |c| c.dump(allocator, indent + 1),
            }
        }
    }
};

// Concerete implementation of a ScopeNode.
// Represents the top-level of a program.
pub const Program = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    parent: *AbstractScopeNode,

    pub fn init(allocator: std.mem.Allocator) Program {
        const parent = allocator.create(AbstractScopeNode) catch @panic("OOM");
        parent.* = AbstractScopeNode.init(allocator);
        return .{
            .allocator = allocator,
            .parent = parent,
        };
    }

    pub fn deinit(self: Self) void {
        self.parent.deinit();
        self.allocator.destroy(self.parent);
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "Program";
    }

    pub fn append_child(self: *Self, child: AstNode) void {
        self.parent.append_child(child);
    }

    pub fn children(self: *Self) []AstNode {
        return self.parent.children.items;
    }

    pub fn clone_ast_node(self: Self) AstNode {
        return .{ .ScopeNode = self.clone() };
    }

    pub fn clone(self: Self) ScopeNode {
        const parent = self.allocator.create(AbstractScopeNode) catch @panic("OOM");
        parent.* = self.parent.clone();
        return .{
            .Program = .{
                .allocator = self.allocator,
                .parent = parent,
            },
        };
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) Value {
        return self.parent.execute(@ptrCast(self), interpreter);
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        for (0..(indent * 4)) |i| {
            mem[i] = ' ';
        }
        const v = std.fmt.bufPrintZ(mem[indent * 4 ..], "{s}", .{"[Program]\n"}) catch @panic("P");
        std.debug.print("{s}", .{mem[0 .. v.len + (indent * 4)]});
        self.parent.dump(allocator, indent);
    }
};

// Concrete implementation of a ScopeNode.
// Represents a block in code, i.e. '{ some code here }'.
pub const BlockStatement = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    parent: *AbstractScopeNode,

    pub fn init(allocator: std.mem.Allocator) BlockStatement {
        const parent = allocator.create(AbstractScopeNode) catch @panic("OOM");
        parent.* = AbstractScopeNode.init(allocator);
        return .{ .allocator = allocator, .parent = parent };
    }

    pub fn deinit(self: Self) void {
        self.parent.deinit();
        self.allocator.destroy(self.parent);
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "BlockStatement";
    }

    pub fn append_child(self: *Self, child: AstNode) void {
        self.parent.append_child(child);
    }

    pub fn children(self: *Self) []AstNode {
        return self.parent.children.items;
    }

    pub fn clone_ast_node(self: Self) AstNode {
        return .{ .ScopeNode = self.clone() };
    }

    pub fn clone(self: Self) ScopeNode {
        const parent = self.allocator.create(AbstractScopeNode) catch @panic("OOM");
        parent.* = self.parent.clone();
        return .{
            .BlockStatement = .{
                .allocator = self.allocator,
                .parent = parent,
            },
        };
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) Value {
        return self.parent.execute(@ptrCast(self), interpreter);
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        for (0..(indent * 4)) |i| {
            mem[i] = ' ';
        }
        const v = std.fmt.bufPrintZ(mem[indent * 4 ..], "{s}", .{"[BlockStatement]\n"}) catch @panic("P");
        std.debug.print("{s}", .{mem[0 .. v.len + (indent * 4)]});
        self.parent.dump(allocator, indent + 1);
    }
};

pub const FunctionDeclaration = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    function_name: []const u8,
    body: *ScopeNode,

    pub fn init(allocator: std.mem.Allocator, function_name: []const u8, body: ScopeNode) FunctionDeclaration {
        const my_body = allocator.create(ScopeNode) catch @panic("OOM");
        my_body.* = body.clone();

        return .{
            .allocator = allocator,
            .function_name = util.own_str(allocator, function_name),
            .body = my_body,
        };
    }

    pub fn deinit(self: Self) void {
        self.body.deinit();
        self.allocator.free(self.function_name);
        self.allocator.destroy(self.body);
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "FunctionDeclaration";
    }

    pub fn execute(self: Self, interpreter: *Interpreter) Value {
        var function = self.allocator.create(Object) catch @panic("OOM");
        function.* = .{ .Function = Function.init(self.allocator, self.function_name, self.body) };
        interpreter.global_object.put(self.function_name, Value.init(function));
        return Value.init(function);
    }

    pub fn clone_ast_node(self: Self) AstNode {
        return .{ .FunctionDeclaration = FunctionDeclaration.init(self.allocator, self.function_name, self.body.*) };
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        for (0..(indent * 4)) |i| {
            mem[i] = ' ';
        }
        var v = std.fmt.bufPrintZ(mem[indent * 4 ..], "{s}{s}{s}", .{
            "[FunctionDeclaration (",
            self.function_name,
            ")]\n",
        }) catch @panic("P");
        std.debug.print("{s}", .{mem[0 .. v.len + (indent * 4)]});
        self.body.dump(allocator, indent + 1);
    }
};

pub const ReturnStatement = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    argument: *Expression,

    pub fn init(allocator: std.mem.Allocator, argument: Expression) ReturnStatement {
        var my_argument = allocator.create(Expression) catch @panic("OOM");
        my_argument.* = argument.clone();

        return .{
            .allocator = allocator,
            .argument = my_argument,
        };
    }

    pub fn deinit(self: Self) void {
        self.argument.deinit();
        self.allocator.destroy(self.argument);
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "ReturnStatement";
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) Value {
        return switch (self.argument.*) {
            inline else => |*arg| arg.execute(interpreter),
        };
    }

    pub fn clone_ast_node(self: Self) AstNode {
        return .{ .ReturnStatement = ReturnStatement.init(self.allocator, self.argument.*) };
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        for (0..(indent * 4)) |i| {
            mem[i] = ' ';
        }
        const v = std.fmt.bufPrintZ(mem[indent * 4 ..], "{s}", .{"[ReturnStatement]\n"}) catch @panic("P");
        std.debug.print("{s}", .{mem[0 .. v.len + (indent * 4)]});
        self.argument.dump(allocator, indent + 1);
    }
};

pub const BinaryExpression = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    operation: BinaryOperation,
    left_hand_side: *Expression,
    right_hand_side: *Expression,

    pub fn init(allocator: std.mem.Allocator, operation: BinaryOperation, left_hand_side: Expression, right_hand_side: Expression) BinaryExpression {
        var my_lhs = allocator.create(Expression) catch @panic("OOM");
        my_lhs.* = left_hand_side.clone();

        var my_rhs = allocator.create(Expression) catch @panic("OOM");
        my_rhs.* = right_hand_side.clone();

        return .{
            .allocator = allocator,
            .operation = operation,
            .left_hand_side = my_lhs,
            .right_hand_side = my_rhs,
        };
    }

    pub fn deinit(self: Self) void {
        self.left_hand_side.deinit();
        self.right_hand_side.deinit();
        self.allocator.destroy(self.left_hand_side);
        self.allocator.destroy(self.right_hand_side);
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "BinaryExpression";
    }

    pub fn clone_ast_node(self: Self) AstNode {
        return .{ .Expression = self.clone() };
    }

    pub fn clone(self: Self) Expression {
        return .{
            .BinaryExpression = BinaryExpression.init(
                self.allocator,
                self.operation,
                self.left_hand_side.*,
                self.right_hand_side.*,
            ),
        };
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) Value {
        var lhs_result = switch (self.left_hand_side.*) {
            inline else => |*lhs| lhs.execute(interpreter),
        };
        var rhs_result = switch (self.right_hand_side.*) {
            inline else => |*rhs| rhs.execute(interpreter),
        };

        return switch (self.operation) {
            .Plus => BinaryExpression.add(lhs_result, rhs_result),
            .Minus => BinaryExpression.minus(lhs_result, rhs_result),
        };
    }

    fn add(lhs: Value, rhs: Value) Value {
        std.debug.assert(lhs.is_number());
        std.debug.assert(rhs.is_number());
        return Value.init(lhs.as_double() + rhs.as_double());
    }

    fn minus(lhs: Value, rhs: Value) Value {
        std.debug.assert(lhs.is_number());
        std.debug.assert(rhs.is_number());
        return Value.init(lhs.as_double() - rhs.as_double());
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        for (0..(indent * 4)) |i| {
            mem[i] = ' ';
        }
        const v = std.fmt.bufPrintZ(mem[indent * 4 ..], "{s}{s}{s}", .{
            "[BinaryExpression (",
            @tagName(self.operation),
            ")]\n",
        }) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + (indent * 4)]});
        self.left_hand_side.dump(allocator, indent + 1);
        self.right_hand_side.dump(allocator, indent + 1);
    }
};

pub const Literal = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    value: *Value,

    pub fn init(allocator: std.mem.Allocator, value: Value) Literal {
        return .{
            .allocator = allocator,
            .value = move(allocator, Value, value),
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.destroy(self.value);
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "Literal";
    }

    pub fn clone_ast_node(self: Self) AstNode {
        return .{ .Expression = self.clone() };
    }

    pub fn clone(self: Self) Expression {
        return .{ .Literal = Literal.init(self.allocator, self.value.*) };
    }

    pub fn execute(self: Self, interpreter: *Interpreter) Value {
        _ = interpreter;
        return self.value.*;
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        for (0..(indent * 4)) |i| {
            mem[i] = ' ';
        }

        const v_str = self.value.*.to_string(allocator);
        defer allocator.free(v_str);

        const v = std.fmt.bufPrintZ(mem[indent * 4 ..], "{s}{s}{s}", .{
            "[Literal (",
            v_str,
            ")]\n",
        }) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + (indent * 4)]});
    }
};

pub const CallExpression = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    function_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, function_name: []const u8) CallExpression {
        return .{ .allocator = allocator, .function_name = util.own_str(allocator, function_name) };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.function_name);
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "CallExpression";
    }

    pub fn clone_ast_node(self: Self) AstNode {
        return .{ .Expression = self.clone() };
    }

    pub fn clone(self: Self) Expression {
        return .{ .CallExpression = CallExpression.init(self.allocator, self.function_name) };
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) Value {
        var callee = interpreter.global_object.get(self.function_name);
        var callee_object = callee.as_object();
        return switch (callee_object.*) {
            .Function => |*function| interpreter.run(function.body),
            else => unreachable,
        };
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        for (0..(indent * 4)) |i| {
            mem[i] = ' ';
        }
        const v = std.fmt.bufPrintZ(mem[indent * 4 ..], "{s}{s}{s}", .{
            "[CallExpression (",
            self.function_name,
            ")]\n",
        }) catch @panic("P");
        std.debug.print("{s}", .{mem[0 .. v.len + (indent * 4)]});
    }
};
