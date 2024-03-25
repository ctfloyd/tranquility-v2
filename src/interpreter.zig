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
    scope_stack: *std.ArrayList(*ScopeFrame),

    pub fn init(allocator: std.mem.Allocator) Interpreter {
        const object = allocator.create(JsObject) catch @panic("OOM");
        object.* = JsObject.init(allocator);

        const scope_stack = allocator.create(std.ArrayList(*ScopeFrame)) catch @panic("OOM");
        scope_stack.* = std.ArrayList(*ScopeFrame).init(allocator);

        return .{
            .allocator = allocator,
            .global_object = object,
            .scope_stack = scope_stack,
        };
    }

    pub fn deinit(self: Self) void {
        self.global_object.deinit();
        self.allocator.destroy(self.global_object);

        for (self.scope_stack.items) |scope_frame_ptr| {
            self.allocator.destroy(scope_frame_ptr);
        }

        self.scope_stack.deinit();
        self.allocator.destroy(self.scope_stack);
    }

    pub fn run(self: *Self, scope_node: *ScopeNode) ?*Value {
        self.enter_scope(scope_node);
        var last_value: ?*Value = null;
        var last_last_value: ?*Value = null;
        switch (scope_node.*) {
            inline else => |*node| {
                for (node.children()) |child_node| {
                    last_last_value = last_value;
                    last_value = child_node.execute(self);
                    self.maybe_cleanup_value(last_last_value);
                }
            },
        }
        self.maybe_cleanup_value(last_last_value);
        self.exit_scope(scope_node);
        return last_value;
    }

    pub fn enter_scope(self: *Self, scope_node: *ScopeNode) void {
        const scope_frame = self.allocator.create(ScopeFrame) catch @panic("OOM");
        scope_frame.* = .{ .scope_node = scope_node };

        self.scope_stack.append(scope_frame) catch @panic("OOM");
    }

    pub fn exit_scope(self: *Self, scope_node: *ScopeNode) void {
        std.debug.assert(self.scope_stack.getLast().scope_node == scope_node);
        var last_scope_frame = self.scope_stack.pop();
        self.allocator.destroy(last_scope_frame);
    }

    pub fn maybe_cleanup_value(self: *Self, value: ?*Value) void {
        if (value != null) {
            if (value.?.interpreter_should_free) {
                if (value.?.is_object()) {
                    value.?.as_object().deinit();
                    self.allocator.destroy(value.?.as_object());
                }
                self.allocator.destroy(value.?);
            }
        }
    }
};
