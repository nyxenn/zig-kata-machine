const std = @import("std");

pub fn string_fmt(allocator: *std.mem.Allocator, comptime fmt: []const u8, args: anytype) std.fmt.AllocPrintError![]u8 {
    return std.fmt.allocPrint(allocator.*, fmt, args);
}
