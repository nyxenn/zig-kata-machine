const std = @import("std");
const string_fmt = @import("../util/string_fmt.zig").string_fmt;
const ArgParser = @import("./TypeParser.zig");
const Method = @This();

name: []const u8,
arg_types: [][]const u8,
arg_names: [][]const u8,
return_type: []const u8,

pub fn to_string(self: *Method, allocator: *std.mem.Allocator) []u8 {
    const template =
        \\ {s}({s}) {s} {{
        \\ 
        \\ }}
    ;

    return string_fmt(allocator, template, .{
        self.name,
        self.params_to_string(allocator),
        self.return_type_to_string(allocator),
    });
}

fn params_to_string(self: *Method, allocator: *const std.mem.Allocator) []const u8 {
    const format = "{s}: {s}, ";
    var string = std.ArrayList(u8).init(allocator);

    for (self.arg_names, 0..) |n, i| {
        string.appendSlice(std.fmt.allocPrint(allocator, format, .{ n, ArgParser.from_str(self.arg_types[i], allocator) }));
    }

    // Skip trailing ', '
    return string[0 .. string.items.len - 2];
}

fn return_type_to_string(self: Method, allocator: *const std.mem.Allocator) []const u8 {
    return ArgParser.from_str(self.return_type, allocator);
}

// TODO: test
