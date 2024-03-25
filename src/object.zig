const std = @import("std");

const util = @import("util.zig");
const Value = @import("value.zig").Value;
const Function = @import("function.zig").Function;

pub const Object = union(enum) {
    JsObject: JsObject,
    Function: Function,

    pub fn deinit(self: *Object) void {
        switch (self.*) {
            inline else => |*obj| obj.deinit(),
        }
    }
};

pub const JsObject = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    properties: *std.StringHashMap(*Value),

    pub fn init(allocator: std.mem.Allocator) JsObject {
        const property_map = allocator.create(std.StringHashMap(*Value)) catch @panic("OOM");
        property_map.* = std.StringHashMap(*Value).init(allocator);

        return .{ .allocator = allocator, .properties = property_map };
    }

    pub fn deinit(self: *Self) void {
        var value_iterator = self.properties.valueIterator();
        while (value_iterator.next()) |value_ptr| {
            if (value_ptr.*.is_object()) {
                value_ptr.*.as_object().deinit();
                self.allocator.destroy(value_ptr.*.as_object());
            }
            // self.allocator.destroy(value_ptr);
        }
        self.properties.deinit();
        self.allocator.destroy(self.properties);
    }

    pub fn get(self: Self, property_name: []const u8) ?*Value {
        return self.properties.get(property_name);
    }

    pub fn put(self: *Self, property_name: []const u8, value: *Value) void {
        self.properties.put(property_name, value) catch @panic("OOM");
    }

    // Caller is responsible for freeing the memory.
    pub fn name(self: *Self, allocator: std.mem.Allocator) []const u8 {
        const size = util.number_to_string(allocator, self.properties.unmanaged.size);
        defer allocator.free(size);
        return util.concat(allocator, 3, .{ "Object(", size, ")" });
    }
};
