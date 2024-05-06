const std = @import("std");
const Exercise = @import("./Exercise.zig");
const Predefined = @import("./Predefined.zig");
const Configuration = @This();

const ConfigFile = struct {
    exercises: []Exercise,
    predefineds: ?[]Predefined,
};

day: u16,
exercises: []Exercise,
parsed_json: ?std.json.Parsed(ConfigFile) = null,
arena: *const std.heap.ArenaAllocator,

fn init(self: Configuration, json: []const u8) !void {
    self.arena = &std.heap.ArenaAllocator.init(std.heap.GeneralPurposeAllocator);
    const allocator = self.arena.allocator();

    var dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
    defer dir.close();
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    self.day = highest_day_folder_in_src(dir, gpa.allocator());

    self.parsed_json = try self.parse_json(allocator, json);
    self.exercises = self.parsed_json.?.value.exercises;

    var predefineds = std.AutoHashMap([]const u8, Predefined).init(allocator);
    defer predefineds.deinit();

    for (self.parsed_json.?.value.predefineds.?) |predefined| {
        predefineds.put(predefined.name, predefined);
    }

    while (predefineds.valueIterator().next()) |predefined| {
        if (predefined.predefineds == null) continue;

        for (predefined.predefineds) |p| {
            predefined.merge(predefineds.get(p));
        }
    }

    for (self.exercises) |exercise| {
        if (exercise.predefineds == null) continue;

        for (exercise.predefineds) |p| {
            exercise.add_predefined(predefineds.get(p));
        }
    }
}

fn parse_json(self: *Configuration, allocator: *const std.mem.Allocator, json: []const u8) !std.json.Parsed(Configuration) {
    _ = self;

    // Actual useful logging on error because zig refuses
    var diagnostics = std.json.Diagnostics{};
    errdefer std.debug.print("\n\n\n\nhuuuuuuuuuuuuuuu\n\n\n\n\n{}", .{diagnostics.getLine()});

    // Remember to add diagnostics
    var scanner = std.json.Scanner.initCompleteInput(allocator.*, json);
    scanner.enableDiagnostics(&diagnostics);
    defer scanner.deinit();

    return try std.json.parseFromTokenSource(Configuration, allocator.*, &scanner, .{});
}

fn deinit(self: *Configuration) void {
    self.arena.deinit();
}

fn highest_day_folder_in_src(dir: std.fs.Dir, allocator: *const std.mem.Allocator) !u16 {
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var max: u16 = 0;
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
        const day = try std.fmt.parseInt(u16, item.basename[4..], 10);
        if (max < day) max = day;
    }

    return max;
}

test "highest_day_folder_in_src" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
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

    const result = try highest_day_folder_in_src(tmp.dir, &std.testing.allocator);

    try std.testing.expect(result == 10);
}

test "parse_json" {
    const json = try std.fs.cwd().readFileAlloc(std.testing.allocator, "assets/testing/dsa.test.json", 10_000);
    defer std.testing.allocator.free(json);

    const pub_len_prop = Property{ .name = "length", .type = "number", .scope = "public" };
    var len_predef_props = [_]Property{pub_len_prop};

    var prepend_arg_names = [_][]const u8{"item"};
    var prepend_arg_types = [_][]const u8{"Generic<T>"};
    const prepend_method = Method{ .name = "prepend", .return_type = "void", .arg_names = prepend_arg_names[0..], .arg_types = prepend_arg_types[0..] };
    var list_predef_methods = [_]Method{prepend_method};
    var list_predef_predefineds = [_][]const u8{"length_property"};

    var get_arg_names = [_][]const u8{ "key", "value" };
    var get_arg_types = [_][]const u8{ "Generic<K>", "Generic<V>" };
    const lru_get_method = Method{ .name = "get", .return_type = "V | undefined", .arg_names = get_arg_names[0..], .arg_types = get_arg_types[0..] };
    var lru_methods = [_]Method{lru_get_method};

    const private_len_prop = Property{ .name = "length", .type = "number", .scope = "private" };
    var lru_props = [_]Property{private_len_prop};

    var bubble_arg_names = [_][]const u8{"arr"};
    var bubble_arg_types = [_][]const u8{"Array<number>"};

    var predefineds = [_]Predefined{
        Predefined{ .name = "length_property", .type = PredefinedType.property, .properties = len_predef_props[0..] },
        Predefined{ .name = "list_interface", .type = PredefinedType.class, .methods = list_predef_methods[0..], .predefineds = list_predef_predefineds[0..] },
    };

    var exercises = [_]Exercise{
        Exercise{ .name = "LRU", .generic = "<K, V>", .type = ExerciseType.class, .methods = lru_methods[0..], .properties = lru_props[0..] },
        Exercise{ .name = "BubbleSort", .type = ExerciseType.method, .fn_name = "bubble_sort", .return_type = "void", .arg_names = bubble_arg_names[0..], .arg_types = bubble_arg_types[0..] },
    };

    const expected = Configuration{
        .predefineds = predefineds[0..],
        .exercises = exercises[0..],
    };

    var cfg = Input{};
    var allocator = std.testing.allocator;

    try cfg.init(&allocator, json);
    defer cfg.deinit();

    try std.testing.expect(cfg.value != null);
    try std.testing.expectEqualDeep(expected.predefineds, cfg.value.?.predefineds);
    try std.testing.expectEqualDeep(expected.exercises, cfg.value.?.exercises);
}
