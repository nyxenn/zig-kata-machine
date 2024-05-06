const std = @import("std");
const cfg = @import("configuration.zig");

pub fn main() !void {
    try generate_katas();
}

fn generate_katas() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    const json = try std.fs.cwd().readFileAlloc(allocator.*, "dsa.json", 25_000);
    defer allocator.free(json);

    var config = cfg.Configuration{};
    try config.init(&allocator, json);
    defer config.deinit();

    std.debug.print("\n\nParsed json:\n{}\n", .{try config.value()});
}
