const std = @import("std");

pub const ConfigurationError = error{NotInitialized};

pub const JsonInput = struct {
    parsed: ?std.json.Parsed(JsonConfiguration) = null,
    value: ?JsonConfiguration = null,

    pub fn init(self: *JsonInput, allocator: *std.mem.Allocator, json: []u8) !void {
        self.parsed = try self.parse_json(allocator, json);
        self.value = self.parsed.?.value;
    }

    fn parse_json(self: *JsonInput, allocator: *std.mem.Allocator, json: []u8) !std.json.Parsed(JsonConfiguration) {
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

    fn deinit(self: *JsonInput) void {
        if (self.parsed != null) {
            self.parsed.?.deinit();
        }
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

pub const JsonPredefinedType = enum {
    class,
    property,
    method,
};

pub const JsonPredefined = struct {
    name: []const u8,
    type: JsonPredefinedType,
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
        JsonPredefined{ .name = "length_property", .type = JsonPredefinedType.property, .properties = len_predef_props[0..] },
        JsonPredefined{ .name = "list_interface", .type = JsonPredefinedType.class, .methods = list_predef_methods[0..], .predefineds = list_predef_predefineds[0..] },
    };

    var exercises = [_]JsonExercise{
        JsonExercise{ .name = "LRU", .generic = "<K, V>", .type = "class", .methods = lru_methods[0..], .properties = lru_props[0..] },
        JsonExercise{ .name = "BubbleSort", .type = "fn", .fn_name = "bubble_sort", .return_type = "void", .arg_names = bubble_arg_names[0..], .arg_types = bubble_arg_types[0..] },
    };

    const expected = JsonConfiguration{
        .predefineds = predefineds[0..],
        .exercises = exercises[0..],
    };

    var cfg = JsonInput{};
    var allocator = std.testing.allocator;

    try cfg.init(&allocator, json);
    defer cfg.deinit();

    try std.testing.expect(cfg.value != null);
    try std.testing.expectEqualDeep(expected.predefineds, cfg.value.?.predefineds);
    try std.testing.expectEqualDeep(expected.exercises, cfg.value.?.exercises);
}
