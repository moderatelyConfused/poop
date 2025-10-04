const std = @import("std");

const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const install_step = b.getInstallStep();
    const target = b.standardTargetOptions(.{
        .whitelist = &.{
            .{ .cpu_arch = .aarch64, .os_tag = .macos },
            .{ .cpu_arch = .aarch64, .os_tag = .ios },
            .{ .cpu_arch = .x86_64, .os_tag = .macos },
            .{ .cpu_arch = .x86_64, .os_tag = .ios },
            .{ .cpu_arch = .x86_64, .os_tag = .linux },
        },
    });
    const optimize = b.standardOptimizeOption(.{});
    const root_source_file = b.path("src/root.zig");
    const version: std.SemanticVersion = try .parse(manifest.version);

    // Either:
    // - Private root module on Linux (for running fmt/doc steps in CI/CD)
    // - Public root module on Darwin
    const root_mod = if (target.result.os.tag == .linux) b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = root_source_file,
        .strip = b.option(bool, "strip", "Strip binary"),
    }) else blk: {
        const sdk_path = std.zig.system.darwin.getSdk(b.allocator, &target.result) orelse @panic("Failed to find SDK!");
        const root_mod = b.addModule("scoop", .{
            .target = target,
            .link_libc = true,
            .optimize = optimize,
            .root_source_file = root_source_file,
            .strip = b.option(bool, "strip", "Strip binary"),
        });
        root_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "System/Library/PrivateFrameworks" }) });
        root_mod.linkFramework("kperf", .{});
        root_mod.linkFramework("kperfdata", .{});
        break :blk root_mod;
    };

    // Library
    const lib = b.addLibrary(.{
        .name = "scoop",
        .version = version,
        .root_module = root_mod,
    });
    b.installArtifact(lib);

    // Documentation
    const docs_step = b.step("doc", "Emit documentation");

    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = lib.getEmittedDocs(),
    });
    docs_step.dependOn(&docs_install.step);

    // Example suite
    const examples_step = b.step("run", "Run example suite");

    const example_opt = b.option(Example, "example", "Run example");

    inline for (comptime std.meta.tags(Example)) |EXAMPLE| {
        const example_exe = b.addExecutable(.{
            .name = @tagName(EXAMPLE),
            .version = version,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .root_source_file = b.path(EXAMPLES_DIR ++ @tagName(EXAMPLE) ++ ".zig"),
                .imports = &.{
                    .{ .name = "scoop", .module = root_mod },
                },
            }),
        });

        if (example_opt == null or example_opt.? == EXAMPLE) {
            const example_run = b.addRunArtifact(example_exe);
            examples_step.dependOn(&example_run.step);
        }
    }

    // Formatting check
    const fmt_step = b.step("fmt", "Check formatting");

    const fmt = b.addFmt(.{
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
            EXAMPLES_DIR,
        },
        .check = true,
    });
    fmt_step.dependOn(&fmt.step);
    install_step.dependOn(fmt_step);

    // Compilation check for ZLS Build-On-Save
    // See: https://zigtools.org/zls/guides/build-on-save/
    const check_step = b.step("check", "Check compilation");
    const check_exe = b.addExecutable(.{
        .name = "scoop",
        .version = version,
        .root_module = root_mod,
    });
    check_step.dependOn(&check_exe.step);
}

const EXAMPLES_DIR = "examples/";

const Example = enum {
    function,
    process,
};
