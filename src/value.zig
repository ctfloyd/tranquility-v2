const std = @import("std");
const ZigType = @import("std").builtin.Type;

const util = @import("util.zig");
const Object = @import("object.zig").Object;
const JsObject = @import("object.zig").JsObject;
const Function = @import("function.zig").Function;

pub const Value = struct {
    const Self = @This();

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
        as_string: []const u8,
        as_object: *Object,
    },
    // If this value was created as a side-effect of interpreting the abstract
    // syntax tree, then we know that the interpreter is the only thing keeping
    // an eye on this memory. If the interpreter is doing to discoard this value,
    // then it should also free it.
    interpreter_should_free: bool,

    pub inline fn make_undefined() Value {
        return Value.init_type(Type.Undefined);
    }

    // Value takes ownership of any pointer values given to it.
    pub fn init(value: anytype) Value {
        return switch (@typeInfo(@TypeOf(value))) {
            .Int => Value.init_int(value),
            .Float => Value.init_float(value),
            .Bool => Value.init_bool(value),
            .Pointer => Value.init_pointer(value),
            .ComptimeInt => Value.init_comptime_int(value),
            .ComptimeFloat => Value.init_comptime_float(value),
            else => unreachable,
        };
    }

    fn init_type(value_type: Type) Value {
        return .{
            .type = value_type,
            .value = undefined,
            .interpreter_should_free = false,
        };
    }

    fn init_int(value: anytype) Value {
        const info = @typeInfo(@TypeOf(value));
        std.debug.assert(info.Int.bits <= 32);

        return .{
            .type = Type.Number,
            .value = .{ .as_double = @as(f64, @floatFromInt(value)) },
            .interpreter_should_free = false,
        };
    }

    fn init_float(value: anytype) Value {
        const info = @typeInfo(@TypeOf(value));
        std.debug.assert(info.Float.bits <= 64);

        return .{
            .type = Type.Number,
            .value = .{ .as_double = value },
            .interpreter_should_free = false,
        };
    }

    fn init_bool(value: anytype) Value {
        std.debug.assert(@TypeOf(value) == bool);
        return .{
            .type = Type.Boolean,
            .value = .{ .as_bool = value },
            .interpreter_should_free = false,
        };
    }

    fn init_pointer(value: anytype) Value {
        const info = @typeInfo(@TypeOf(value));
        if (info.Pointer.is_const and info.Pointer.child == u8) {
            return .{
                .type = Type.String,
                .value = .{ .as_string = value },
                .interpreter_should_free = false,
            };
        } else if (info.Pointer.child == Object) {
            return .{
                .type = Type.Object,
                .value = .{ .as_object = value },
                .interpreter_should_free = false,
            };
        }
        unreachable;
    }

    fn init_comptime_int(value: anytype) Value {
        std.debug.assert(@TypeOf(value) == comptime_int);

        // This is a safe cast, since the value is known at compile time, the
        // compiler will throw an error if the value doesn't fit within a i32.
        const v: i32 = @intCast(value);
        return Value.init_int(v);
    }

    fn init_comptime_float(value: anytype) Value {
        std.debug.assert(@TypeOf(value) == comptime_float);

        // This is a safe cast, since the value is known at compile time, the
        // compiler will throw an error if the value doesn't fit within a f64.
        const v: f64 = @floatCast(value);
        return Value.init_float(v);
    }

    pub fn is_undefined(self: Self) bool {
        return self.type == Type.Undefined;
    }

    pub fn is_null(self: Self) bool {
        return self.type == Type.Null;
    }

    pub fn is_number(self: Self) bool {
        return self.type == Type.Number;
    }

    pub fn is_string(self: Self) bool {
        return self.type == Type.String;
    }

    pub fn is_boolean(self: Self) bool {
        return self.type == Type.Boolean;
    }

    pub fn is_object(self: Self) bool {
        return self.type == Type.Object;
    }

    pub fn as_double(self: Self) f64 {
        std.debug.assert(self.is_number());
        return self.value.as_double;
    }

    pub fn as_bool(self: Self) bool {
        std.debug.assert(self.is_boolean());
        return self.value.as_bool;
    }

    pub fn as_string(self: Self) []const u8 {
        std.debug.assert(self.is_string());
        return self.value.as_string;
    }

    pub fn as_object(self: Self) *Object {
        std.debug.assert(self.is_object());
        return self.value.as_object;
    }

    // Creates a string on the heap with the string representation of the value.
    // The caller is responsible for freeing Self memory when it's done using it.
    pub fn to_string(self: Self, allocator: std.mem.Allocator) []const u8 {
        // The memory to give back to the caller. It's guranteed to be initialized
        // by the end of the method.
        var give_to_caller: ?[]u8 = null;

        var value: []const u8 = "UNREACHABLE";
        if (self.is_boolean()) {
            if (self.as_bool()) {
                value = "true";
            } else {
                value = "false";
            }
        }

        if (self.is_null()) {
            value = "null";
        }

        if (self.is_undefined()) {
            value = "undefined";
        }

        if (self.is_number()) {
            give_to_caller = @constCast(util.number_to_string(allocator, self.as_double()));
        }

        if (self.is_string()) {
            value = self.as_string();
        }

        if (self.is_object()) {
            value = switch (self.as_object().*) {
                .JsObject => |*object| object.name(allocator),
                .Function => |*object| object.name(),
            };
        }

        if (give_to_caller != null) {
            return give_to_caller.?;
        }

        give_to_caller = allocator.alloc(u8, value.len) catch @panic("OOM");
        @memcpy(give_to_caller.?, value);
        return give_to_caller.?;
    }
};
