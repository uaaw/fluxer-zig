const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "fluxer",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const fluxer_mod = b.addModule("fluxer", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const examples_step = b.step("examples", "Build all examples");
    const example_names = [_][]const u8{
        "basic",
        "basic_bot",
        "raw_request",
        "shard_control",
    };
    inline for (example_names) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path("example/" ++ name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("fluxer", fluxer_mod);
        examples_step.dependOn(&exe.step);
    }
}
