const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const plugin = b.addExecutable(.{
        .name = "cln4zig-plugin",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(plugin);

    const lib = b.addExecutable(.{
        .name = "cln4zig",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const rpc2_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/json_rpc/rpc_two.zig" },
        .target = target,
        .optimize = optimize,
    });
   const plugin_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/plugin.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    const run_main_tests = b.addRunArtifact(main_tests);
    const run_lib_tests = b.addRunArtifact(rpc2_tests);
    const run_plugin_tests = b.addRunArtifact(plugin_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_plugin_tests.step);
}
