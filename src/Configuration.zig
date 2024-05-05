const std = @import("std");
const ConfigFile = @import("./ConfigFile.zig");

pub const ConfigurationError = error{ NotInitialized, UnsupportedPredefined };

fn string_fmt(allocator: *std.mem.Allocator, comptime fmt: []const u8, args: anytype) std.fmt.AllocPrintError![]u8 {
    return std.fmt.allocPrint(allocator.*, fmt, args);
}

fn highest_day_folder_in_src(dir: std.fs.Dir, allocator: *const std.mem.Allocator) !u16 {
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

pub const Configuration = struct {
    predefineds: ?[]Predefined = null,
    exercises: ?[]Exercise = null,

    fn from_json(json: *ConfigFile.JsonInput, allocator: *std.mem.Allocator) Configuration {
        var predefineds: []Predefined = std.ArrayList(Predefined).init(allocator);
        defer predefineds.deinit();

        for (json.parsed.?.predefineds) |predefined| {
            predefineds.append(Predefined.from_json(predefined));
        }

        for (predefineds) |predefined| {
            if (predefined.predefined_names == null) continue;
            // TODO: merge from list
        }

        var exercises = std.ArrayList(Predefined).init(allocator);
        defer exercises.deinit();

        for (json.parsed.?.exercises) |exercise| {
            _ = exercise;
        }
    }
};

const PredefinedType = union(enum) {
    Class: Class,
    Method: Method,
    Property: Parameter,
};

const Predefined = struct {
    name: []const u8,
    inner: PredefinedType,
    predefined_names: ?[][]const u8 = null,

    fn from_json(json: *ConfigFile.JsonPredefined) !Predefined {
        return Predefined{
            .name = json.name,
            .predefined_names = json.predefineds,
            .inner = switch (json.type) {
                ConfigFile.JsonPredefinedType.property => Parameter.from_json(json),
                ConfigFile.JsonPredefinedType.method => Method.from_json(json),
                ConfigFile.JsonPredefinedType.class => Class{
                    .name = json.name,
                    .methods = for (json.methods) |m| Method.from_json(m),
                    .properties = for (json.properties) |m| Method.from_json(m),
                },
                else => ConfigurationError.UnsupportedPredefined,
            },
        };
    }

    // TODO: Implement
    fn merge(self: Predefined, other: *Predefined) void {
        _ = self;
        _ = other;
    }
};

const Exercise = struct {
    type: ExerciseType,
    predefineds: []Predefined,
};

const Class = struct {
    name: []u8,
    methods: []Method,
    properties: []Parameter,

    fn params_to_string(self: Class, allocator: *std.mem.Allocator) ![]u8 {
        var string: []u8 = undefined;
        for (self.properties) |p| {
            string += "\t";
            string += p.to_string(allocator);
            string += ",\r\n\t";
        }

        // Trim trailing "\r\n\t"
        string = string[0 .. string.len - 3];

        return string;
    }

    fn methods_to_string(self: Class, allocator: *std.mem.Allocator) ![]u8 {
        var string: []u8 = undefined;
        for (self.methods) |m| {
            string += "\t";
            string += m.to_string(allocator);
            string += "{{\n\n}}\n\n";
        }

        // Trim trailing "\n\n"
        string = string[0 .. string.len - 2];

        return string;
    }

    pub fn to_string(self: Class, allocator: *std.mem.Allocator) []u8 {
        const template =
            \\ const {s} = struct {{
            \\     {s}
            \\ 
            \\     {s}
            \\ }}
        ;

        return string_fmt(allocator, template, .{ self.name, self.params_to_string(allocator), self.methods_to_string(allocator) });
    }

    pub fn add_predefined(self: Class, predefined: *Predefined) void {
        switch (predefined) {
            .class => self.merge(predefined.class),
            .method => self.methods += predefined.method,
            .param => self.properties += predefined.property,
        }
    }

    fn merge(self: Class, other: *Class) void {
        for (other.properties) |p| {
            self.properties += p;
        }

        for (other.methods) |m| {
            self.methods += m;
        }
    }
};

const Method = struct {
    name: []u8,
    access_modifier: AccessModifier,
    parameters: []Parameter,

    fn input_params_to_string(self: Method, allocator: *std.mem.Allocator) ![]u8 {
        var string: []u8 = undefined;
        for (self.parameters) |p| {
            if (p.direction == ParameterDirection.Out) continue;
            string += p.to_string(allocator);
            string += ", ";
        }

        // Trim trailing ", "
        string = string[0 .. string.len - 2];

        return string;
    }

    fn output_param_to_string(self: Method, allocator: *std.mem.Allocator) ![]u8 {
        const output_param: Parameter = undefined;
        for (self.parameters) |p| {
            if (p.direction == ParameterDirection.Out) {
                output_param = p;
                break;
            }
        }
        return output_param.to_string(allocator);
    }

    pub fn to_string(self: Method, allocator: *std.mem.Allocator) []u8 {
        return switch (self.access_modifier) {
            AccessModifier.Private => string_fmt(allocator, "fn {s}({s}) {s}", .{ self.name, self.input_params_to_string(allocator), self.output_param_to_string(allocator) }),
            AccessModifier.Public => string_fmt(allocator, "pub fn {s}({s}) {s}", .{ self.name, self.input_params_to_string(allocator), self.output_param_to_string(allocator) }),
        };
    }
};

const ExerciseType = union(enum) {
    class: Class,
    method: Method,

    pub fn to_string(self: Exercise, allocator: *std.mem.Allocator) ![]u8 {
        return switch (self) {
            .class => string_fmt(allocator, "export {s} {{ }}", .{self.class.to_string(allocator)}),
            .method => string_fmt(allocator, "export {s} {{ }}", .{self.method.to_string(allocator)}),
        };
    }
};

const ParameterDirection = enum { In, Out };
const Parameter = struct {
    direction: ParameterDirection,
    name: []u8,
    type: []u8,

    pub fn to_string(self: Parameter, allocator: *std.mem.Allocator) []u8 {
        return switch (self.direction) {
            ParameterDirection.In => string_fmt(allocator, "{s}: {s}", .{ self.name, self.type }),
            ParameterDirection.Out => string_fmt(allocator, "{s}", .{self.type}),
        };
    }
};

const AccessModifier = enum {
    Private,
    Public,
};
