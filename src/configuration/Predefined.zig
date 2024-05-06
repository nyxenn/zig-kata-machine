const std = @import("std");
const Method = @import("./Method.zig");
const Property = @import("./Property.zig");
const Predefined = @This();

pub const PredefinedType = enum {
    class,
    property,
    method,
};

name: []const u8,
type: PredefinedType,
methods: ?[]Method = null,
properties: ?[]Property = null,

// Should not be used here
predefineds: ?[][]const u8 = null,

fn merge(self: Predefined, other: *Predefined, allocator: *const std.mem.Allocator) void {
    var methods = if (self.methods != null) std.ArrayList(Method).fromOwnedSlice(allocator, self.methods) else std.ArrayList(Method).init(allocator);

    for (other.methods) |m| {
        methods.append(m);
    }

    self.methods = methods;

    var properties = if (self.properties != null) std.ArrayList(Property).fromOwnedSlice(allocator, self.properties) else std.ArrayList(Property).init(allocator);

    for (other.properties) |m| {
        properties.append(m);
    }

    self.properties = properties;
}
