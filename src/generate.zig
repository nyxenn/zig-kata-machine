const std = @import("std");
const cfg = @import("configuration.zig");

pub fn main() !void {
    try generate_katas();
}

fn string_fmt(allocator: *std.mem.Allocator, comptime fmt: []const u8, args: anytype) std.fmt.AllocPrintError![]u8 {
    return std.fmt.allocPrint(allocator.*, fmt, args);
}

fn generate_katas() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var config = cfg.Configuration{};
    try config.init(&allocator);
    defer config.deinit();

    std.debug.print("\n\nParsed json:\n{}\n", .{try config.value()});
}

// Models for own use
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
const Predefined = union(enum) { class: Class, method: Method, property: Parameter };

const Exercise = struct { type: ExerciseType, predefineds: []Predefined };

// const Configuration = struct { predefineds: []Predefined, exercises: []Exercise };
