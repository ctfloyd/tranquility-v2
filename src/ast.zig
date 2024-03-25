const std = @import("std");
const util = @import("util.zig");

const Object = @import("object.zig").Object;
const Value = @import("value.zig").Value;
const Interpreter = @import("interpreter.zig").Interpreter;
const Function = @import("function.zig").Function;

const DUMP_SPACE_AMOUNT = 4;

pub const AstNode = union(enum) {
    ScopeNode: ScopeNode,
    Expression: Expression,
    FunctionDeclaration: FunctionDeclaration,
    ReturnStatement: ReturnStatement,

    pub fn execute(self: *AstNode, interpreter: *Interpreter) *Value {
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

    pub fn execute(self: *ScopeNode, interpreter: *Interpreter) *Value {
        return switch (self.*) {
            inline else => |*sn| sn.execute(interpreter),
        };
    }

    pub fn append_child(self: *ScopeNode, node: *AstNode) void {
        switch (self.*) {
            inline else => |*sn| sn.append_child(node),
        }
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

    pub fn execute(self: *Expression, interpreter: *Interpreter) *Value {
        return switch (self.*) {
            inline else => |*expr| expr.execute(interpreter),
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
    children: *std.ArrayList(*AstNode),

    pub fn init(allocator: std.mem.Allocator) AbstractScopeNode {
        const children = allocator.create(std.ArrayList(*AstNode)) catch @panic("OOM");
        children.* = std.ArrayList(*AstNode).init(allocator);

        return .{ .allocator = allocator, .children = children };
    }

    pub fn deinit(self: Self) void {
        for (self.children.items) |child_ptr| {
            switch (child_ptr.*) {
                inline else => |c| c.deinit(),
            }
        }
        self.children.deinit();
        self.allocator.destroy(self.children);
    }

    pub fn append_child(self: *Self, child: *AstNode) void {
        self.children.append(child) catch @panic("OOM");
    }

    pub fn execute(self: *Self, delegate: *ScopeNode, interpreter: *Interpreter) *Value {
        _ = self;
        return interpreter.run(delegate) orelse @panic("WTF");
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        for (self.children.items) |child_ptr| {
            switch (child_ptr.*) {
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

    pub fn append_child(self: *Self, child: *AstNode) void {
        self.parent.append_child(child);
    }

    pub fn children(self: *Self) []*AstNode {
        return self.parent.children.items;
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) *Value {
        return self.parent.execute(@ptrCast(self), interpreter);
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        defer allocator.free(mem);

        var spaces = indent * DUMP_SPACE_AMOUNT;
        for (0..spaces) |i| {
            mem[i] = ' ';
        }

        const v = std.fmt.bufPrintZ(mem[spaces..], "{s}", .{"[Program]\n"}) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + spaces]});
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

    pub fn append_child(self: *Self, child: *AstNode) void {
        self.parent.append_child(child);
    }

    pub fn children(self: *Self) []*AstNode {
        return self.parent.children.items;
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) *Value {
        return self.parent.execute(@ptrCast(self), interpreter);
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        defer allocator.free(mem);

        const spaces = indent * DUMP_SPACE_AMOUNT;
        for (0..spaces) |i| {
            mem[i] = ' ';
        }

        const v = std.fmt.bufPrintZ(mem[spaces..], "{s}", .{"[BlockStatement]\n"}) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + spaces]});
        self.parent.dump(allocator, indent + 1);
    }
};

pub const FunctionDeclaration = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    function_name: []const u8,
    body: *ScopeNode,

    pub fn init(allocator: std.mem.Allocator, function_name: []const u8, body: *ScopeNode) FunctionDeclaration {
        return .{
            .allocator = allocator,
            .function_name = function_name,
            .body = body,
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "FunctionDeclaration";
    }

    pub fn execute(self: Self, interpreter: *Interpreter) *Value {
        // When the global object is cleaned up from the interpreter, the function
        // object that is created here should also be cleaned up then.
        var function = self.allocator.create(Object) catch @panic("OOM");
        function.* = .{ .Function = Function.init(self.allocator, self.function_name, self.body) };

        // When the global object is cleaned up from the intrepter, the value
        // object that is created here should also be cleaned up then.
        const value = self.allocator.create(Value) catch @panic("OOM");
        value.* = Value.init(function);
        value.*.interpreter_should_free = true;

        interpreter.global_object.put(self.function_name, value);
        return value;
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        defer allocator.free(mem);

        const spaces = indent * DUMP_SPACE_AMOUNT;
        for (0..spaces) |i| {
            mem[i] = ' ';
        }
        var v = std.fmt.bufPrintZ(mem[spaces..], "{s}{s}{s}", .{
            "[FunctionDeclaration (",
            self.function_name,
            ")]\n",
        }) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + spaces]});
        self.body.dump(allocator, indent + 1);
    }
};

pub const ReturnStatement = struct {
    const Self = @This();

    argument: *Expression,

    pub fn init(argument: *Expression) ReturnStatement {
        return .{
            .argument = argument,
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "ReturnStatement";
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) *Value {
        return switch (self.argument.*) {
            inline else => |*arg| arg.execute(interpreter),
        };
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        defer allocator.free(mem);

        const spaces = indent * DUMP_SPACE_AMOUNT;
        for (0..spaces) |i| {
            mem[i] = ' ';
        }

        const v = std.fmt.bufPrintZ(mem[spaces..], "{s}", .{"[ReturnStatement]\n"}) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + spaces]});
        self.argument.dump(allocator, indent + 1);
    }
};

pub const BinaryExpression = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    operation: BinaryOperation,
    left_hand_side: *Expression,
    right_hand_side: *Expression,

    pub fn init(allocator: std.mem.Allocator, operation: BinaryOperation, left_hand_side: *Expression, right_hand_side: *Expression) BinaryExpression {
        return .{
            .allocator = allocator,
            .operation = operation,
            .left_hand_side = left_hand_side,
            .right_hand_side = right_hand_side,
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "BinaryExpression";
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) *Value {
        var lhs_result = switch (self.left_hand_side.*) {
            inline else => |*lhs| lhs.execute(interpreter),
        };
        defer interpreter.maybe_cleanup_value(lhs_result);

        var rhs_result = switch (self.right_hand_side.*) {
            inline else => |*rhs| rhs.execute(interpreter),
        };
        defer interpreter.maybe_cleanup_value(rhs_result);

        return switch (self.operation) {
            .Plus => self.add(lhs_result, rhs_result),
            .Minus => self.minus(lhs_result, rhs_result),
        };
    }

    fn add(self: *Self, lhs: *Value, rhs: *Value) *Value {
        std.debug.assert(lhs.is_number());
        std.debug.assert(rhs.is_number());

        const value = self.allocator.create(Value) catch @panic("OOM");
        value.* = Value.init(lhs.as_double() + rhs.as_double());
        value.*.interpreter_should_free = true;
        return value;
    }

    fn minus(self: *Self, lhs: *Value, rhs: *Value) *Value {
        std.debug.assert(lhs.is_number());
        std.debug.assert(rhs.is_number());

        const value = self.allocator.create(Value) catch @panic("OOM");
        value.* = Value.init(lhs.as_double() + rhs.as_double());
        value.*.interpreter_should_free = true;
        return value;
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        defer allocator.free(mem);

        const spaces = indent * DUMP_SPACE_AMOUNT;
        for (0..spaces) |i| {
            mem[i] = ' ';
        }

        const v = std.fmt.bufPrintZ(mem[spaces..], "{s}{s}{s}", .{
            "[BinaryExpression (",
            @tagName(self.operation),
            ")]\n",
        }) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + spaces]});
        self.left_hand_side.dump(allocator, indent + 1);
        self.right_hand_side.dump(allocator, indent + 1);
    }
};

pub const Literal = struct {
    const Self = @This();

    value: *Value,

    pub fn init(value: *Value) Literal {
        return .{
            .value = value,
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "Literal";
    }

    pub fn execute(self: Self, interpreter: *Interpreter) *Value {
        _ = interpreter;
        return self.value;
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        defer allocator.free(mem);

        const spaces = indent * DUMP_SPACE_AMOUNT;
        for (0..spaces) |i| {
            mem[i] = ' ';
        }

        const v_str = self.value.*.to_string(allocator);
        defer allocator.free(v_str);

        const v = std.fmt.bufPrintZ(mem[spaces..], "{s}{s}{s}", .{
            "[Literal (",
            v_str,
            ")]\n",
        }) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + spaces]});
    }
};

pub const CallExpression = struct {
    const Self = @This();

    function_name: []const u8,

    pub fn init(function_name: []const u8) CallExpression {
        return .{ .function_name = function_name };
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn name(self: Self) []const u8 {
        _ = self;
        return "CallExpression";
    }

    pub fn execute(self: *Self, interpreter: *Interpreter) *Value {
        var callee = interpreter.global_object.get(self.function_name);
        if (callee != null) {
            var callee_object = callee.?.as_object();
            return switch (callee_object.*) {
                .Function => |*function| interpreter.run(function.body) orelse @panic("WTF"),
                else => unreachable,
            };
        }
        unreachable;
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, indent: u32) void {
        var mem = allocator.alloc(u8, 128) catch @panic("OOM");
        defer allocator.free(mem);

        const spaces = indent * DUMP_SPACE_AMOUNT;
        for (0..spaces) |i| {
            mem[i] = ' ';
        }

        const v = std.fmt.bufPrintZ(mem[spaces..], "{s}{s}{s}", .{
            "[CallExpression (",
            self.function_name,
            ")]\n",
        }) catch @panic("P");

        std.debug.print("{s}", .{mem[0 .. v.len + spaces]});
    }
};
