const std = @import("std");

const ScopeNode = @import("ast.zig").ScopeNode;
const JsObject = @import("object.zig").JsObject;
const Value = @import("value.zig").Value;

const ScopeFrame = struct {
    scope_node: *const ScopeNode,
};

pub const Interpreter = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    global_object: *JsObject,
    scope_stack: std.ArrayList(ScopeFrame),

    pub fn init(allocator: std.mem.Allocator) Interpreter {
        const object = allocator.create(JsObject) catch @panic("OOM");
        object.* = JsObject.init(allocator);

        const scope_stack = std.ArrayList(ScopeFrame).init(allocator);

        return .{
            .allocator = allocator,
            .global_object = object,
            .scope_stack = scope_stack,
        };
    }

    pub fn deinit(self: Self) void {
        self.global_object.deinit();
        self.scope_stack.deinit();
        self.allocator.destroy(self.global_object);
    }

    pub fn run(self: *Self, scope_node: *ScopeNode) Value {
        self.enter_scope(scope_node);
        var last_value = Value.make_undefined();
        switch (scope_node.*) {
            inline else => |*node| {
                for (node.children()) |*child_node| {
                    last_value = child_node.execute(self);
                }
            },
        }
        self.exit_scope(scope_node);
        return last_value;
    }

    pub fn enter_scope(self: *Self, scope_node: *const ScopeNode) void {
        self.scope_stack.append(.{ .scope_node = scope_node }) catch @panic("OOM");
    }

    pub fn exit_scope(self: *Self, scope_node: *const ScopeNode) void {
        std.debug.assert(self.scope_stack.getLast().scope_node == scope_node);
        _ = self.scope_stack.pop();
    }
};
