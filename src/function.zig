const std = @import("std");
const own_str = @import("util.zig").own_str;

const ScopeNode = @import("ast.zig").ScopeNode;
const JsObject = @import("object.zig").JsObject;

pub const Function = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    parent: *JsObject,
    function_name: []const u8,
    body: *ScopeNode,

    pub fn init(allocator: std.mem.Allocator, function_name: []const u8, body: *ScopeNode) Function {
        const object = allocator.create(JsObject) catch @panic("OOM");
        object.* = JsObject.init(allocator);

        const my_body = allocator.create(ScopeNode) catch @panic("OOM");
        my_body.* = body.clone();

        return .{
            .allocator = allocator,
            .parent = object,
            .function_name = own_str(allocator, function_name),
            .body = my_body,
        };
    }

    pub fn deinit(self: *Self) void {
        self.parent.deinit();
        self.body.deinit();
        self.allocator.free(self.function_name);
        self.allocator.destroy(self.body);
        self.allocator.destroy(self.parent);
    }

    pub fn name(self: *Self) []const u8 {
        _ = self;
        return "Function";
    }
};
