const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const wayland_support = b.option(bool, "wayland", "Build with Wayland support") orelse false;

    const glfw_bindings = b.addTranslateC(.{
        .link_libc = true,
        .target = target,
        .root_source_file = b.path("external/glfw/include/GLFW/glfw3.h"),
        .optimize = optimize,
    });

    glfw_bindings.addIncludePath(b.path("external/glfw/include"));

    const glfw = glfw_bindings.createModule();

    const glfw3 = b.addLibrary(.{
        .name = "glfw3",
        .linkage = .static,
        .version = .{ .major = 3, .minor = 3, .patch = 0 },
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const glfw3_common_src = &[_][]const u8{
        "context.c",
        "init.c",
        "input.c",
        "monitor.c",
        "platform.c",
        "vulkan.c",
        "window.c",
        "egl_context.c",
        "osmesa_context.c",
        "null_init.c",
        "null_monitor.c",
        "null_window.c",
        "null_joystick.c",
    };

    const glfw3_win32_src = &[_][]const u8{
        "win32_init.c",
        "win32_joystick.c",
        "win32_monitor.c",
        "win32_time.c",
        "win32_thread.c",
        "win32_window.c",
        "win32_module.c",
        "wgl_context.c",
    };

    const glfw3_linux_x11_src = &[_][]const u8{
        "x11_init.c",
        "x11_monitor.c",
        "x11_window.c",
        "xkb_unicode.c",
        "posix_time.c",
        "posix_thread.c",
        "posix_module.c",
        "glx_context.c",
        "linux_joystick.c",
        "posix_poll.c",
    };

    const glfw3_linux_wayland_src = &[_][]const u8{
        "wl_init.c",
        "wl_monitor.c",
        "wl_window.c",
    };

    const glfw3_cocoa_src = &[_][]const u8{
        "cocoa_init.m",
        "cocoa_joystick.m",
        "cocoa_monitor.m",
        "cocoa_window.m",
        "cocoa_time.c",
        "nsgl_context.m",
        "posix_thread.c",
        "posix_module.c",
    };

    const glfw3_win32_macros = &[_][]const u8{ "_GLFW_WIN32", "UNICODE", "_UNICODE", "_CRT_SECURE_NO_WARNINGS" };
    const glfw3_linux_x11_macros = &[_][]const u8{ "_GLFW_X11", "_DEFAULT_SOURCE" };
    const glfw3_linux_wayland_macros = &[_][]const u8{"_GLFW_WAYLAND"};
    const glfw3_cocoa_macros = &[_][]const u8{"_GLFW_COCOA"};

    const glfw3_win32_libs = &[_][]const u8{ "gdi32", "user32", "kernel32", "shell32" };
    const glfw3_linux_x11_libs = &[_][]const u8{ "X11", "Xrandr", "Xi", "Xcursor", "Xinerama", "dl", "m", "pthread", "rt" };
    const glfw3_linux_wayland_libs = &[_][]const u8{ "wayland-client", "wayland-cursor", "wayland-egl", "EGL" };
    const glfw3_cocoa_libs = &[_][]const u8{ "Cocoa", "IOKit", "CoreVideo", "QuartzCore" };

    const glfw3_src = switch (target.result.os.tag) {
        .windows => glfw3_common_src ++ glfw3_win32_src,
        .linux => if (wayland_support) glfw3_common_src ++ glfw3_linux_x11_src ++ glfw3_linux_wayland_src else glfw3_common_src ++ glfw3_linux_x11_src,
        .macos => glfw3_common_src ++ glfw3_cocoa_src,
        else => @panic("[glfw src config]: Unsupported OS"),
    };

    const glfw3_macros = switch (target.result.os.tag) {
        .windows => glfw3_win32_macros,
        .linux => if (wayland_support) glfw3_linux_x11_macros ++ glfw3_linux_wayland_macros else glfw3_linux_x11_macros,
        .macos => glfw3_cocoa_macros,
        else => @panic("[glfw macro config]: Unsupported OS"),
    };

    const system_libs = switch (target.result.os.tag) {
        .windows => glfw3_win32_libs,
        .linux => if (wayland_support) glfw3_linux_x11_libs ++ glfw3_linux_wayland_libs else glfw3_linux_x11_libs,
        .macos => glfw3_cocoa_libs,
        else => @panic("[glfw system libs config]: Unsupported OS"),
    };

    for (glfw3_macros) |macro| {
        glfw3.root_module.addCMacro(macro, "1");
    }

    glfw3.addIncludePath(b.path("external/glfw/include"));
    glfw3.addCSourceFiles(.{ .files = glfw3_src, .root = b.path("external/glfw/src"), .flags = &.{} });

    for (system_libs) |src| {
        glfw3.linkSystemLibrary(src);
    }

    const mod = b.addModule("wave", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "glfw", .module = glfw },
        },
    });

    mod.linkLibrary(glfw3);

    const exe = b.addExecutable(.{
        .name = "wave",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,

            .imports = &.{
                .{ .name = "wave", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
