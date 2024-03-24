const std = @import("std");

const util = @import("util.zig");
const Value = @import("value.zig").Value;

pub const Object = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    properties: std.StringHashMap(Value),
    m_name: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) Object {
        const property_map = std.StringHashMap(Value).init(allocator);
        return .{ .allocator = allocator, .m_name = null, .properties = property_map };
    }

    pub fn deinit(self: *Self) void {
        if (self.m_name != null) {
            self.allocator.free(self.m_name.?);
        }
        self.properties.deinit();
    }

    pub fn get(self: Self, property_name: []const u8) Value {
        return self.properties.get(property_name) orelse Value.make_undefined();
    }

    pub fn put(self: *Self, property_name: []const u8, value: Value) void {
        self.properties.put(property_name, value) catch @panic("OOM");
    }

    pub fn name(self: *Self) []const u8 {
        if (self.m_name == null) {
            const size = util.number_to_string(self.allocator, self.properties.unmanaged.size);
            defer self.allocator.free(size);

            const computed_name = util.concat(self.allocator, 3, .{ "Object(", size, ")" });
            self.m_name = computed_name;
        }
        return self.m_name.?;
    }
};
