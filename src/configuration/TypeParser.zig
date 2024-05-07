const std = @import("std");
const expect = std.testing.expect;

// TODO: Write testy

pub const Error = error{LazyDeveloper};

const ARRAY_STR = "Array";
const ARRAY_FORMAT = "[]const {s}";

const SimpleTypes = enum {
    string,
    number,
    boolean,
};

// TODO: Include support for | undefined, add to test
pub fn from_str(str: []const u8, allocator: *const std.mem.Allocator) ![]const u8 {
    if (str.len == 0 or std.mem.eql(u8, "void", str)) return "void";

    const simple = std.meta.stringToEnum(SimpleTypes, str);

    // Praise
    if (simple != null) {
        return switch (simple.?) {
            SimpleTypes.string => "[]const u8",
            SimpleTypes.number => "i32",
            SimpleTypes.boolean => "bool",
        };
    }

    const is_array = str.len > ARRAY_STR.len and std.mem.eql(u8, str[0..ARRAY_STR.len], ARRAY_STR);
    const generic_begin_index: ?usize = if (is_array) ARRAY_STR.len else for (str, 0..) |c, i| {
        if (c == '<') break i;
    } else blk: {
        break :blk null;
    };

    if (!is_array and generic_begin_index == null) {
        // At this point, we assume that the parameter is a generic placeholder
        // such as 'T' or 'V' etc.
        // So just return str
        return str;
    }

    const generic_end_index = for (str[generic_begin_index.?..], 0..) |c, i| {
        if (c == '>') break i + ARRAY_STR.len;
    } else blk: {
        break :blk null;
    };

    const generic_part = try from_str(str[generic_begin_index.? + 1 .. generic_end_index.?], allocator);

    // TODO: Figure out generic format
    if (!is_array)
        return Error.LazyDeveloper;

    const res = try std.fmt.allocPrint(allocator.*, "[]const {s}", .{generic_part});
    return res;
}

// TODO: Generic tests, undefined tests
test "parses_void" {
    const allocator = &std.testing.allocator;

    const implicit = try from_str("", allocator);
    const explicit = try from_str("void", allocator);

    try expect(std.mem.eql(u8, "void", implicit));
    try expect(std.mem.eql(u8, "void", explicit));
}

test "parses string" {
    const allocator = &std.testing.allocator;

    const result = try from_str("string", allocator);

    try expect(std.mem.eql(u8, "[]const u8", result));
}

test "parses number" {
    const allocator = &std.testing.allocator;

    const result = try from_str("number", allocator);

    try expect(std.mem.eql(u8, "i32", result));
}

test "parses boolean" {
    const allocator = &std.testing.allocator;

    const result = try from_str("boolean", allocator);

    try expect(std.mem.eql(u8, "bool", result));
}

test "parses Array<number>" {
    const allocator = &std.testing.allocator;

    const result = try from_str("Array<number>", allocator);
    // TODO: This is bad. either alloc for every str or ... yeah i guess every return val
    defer allocator.free(result);

    try expect(std.mem.eql(u8, "[]const i32", result));
}
