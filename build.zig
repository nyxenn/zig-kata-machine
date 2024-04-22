const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.host; // b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Executable stuff",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "main.zig" },
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("main", "build main i guess");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .name = "Test stuff",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "main.zig" },
    });

    const test_cmd = b.addRunArtifact(tests);
    test_cmd.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "run testies");
    test_step.dependOn(&test_cmd.step);
}
