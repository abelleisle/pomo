const std = @import("std");

pub fn build(b: *std.Build) void {
    //////////////////
    //  BUILD OPTS  //
    //////////////////
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    ///////////////
    //  MODULES  //
    ///////////////
    const vaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    ///////////
    //  LIB  //
    ///////////
    const lib = b.addStaticLibrary(.{ .name = "pomo", .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize });

    b.installArtifact(lib);

    ///////////
    //  EXE  //
    ///////////
    const exe = b.addExecutable(.{
        .name = "pomo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("vaxis", vaxis.module("vaxis"));

    b.installArtifact(exe);

    ///////////
    //  RUN  //
    ///////////
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    ////////////
    //  TEST  //
    ////////////
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
