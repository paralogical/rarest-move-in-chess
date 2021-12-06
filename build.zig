const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        const exe = b.addExecutable(.{
            .name = "chesspgn",
            .root_source_file = .{ .path = "src/chessmoves.zig" },
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibC();
        exe.linkSystemLibrary("System");

        // enable profiling (if you pass env var CPUPROFILE=name.prof when running)
        // exe.addIncludePath(.{ .path = "/usr/local/Cellar/gperftools/2.9.1_1/lib" });
        // exe.linkSystemLibrary("profiler");

        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/chessmoves.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
