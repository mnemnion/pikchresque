const std = @import("std");
const pikchresque = @import("pikchresque");

const html_header =
    "<!DOCTYPE html>\n" ++
    "<html lang=\"en-US\">\n" ++
    "<head>\n<title>PIKCHR Test</title>\n" ++
    "<style>\n" ++
    "  .hidden {\n" ++
    "     position: absolute !important;\n" ++
    "     opacity: 0 !important;\n" ++
    "     pointer-events: none !important;\n" ++
    "     display: none !important;\n" ++
    "  }\n" ++
    "</style>\n" ++
    "<script>\n" ++
    "  function toggleHidden(id){\n" ++
    "    for(var c of document.getElementById(id).children){\n" ++
    "      c.classList.toggle('hidden');\n" ++
    "    }\n" ++
    "  }\n" ++
    "</script>\n" ++
    "<meta charset=\"utf-8\">\n" ++
    "</head>\n" ++
    "<body>\n";

fn usage(stderr: *std.Io.Writer, argv0: []const u8) !void {
    try stderr.print("usage: {s} [OPTIONS] FILE ...\n", .{argv0});
    try stderr.writeAll(
        "Convert Pikchr input files into SVG.  Filename \"-\" means stdin.\n" ++
            "All output goes to stdout.\n" ++
            "Options:\n" ++
            "   --dark-mode      Generate \"dark mode\" output\n" ++
            "   --dont-stop      Process all files even if earlier files have errors\n" ++
            "   --svg-only       Emit raw SVG without the HTML wrapper\n",
    );
    try stderr.flush();
}

fn printEscapeHtml(stdout: *std.Io.Writer, text: []const u8) !void {
    var start: usize = 0;
    for (text, 0..) |c, idx| {
        switch (c) {
            '<', '>', '&' => {
                if (idx > start) try stdout.writeAll(text[start..idx]);
                switch (c) {
                    '<' => try stdout.writeAll("&lt;"),
                    '>' => try stdout.writeAll("&gt;"),
                    '&' => try stdout.writeAll("&amp;"),
                    else => unreachable,
                }
                start = idx + 1;
            },
            else => {},
        }
    }
    if (start < text.len) try stdout.writeAll(text[start..]);
}

fn readFile(init: std.process.Init, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (std.mem.eql(u8, path, "-")) {
        var stdin_buffer: [4096]u8 = undefined;
        var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buffer);
        return stdin_reader.interface.allocRemaining(allocator, .unlimited);
    }
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .unlimited);
}

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    if (args.len < 2) {
        try usage(stderr, args[0]);
        std.process.exit(1);
    }

    var svg_only = false;
    var dont_stop = false;
    var exit_code: u8 = 0;
    var options = pikchresque.PikOptions.default;
    var style: []const u8 = "";
    var html_header_pending = true;

    for (args[1..], 1..) |arg, arg_index| {
        if (arg.len > 1 and arg[0] == '-') {
            const option = if (arg[1] == '-') arg[2..] else arg[1..];
            if (std.mem.eql(u8, option, "dont-stop")) {
                dont_stop = true;
            } else if (std.mem.eql(u8, option, "dark-mode")) {
                style = "color:white;background-color:black;";
                options.dark_mode = true;
            } else if (std.mem.eql(u8, option, "svg-only")) {
                if (!html_header_pending) {
                    try stderr.print("the \"{s}\" option must come first\n", .{arg});
                    std.process.exit(1);
                }
                svg_only = true;
                options.plaintext_errors = true;
            } else {
                try stderr.print("unknown option: \"{s}\"\n", .{arg});
                try usage(stderr, args[0]);
                std.process.exit(1);
            }
            continue;
        }

        const input = readFile(init, allocator, arg) catch |err| {
            switch (err) {
                error.FileNotFound => try stderr.print("cannot open \"{s}\" for reading\n", .{arg}),
                else => return err,
            }
            continue;
        };
        defer allocator.free(input);

        const out = pikchresque.pikchr(allocator, input, "pikchr", options) catch |err| {
            switch (err) {
                error.OutOfMemory => try stderr.writeAll("pikchr() returns NULL.  Out of memory?\n"),
            }
            if (!dont_stop) std.process.exit(1);
            continue;
        };
        defer out.deinit(allocator);

        if (!out.ok()) {
            exit_code = 1;
            if (!svg_only and !dont_stop) std.process.exit(1);
        }
        if (svg_only) {
            try stdout.print("{s}\n", .{out.svg});
        } else {
            if (html_header_pending) {
                try stdout.writeAll(html_header);
                html_header_pending = false;
            }
            try stdout.print("<h1>File {s}</h1>\n", .{arg});
            if (!out.ok()) {
                try stdout.print("<p>ERROR</p>\n{s}\n", .{out.svg});
            } else {
                try stdout.print("<div id=\"svg-{d}\" onclick=\"toggleHidden('svg-{d}')\">\n", .{ arg_index, arg_index });
                try stdout.print("<div style='border:3px solid lightgray;max-width:{d}px;{s}'>\n", .{ out.width, style });
                try stdout.print("{s}</div>\n", .{out.svg});
                try stdout.writeAll("<pre class='hidden'>");
                try printEscapeHtml(stdout, input);
                try stdout.writeAll("</pre>\n</div>\n");
            }
        }
    }

    if (!svg_only) {
        try stdout.writeAll("</body></html>\n");
    }
    try stdout.flush();
    try stderr.flush();
    if (exit_code != 0) std.process.exit(exit_code);
}
