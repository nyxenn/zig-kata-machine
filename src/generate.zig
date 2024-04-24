const std = @import("std");
const testing = std.testing;
const tmp_dir = testing.tmpDir;
const expect = testing.expect;

pub fn generate_katas() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
    const curr_day = try highest_day_folder_in_src(dir, &allocator);

    std.debug.print("\nDay folders: {}\n", .{curr_day});
}

fn highest_day_folder_in_src(dir: std.fs.Dir, allocator: *const std.mem.Allocator) !i16 {
    var walker = try dir.walk(allocator.*);
    defer walker.deinit();

    var max: i16 = 0;
    // Loop over items in dir
    outer: while (try walker.next()) |item| {
        if (item.kind != std.fs.File.Kind.directory) continue;
        if (item.basename.len != 7) continue;

        // Create mask of directory name by:
        // - Replacing numeric characters with 'x'
        // - Replacing uppercase characters with lowercase equivalent
        var mask: [7]u8 = .{undefined} ** 7;
        for (item.basename, 0..) |c, i| {
            mask[i] = switch (c) {
                '0'...'9' => 'x',
                'A'...'Z' => c + 'a' - 'A',
                else => c,
            };
        }

        // Verify masked directory name is "day_xxx"
        for ("day_xxx", 0..) |c, i| {
            if (c != mask[i]) continue :outer;
        }

        // Update max if day number is higher than current max
        const day = try std.fmt.parseInt(i16, item.basename[4..], 10);
        if (max < day) max = day;
    }

    return max;
}

test "highest_day_folder_in_src" {
    var tmp = tmp_dir(.{ .iterate = true });
    defer tmp.cleanup();

    try tmp.dir.makeDir("day_001");
    try tmp.dir.makeDir("daY_002");
    try tmp.dir.makeDir("DAY_003");
    try tmp.dir.makeDir("dAy_009");
    try tmp.dir.makeDir("day_010");

    // Invalid dirs
    try tmp.dir.makeDir("day_03");
    try tmp.dir.makeDir("day9999");
    try tmp.dir.makeDir("pepes");
    try tmp.dir.makeDir("69__420");

    const result = try highest_day_folder_in_src(tmp.dir, &testing.allocator);

    try expect(result == 10);
}
