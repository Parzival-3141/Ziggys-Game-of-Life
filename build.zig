const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zgol",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath("deps/SDL2/include");

    const t = exe.target_info.target;
    switch (t.os.tag) {
        .windows => {
            const install_SDL = b.addInstallBinFile(.{ .path = "deps/SDL2/lib/SDL2.dll" }, "SDL2.dll");
            exe.step.dependOn(&install_SDL.step);
            exe.addLibraryPath("deps/SDL2/lib");
            exe.linkSystemLibrary("SDL2");
        },
        .macos => {
            exe.addFrameworkPath("/Library/Frameworks");
            exe.linkFramework("SDL2");
        },
        else => @panic("only Windows and macOS supported for now"),
    }

    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
