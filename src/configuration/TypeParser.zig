const std = @import("std");

// TODO: Write testy

pub const Error = error{LazyDeveloper};

const ARRAY_STR = "Array";
const ARRAY_FORMAT = "[]const {s}";

const SimpleTypes = enum {
    string,
    number,
    boolean,
};

// TODO: Include support for | undefined
pub fn from_str(str: []const u8, allocator: *const std.mem.Allocator) ![]const u8 {
    if (str.len == 0) return "void";

    const simple = std.meta.stringToEnum(SimpleTypes, str);

    // Praise
    if (simple != null) {
        return switch (simple.?) {
            SimpleTypes.string => "[]const u8",
            SimpleTypes.number => "i32",
            SimpleTypes.boolean => "bool",
        };
    }

    const is_array = std.mem.eql(u8, str[0..ARRAY_STR.len], ARRAY_STR);
    const generic_begin_index = if (is_array) ARRAY_STR.len else for (str, 0..) |c, i| {
        if (c == '<') break i;
    } else blk: {
        break :blk -1;
    };

    if (!is_array and generic_begin_index == -1) {
        // At this point, we assume that the parameter is a generic placeholder
        // such as 'T' or 'V' etc.
        // So just return str
        return str;
    }

    const generic_end_index = for (str[generic_begin_index..], 0..) |c, i| {
        if (c == '>') break i;
    } else blk: {
        break :blk -1;
    };

    const generic_part = from_str(str[generic_begin_index..generic_end_index], allocator);

    // TODO: Figure out generic format
    if (!is_array)
        return Error.LazyDeveloper;

    return std.fmt.allocPrint(allocator, ARRAY_FORMAT, .{generic_part});
}
