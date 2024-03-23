const std = @import("std");

const ZigType = @import("std").builtin.Type;

pub const Value = struct {
    const this = @This();

    const Type = enum {
        Undefined,
        Null,
        Number,
        String,
        Object,
        Boolean,
    };

    type: Type,
    value: union {
        as_bool: bool,
        as_double: f64,
        as_string: []u8,
    },

    pub fn init(value: anytype) Value {
        return switch (@typeInfo(@TypeOf(value))) {
            .Int => Value.init_int(value),
            .Float => Value.init_float(value),
            .Bool => Value.init_bool(value),
            .Pointer => Value.init_string(value),
            .ComptimeInt => Value.init_comptime_int(value),
            .ComptimeFloat => Value.init_comptime_float(value),
            else => unreachable,
        };
    }

    pub fn init_int(value: anytype) Value {
        const info = @typeInfo(@TypeOf(value));
        std.debug.assert(info.Int.bits <= 32);

        return .{
            .type = Type.Number,
            .value = .{ .as_double = @as(f64, @floatFromInt(value)) },
        };
    }

    pub fn init_float(value: anytype) Value {
        const info = @typeInfo(@TypeOf(value));
        std.debug.assert(info.Float.bits <= 64);

        return .{
            .type = Type.Number,
            .value = .{ .as_double = value },
        };
    }

    pub fn init_bool(value: anytype) Value {
        std.debug.assert(@TypeOf(value) == bool);
        return .{
            .type = Type.Boolean,
            .value = .{ .as_bool = value },
        };
    }

    pub fn init_string(value: anytype) Value {
        const info = @typeInfo(@TypeOf(value));
        std.debug.assert(info.Pointer.is_const and info.Pointer.child == u8);

        return .{
            .type = Type.String,
            .value = .{ .as_string = @constCast(value) },
        };
    }

    pub fn init_comptime_int(value: anytype) Value {
        std.debug.assert(@TypeOf(value) == comptime_int);

        // This is a safe cast, since the value is known at compile time, the
        // compiler will throw an error if the value doesn't fit within a i32.
        const v: i32 = @intCast(value);
        return Value.init_int(v);
    }

    pub fn init_comptime_float(value: anytype) Value {
        std.debug.assert(@TypeOf(value) == comptime_float);

        // This is a safe cast, since the value is known at compile time, the
        // compiler will throw an error if the value doesn't fit within a f64.
        const v: f64 = @floatCast(value);
        return Value.init_float(v);
    }

    pub fn is_undefined(self: *const this) bool {
        return self.type == Type.Undefined;
    }

    pub fn is_null(self: *const this) bool {
        return self.type == Type.Null;
    }

    pub fn is_number(self: *const this) bool {
        return self.type == Type.Number;
    }

    pub fn is_string(self: *const this) bool {
        return self.type == Type.String;
    }

    pub fn is_boolean(self: *const this) bool {
        return self.type == Type.Boolean;
    }

    pub fn as_double(self: *const this) f64 {
        std.debug.assert(self.is_number());
        return self.value.as_double;
    }

    pub fn as_bool(self: *const this) bool {
        std.debug.assert(self.is_boolean());
        return self.value.as_bool;
    }

    pub fn as_string(self: *const this) []const u8 {
        std.debug.assert(self.is_string());
        return self.value.as_string;
    }

    pub fn to_string(self: *const this) []const u8 {
        if (self.is_boolean()) {
            if (self.as_bool()) {
                return "true";
            } else {
                return "false";
            }
        }

        if (self.is_null()) {
            return "null";
        }

        if (self.is_undefined()) {
            return "undefined";
        }

        if (self.is_number()) {
            var buf: [32]u8 = undefined;
            return std.fmt.bufPrintZ(&buf, "{d}", .{self.as_double()}) catch "number";
        }

        if (self.is_string()) {
            return self.as_string();
        }

        unreachable;
    }
};
