const std = @import("std");
const expect = std.testing.expect;

pub fn main() !void {
    std.debug.print("broooooooooooooooo", .{});
}

test "try not to fuc this up" {
    try std.testing.expect
    try expect(1 == 2);
}
