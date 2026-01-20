const std = @import("std");
const webview = @import("webview");
const WebView = webview.WebView;

var global_webview: ?WebView = null;

fn loadFilesCallback(_: [*:0]const u8, req: [*:0]const u8, _: ?*anyopaque) callconv(.c) void {
    const req_str = std.mem.span(req);
    std.debug.print("loadFilesCallback received: {s}\n", .{req_str});
    
    // Parse JSON array like ["path"] to extract the path
    // Simple parsing: strip brackets and quotes
    var path: []const u8 = ".";
    if (req_str.len > 4) { // Minimum: ["x"]
        // Find first quote after [
        if (std.mem.indexOf(u8, req_str, "\"")) |start| {
            if (std.mem.indexOfPos(u8, req_str, start + 1, "\"")) |end| {
                path = req_str[start + 1 .. end];
            }
        }
    }
    
    loadFiles(path);
}

pub fn main() !void {
    var w = WebView.create(true, null);
    defer w.destroy() catch {};
    global_webview = w;

    try w.setTitle("ZigView App");
    w.setSize(800, 600, .none) catch |err| {
        std.debug.print("Warning: setSize failed with error: {}\n", .{err});
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get executable directory to find assets
    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    const exe_dir_handle = try std.fs.openDirAbsolute(exe_dir, .{});
    var src_dir = try exe_dir_handle.openDir("src", .{});
    defer src_dir.close();

    // Bind JavaScript functions for reactive file navigation
    try w.bind("loadFilesFromZig", loadFilesCallback, null);

    // Read and embed all assets inline
    const styles = src_dir.readFileAlloc(allocator, "styles.css", 1024 * 1024) catch "";
    const app_js = src_dir.readFileAlloc(allocator, "app.js", 2 * 1024 * 1024) catch "";
    const bridge_js = src_dir.readFileAlloc(allocator, "bridge.js", 1024 * 1024) catch "";

    // Build complete HTML with embedded assets
    const html_content = try std.fmt.allocPrint(allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <title>ZigView</title>
        \\    <style>{s}</style>
        \\</head>
        \\<body>
        \\    <div id="elm-app"></div>
        \\    <script>{s}</script>
        \\    <script>{s}</script>
        \\</body>
        \\</html>
    , .{ styles, app_js, bridge_js });

    try w.setHtml(try allocator.dupeZ(u8, html_content));

    // Inject JavaScript to load initial files after page is ready
    try w.init(
        \\window.addEventListener('load', function() {
        \\    setTimeout(function() {
        \\        if (typeof loadFilesFromZig === 'function') {
        \\            loadFilesFromZig('.');
        \\        }
        \\    }, 100);
        \\});
    );

    try w.run();
}

fn escapeJsonString(s: []const u8, writer: anytype) !void {
    try writer.writeAll("\"");
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0x08 => try writer.writeAll("\\b"),
            0x0C => try writer.writeAll("\\f"),
            else => try writer.writeByte(c),
        }
    }
    try writer.writeAll("\"");
}

fn loadFiles(path: []const u8) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        std.debug.print("Error opening directory '{s}': {}\n", .{path, err});
        return;
    };
    defer dir.close();

    var json = std.array_list.Managed(u8).init(allocator);
    json.appendSlice("[") catch return;
    
    var iterator = dir.iterate();
    var first = true;
    while (iterator.next() catch |err| {
        std.debug.print("Error iterating directory: {}\n", .{err});
        return;
    }) |entry| {
        if (!first) json.appendSlice(",") catch return;
        first = false;
        
        const kind_str = switch (entry.kind) {
            .directory => "directory",
            else => "file",
        };
        
        json.writer().print("{{\"name\":", .{}) catch return;
        escapeJsonString(entry.name, json.writer()) catch return;
        json.writer().print(",\"kind\":\"{s}\"}}", .{kind_str}) catch return;
    }

    json.appendSlice("]") catch return;

    const files_json = allocator.dupeZ(u8, json.items) catch return;

    // Call JavaScript to update Elm with new file list
    const js_code_slice = std.fmt.allocPrint(allocator, "onFilesFromZig('{s}');", .{files_json}) catch return;
    const js_code = allocator.dupeZ(u8, js_code_slice) catch return;
    std.debug.print("Sending to Elm: {s}\n", .{files_json});

    if (global_webview) |gw| {
        gw.eval(js_code) catch |err| {
            std.debug.print("Error executing JavaScript: {}\n", .{err});
        };
    }
}
