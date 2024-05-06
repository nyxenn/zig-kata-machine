const std = @import("std");
const Method = @import("./Method.zig");
const Predefined = @import("./Predefined.zig");
const ArgParser = @import("./TypeParser.zig");
const string_fmt = @import("../util/string_fmt.zig").string_fmt;
const Exercise = @This();

const ExerciseType = enum {
    class,
    method,
};

pub const AccessModifier = enum {
    private,
    public,
};

pub const Property = struct {
    name: []const u8,
    type: []const u8,
    scope: AccessModifier,
};

name: []const u8,
type: ExerciseType,
generic: ?[]const u8 = null,
methods: ?[]Method = null,
properties: ?[]Property = null,

// Should not be used here
predefineds: ?[][]const u8 = null,

pub fn to_string(self: *Exercise, allocator: *const std.mem.Allocator) ![]u8 {
    return switch (self.type) {
        .class => string_fmt(allocator, "pub {s}", .{to_string_class(allocator)}),
        .method => string_fmt(allocator, "pub {s}", .{self.methods[0].to_string(allocator)}),
    };
}

pub fn add_predefined(self: Exercise, predefined: *const Predefined) void {
    switch (predefined) {
        .class => self.merge(predefined.class),
        .method => self.methods += predefined.method,
        .param => self.properties += predefined.property,
    }
}

fn merge(self: Exercise, other: *const Exercise, allocator: *const std.mem.Allocator) void {
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

fn to_string_class(self: *Exercise, allocator: *std.mem.Allocator) []u8 {
    const template =
        \\ const {s} = @This();
        \\
        \\ {s}
        \\ 
        \\ {s}
    ;

    return string_fmt(allocator, template, .{ self.name, self.props_to_string(allocator), self.methods_to_string(allocator) });
}

fn props_to_string(self: *Exercise, allocator: *std.mem.Allocator) ![]u8 {
    if (self.properties == null) return "";

    const format = "{s}{s}: {s},\r\n";
    var string = std.ArrayList(u8).init(allocator);

    for (self.properties.?) |p| {
        string.appendSlice(std.fmt.allocPrint(allocator, format, .{
            if (p.scope == AccessModifier.public) "pub " else "",
            p.name,
            ArgParser.from_str(p.type, allocator),
        }));
    }

    return string;
}

fn methods_to_string(self: *Exercise, allocator: *std.mem.Allocator) ![]u8 {
    if (self.methods == null) return "";

    var string = std.ArrayList(u8).init(allocator);
    for (self.methods.?) |m| {
        string.appendSlice(m.to_string(allocator));
    }

    return string;
}

// TODO: Test
