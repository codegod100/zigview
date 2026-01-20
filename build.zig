const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const webview = b.dependency("webview", .{
        .target = target,
        .optimize = optimize,
    });

    const webview_module = webview.module("webview");

    const zigview_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigview_module.addImport("webview", webview_module);

    const exe = b.addExecutable(.{
        .name = "zigview",
        .root_module = zigview_module,
    });

    exe.linkLibC();
    exe.linkLibrary(webview.artifact("webviewStatic"));
    b.installArtifact(exe);

    // Copy assets to the installation directory
    const install_assets = b.addInstallDirectory(.{
        .source_dir = b.path("src"),
        .install_dir = .{ .custom = "bin/src" },
        .install_subdir = "",
        .exclude_extensions = &.{ "zig" },
    });
    b.getInstallStep().dependOn(&install_assets.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run app");
    run_step.dependOn(&run_cmd.step);

    // AppImage step
    const appimage_step = b.step("appimage", "Build AppImage");
    const appimage_cmd = b.addSystemCommand(&.{ "bash", "-c" });
    const appimage_script =
        \\set -e
        \\APPDIR="zig-out/zigview.AppDir"
        \\rm -rf "$APPDIR"
        \\mkdir -p "$APPDIR/usr/bin"
        \\mkdir -p "$APPDIR/usr/share/applications"
        \\mkdir -p "$APPDIR/usr/share/icons/hicolor/128x128/apps"
        \\cp -r zig-out/bin/* "$APPDIR/usr/bin/"
        \\cp zigview.desktop "$APPDIR/"
        \\cp zigview.desktop "$APPDIR/usr/share/applications/"
        \\cp zigview.png "$APPDIR/"
        \\cp zigview.png "$APPDIR/usr/share/icons/hicolor/128x128/apps/"
        \\ln -sf usr/bin/zigview "$APPDIR/AppRun"
        \\appimagetool "$APPDIR" "ZigView-x86_64.AppImage"
    ;
    appimage_cmd.addArg(appimage_script);
    appimage_cmd.step.dependOn(b.getInstallStep());
    appimage_step.dependOn(&appimage_cmd.step);
}
