const std = @import("std");
const WebView = @import("webview").WebView;

pub fn main() !void {
    const w = WebView.create(true, null);
    defer w.destroy() catch {};

    try w.setTitle("ZigView App");
    w.setSize(800, 600, .none) catch |err| {
        std.debug.print("Warning: setSize failed with error: {}\n", .{err});
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "ls", "-1" },
    });

    var json = try std.ArrayList(u8).initCapacity(allocator, 1024);
    try json.writer(allocator).print("[", .{});

    var first = true;
    var it = std.mem.splitScalar(u8, result.stdout, '\n');
    while (it.next()) |file| {
        if (file.len == 0) continue;
        if (!first) try json.writer(allocator).print(",", .{});
        first = false;
        try json.writer(allocator).print("\"{s}\"", .{file});
    }

    try json.writer(allocator).print("]", .{});
    const files_json = try allocator.dupeZ(u8, json.items);

    const html_content = try std.fs.cwd().readFileAlloc(allocator, "src/index.html", 1024 * 1024);

    const files_placeholder = "const files = [];";
    const new_script = try std.fmt.allocPrint(allocator, "const files = {s};", .{files_json});

    const final_html = try std.mem.replaceOwned(u8, allocator, html_content, files_placeholder, new_script);

    try w.setHtml(try allocator.dupeZ(u8, final_html));
    try w.run();
}
