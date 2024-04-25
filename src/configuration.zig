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

    pub fn init(self: *Configuration, allocator: *std.mem.Allocator) !void {
        self.json = try self.parse_json(allocator);
        self.day = try self.highest_day_folder_in_src(allocator);

        self.initialized = true;
    }

    fn parse_json(self: *Configuration, allocator: *std.mem.Allocator) !std.json.Parsed(JsonConfiguration) {
        _ = self;

        const json = try std.fs.cwd().readFileAlloc(allocator.*, "dsa.json", 25_000);
        defer allocator.free(json);

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

    fn highest_day_folder_in_src(self: *Configuration, allocator: *const std.mem.Allocator) !u16 {
        _ = self;

        var dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(allocator.*);
        defer walker.deinit();

        var max: u16 = 0;
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
            const day = try std.fmt.parseInt(u16, item.basename[4..], 10);
            if (max < day) max = day;
        }

        return max;
    }

    test "highest_day_folder_in_src" {
        var tmp = std.testing.tmp_dir(.{ .iterate = true });
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
};

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
    methods: ?[]JsonMethod = null,
    properties: ?[]JsonProperty = null,
    predefineds: ?[][]const u8 = null,
    arg_types: ?[][]const u8 = null,
    arg_names: ?[][]const u8 = null,
    return_type: ?[]const u8 = null,
};

pub const JsonConfiguration = struct { predefineds: []JsonPredefined, exercises: []JsonExercise };
