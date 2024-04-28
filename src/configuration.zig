const std = @import("std");

pub const ConfigurationError = error{NotInitialized};

pub const Configuration = struct {
    json: std.json.Parsed(JsonConfiguration) = undefined,
    day: u16 = undefined,

    initialized: bool = false,

    pub fn value(self: *Configuration) !JsonConfiguration {
        if (!self.initialized) {
            const msg =
                \\ Error trying to get value from configuration.
                \\ Did you forget to call .init() ?
            ;
            std.debug.print(msg, .{});
            return ConfigurationError.NotInitialized;
        }

        return self.json.value;
    }

    pub fn init(self: *Configuration, allocator: *std.mem.Allocator, json: []u8) !void {
        var dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
        defer dir.close();

        self.json = try self.parse_json(allocator, json);
        self.day = try self.highest_day_folder_in_src(dir, allocator);

        self.initialized = true;
    }

    fn parse_json(self: *Configuration, allocator: *std.mem.Allocator, json: []u8) !std.json.Parsed(JsonConfiguration) {
        _ = self;

        // Actual useful logging on error because zig refuses
        var diagnostics = std.json.Diagnostics{};
        errdefer std.debug.print("\n\n\n\nhuuuuuuuuuuuuuuu\n\n\n\n\n{}", .{diagnostics.getLine()});

        // Remember to add diagnostics
        var scanner = std.json.Scanner.initCompleteInput(allocator.*, json);
        scanner.enableDiagnostics(&diagnostics);
        defer scanner.deinit();

        return try std.json.parseFromTokenSource(JsonConfiguration, allocator.*, &scanner, .{});
    }

    pub fn deinit(self: *Configuration) void {
        self.json.deinit();
    }

    fn highest_day_folder_in_src(self: *Configuration, dir: std.fs.Dir, allocator: *const std.mem.Allocator) !u16 {
        _ = self;

        var walker = try dir.walk(allocator.*);
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
};

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

    var cfg = Configuration{};
    const result = try cfg.highest_day_folder_in_src(tmp.dir, &std.testing.allocator);

    try std.testing.expect(result == 10);
}

test "parse_json" {
    const json = try std.fs.cwd().readFileAlloc(std.testing.allocator, "assets/testing/dsa.test.json", 10_000);
    defer std.testing.allocator.free(json);

    const pub_len_prop = JsonProperty{ .name = "length", .type = "number", .scope = "public" };
    var len_predef_props = [_]JsonProperty{pub_len_prop};

    var prepend_arg_names = [_][]const u8{"item"};
    var prepend_arg_types = [_][]const u8{"Generic<T>"};
    const prepend_method = JsonMethod{ .name = "prepend", .return_type = "void", .arg_names = prepend_arg_names[0..], .arg_types = prepend_arg_types[0..] };
    var list_predef_methods = [_]JsonMethod{prepend_method};
    var list_predef_predefineds = [_][]const u8{"length_property"};

    var get_arg_names = [_][]const u8{ "key", "value" };
    var get_arg_types = [_][]const u8{ "Generic<K>", "Generic<V>" };
    const lru_get_method = JsonMethod{ .name = "get", .return_type = "V | undefined", .arg_names = get_arg_names[0..], .arg_types = get_arg_types[0..] };
    var lru_methods = [_]JsonMethod{lru_get_method};

    const private_len_prop = JsonProperty{ .name = "length", .type = "number", .scope = "private" };
    var lru_props = [_]JsonProperty{private_len_prop};

    var bubble_arg_names = [_][]const u8{"arr"};
    var bubble_arg_types = [_][]const u8{"Array<number>"};

    var predefineds = [_]JsonPredefined{
        JsonPredefined{ .name = "length_property", .properties = len_predef_props[0..] },
        JsonPredefined{ .name = "list_interface", .methods = list_predef_methods[0..], .predefineds = list_predef_predefineds[0..] },
    };

    var exercises = [_]JsonExercise{
        JsonExercise{ .name = "LRU", .generic = "<K, V>", .type = "class", .methods = lru_methods[0..], .properties = lru_props[0..] },
        JsonExercise{ .name = "BubbleSort", .type = "fn", .fn_name = "bubble_sort", .return_type = "void", .arg_names = bubble_arg_names[0..], .arg_types = bubble_arg_types[0..] },
    };

    const expected = JsonConfiguration{
        .predefineds = predefineds[0..],
        .exercises = exercises[0..],
    };

    var cfg = Configuration{};
    var allocator = std.testing.allocator;

    try cfg.init(&allocator, json);
    defer cfg.deinit();

    try std.testing.expectEqualDeep(expected, cfg.json.value);
}

pub const JsonProperty = struct {
    name: []const u8,
    type: []const u8,
    scope: []const u8,
};

pub const JsonMethod = struct {
    name: []const u8,
    arg_types: [][]const u8,
    arg_names: [][]const u8,
    return_type: []const u8,
};

pub const JsonPredefined = struct {
    name: []const u8,
    properties: ?[]JsonProperty = null,
    methods: ?[]JsonMethod = null,
    predefineds: ?[][]const u8 = null,
};

// TODO: Might want to clean up the input json... cba tho
pub const JsonExercise = struct {
    name: []const u8,
    fn_name: ?[]const u8 = null,
    generic: ?[]const u8 = null,
    type: ?[]const u8 = null,
    return_type: ?[]const u8 = null,
    methods: ?[]JsonMethod = null,
    properties: ?[]JsonProperty = null,
    predefineds: ?[][]const u8 = null,
    arg_types: ?[][]const u8 = null,
    arg_names: ?[][]const u8 = null,
};

pub const JsonConfiguration = struct {
    predefineds: []JsonPredefined,
    exercises: []JsonExercise,
};
