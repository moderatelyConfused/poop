const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const target_os = target.result.os.tag;

    // Dependencies
    const scoop_dep_lazy = if (target_os.isDarwin()) b.lazyDependency("scoop", .{
        .target = target,
        .optimize = optimize,
    }) else null;
    const scoop_mod = if (scoop_dep_lazy) |scoop_dep| scoop_dep.module("scoop") else undefined;

    // Executable
    const exe_step = b.step("exe", "Run executable");

    const exe = b.addExecutable(.{
        .name = "poop",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = b.option(bool, "strip", "strip the binary"),
        }),
    });

    switch (target_os) {
        .linux => {},
        .macos => exe.root_module.addImport("scoop", scoop_mod),
        else => std.debug.panic("Unsupported OS: {s}", .{@tagName(target_os)}),
    }

    b.installArtifact(exe);

    const exe_run = b.addRunArtifact(exe);
    if (b.args) |args| {
        exe_run.addArgs(args);
    }
    exe_step.dependOn(&exe_run.step);

    const release = b.step("release", "make an upstream binary release");
    const release_targets = [_]std.Target.Query{
        .{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
        },
        .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
        },
        .{
            .cpu_arch = .x86,
            .os_tag = .linux,
        },
        .{
            .cpu_arch = .riscv64,
            .os_tag = .linux,
        },
    };
    for (release_targets) |target_query| {
        const resolved_target = b.resolveTargetQuery(target_query);
        const t = resolved_target.result;
        const rel_exe = b.addExecutable(.{
            .name = "poop",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = resolved_target,
                .optimize = .ReleaseSafe,
                .strip = true,
            }),
        });

        const install = b.addInstallArtifact(rel_exe, .{});
        install.dest_dir = .prefix;
        install.dest_sub_path = b.fmt("{s}-{s}-{s}", .{
            @tagName(t.cpu.arch), @tagName(t.os.tag), rel_exe.name,
        });

        release.dependOn(&install.step);
    }
}
