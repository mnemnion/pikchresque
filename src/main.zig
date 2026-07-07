const std = @import("std");
const pikchresque = @import("pikchresque");

const pik_classic = false; // If this is true, classic pikchr html will be generated

const classic_html_header =
    \\<!DOCTYPE html>
    \\<html lang="en-US">
    \\<head><title>PIKCHR Test</title>\n
    \\<style>
    \\  .hidden {
    \\     position: absolute !important;
    \\     opacity: 0 !important;
    \\     pointer-events: none !important;
    \\     display: none !important;
    \\  }
    \\</style>
    \\<script>
    \\  function toggleHidden(id){
    \\    for(var c of document.getElementById(id).children){
    \\      c.classList.toggle('hidden');
    \\    }
    \\  }
    \\</script>
    \\<meta charset="utf-8">
    \\</head>
    \\<body>
;

const html_header =
    \\<!DOCTYPE html>
    \\<html lang="en-US">
    \\<head>
    \\<title>PIKCHR Test</title>
    \\<meta charset="utf-8">
    \\<meta name="viewport" content="width=device-width, initial-scale=1">
    \\<style>
    \\  html {
    \\    height: 100%;
    \\  }
    \\  :root {
    \\    color-scheme: light dark;
    \\    background: Canvas;
    \\    color: CanvasText;
    \\  }
    \\  :root[data-theme="light"] {
    \\    color-scheme: light;
    \\  }
    \\  :root[data-theme="dark"] {
    \\    color-scheme: dark;
    \\  }
    \\  body {
    \\    height: 100%;
    \\    margin: 0;
    \\    background: Canvas;
    \\    color: CanvasText;
    \\    font-family: system-ui, sans-serif;
    \\  }
    \\  section {
    \\    box-sizing: border-box;
    \\    display: grid;
    \\    gap: 1rem;
    \\    grid-template-rows: auto minmax(0, 1fr);
    \\    height: 100vh;
    \\    height: 100dvh;
    \\    overflow: hidden;
    \\    padding: 1rem;
    \\  }
    \\  section.no-title {
    \\    grid-template-rows: minmax(0, 1fr);
    \\  }
    \\  .diagram {
    \\    display: contents;
    \\  }
    \\  .diagram h1 {
    \\    font-size: 1rem;
    \\    font-weight: 600;
    \\    margin: 0;
    \\  }
    \\  .viewport {
    \\    height: 100%;
    \\    min-height: 0;
    \\    min-width: 0;
    \\    overflow: hidden;
    \\    width: 100%;
    \\  }
    \\  .viewport svg {
    \\    display: block;
    \\    height: 100%;
    \\    width: 100%;
    \\  }
    \\  pre {
    \\    box-sizing: border-box;
    \\    height: 100%;
    \\    margin: 0;
    \\    overflow: auto;
    \\    padding: 1rem;
    \\    white-space: pre-wrap;
    \\  }
    \\  .theme-toggle {
    \\    background: Canvas;
    \\    border: 0.18rem solid CanvasText;
    \\    border-radius: 999px;
    \\    color: CanvasText;
    \\    cursor: pointer;
    \\    height: 1.7rem;
    \\    padding: 0;
    \\    position: fixed;
    \\    right: 0.75rem;
    \\    top: 0.75rem;
    \\    width: 3.25rem;
    \\    z-index: 1;
    \\  }
    \\  .theme-toggle::before {
    \\    border: 0.18rem solid CanvasText;
    \\    border-radius: 50%;
    \\    box-sizing: border-box;
    \\    content: "";
    \\    height: 1.7rem;
    \\    left: -0.18rem;
    \\    position: absolute;
    \\    top: -0.18rem;
    \\    transition: transform 120ms ease;
    \\    width: 1.7rem;
    \\  }
    \\  :root[data-theme="light"] .theme-toggle::before {
    \\    transform: translateX(1.55rem);
    \\  }
    \\  .hidden {
    \\    display: none !important;
    \\  }
    \\</style>
    \\<script>
    \\  function toggleHidden(id){
    \\    for(var c of document.getElementById(id).children){
    \\      c.classList.toggle('hidden');
    \\    }
    \\  }
    \\  function setTheme(theme){
    \\    document.documentElement.dataset.theme = theme;
    \\    document.getElementById('theme-toggle').setAttribute('aria-pressed', theme == 'dark');
    \\    for(var svg of document.querySelectorAll('svg.pikchr')){
    \\      svg.style.colorScheme = theme;
    \\    }
    \\  }
    \\  function toggleTheme(event){
    \\    event.stopPropagation();
    \\    var root = document.documentElement;
    \\    var current = root.dataset.theme || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    \\    setTheme(current == 'dark' ? 'light' : 'dark');
    \\  }
    \\  addEventListener('DOMContentLoaded', function(){
    \\    var theme = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    \\    setTheme(theme);
    \\  });
    \\</script>
    \\</head>
    \\<body>
    \\<button
    \\   aria-label="Toggle light or dark mode"
    \\   aria-pressed="false"
    \\   class="theme-toggle"
    \\   id="theme-toggle"
    \\   onclick="toggleTheme(event)"
    \\   type="button">
    \\</button>
;

fn usage(stderr: *std.Io.Writer, argv0: []const u8) !void {
    try stderr.print("usage: {s} [OPTIONS] FILE ...\n", .{argv0});
    try stderr.writeAll(
        \\Convert Pikchr input files into SVG.  Filename "-" means stdin.
        \\    All output goes to stdout.
        \\    Options:
        \\       --dark-mode      Generate dark-mode output if single-color is set
        \\       --dont-stop      Process all files even if earlier files have errors
        \\       --single-color   Generate single-color light output
        \\       --svg-only       Emit raw SVG without the HTML wrapper
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

fn writeHtmlHeader(stdout: *std.Io.Writer) !void {
    if (pik_classic) {
        try stdout.writeAll(classic_html_header);
    } else {
        try stdout.writeAll(html_header);
    }
}

fn writeHtmlOutput(
    stdout: *std.Io.Writer,
    input: []const u8,
    out: pikchresque.PikchrSvg,
    arg: []const u8,
    arg_index: usize,
    style: []const u8,
) !void {
    if (pik_classic) {
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
        return;
    }

    const has_title = !std.mem.eql(u8, arg, "-");
    if (has_title) {
        try stdout.print("<section id=\"svg-{d}\" onclick=\"toggleHidden('svg-{d}')\">\n", .{ arg_index, arg_index });
    } else {
        try stdout.print("<section class=\"no-title\" id=\"svg-{d}\" onclick=\"toggleHidden('svg-{d}')\">\n", .{ arg_index, arg_index });
    }
    try stdout.writeAll("<div class=\"diagram\">\n");
    if (has_title) {
        try stdout.writeAll("<h1>");
        try printEscapeHtml(stdout, arg);
        try stdout.writeAll("</h1>\n");
    }
    try stdout.writeAll("<div class=\"viewport\">\n");
    try stdout.writeAll(out.svg);
    try stdout.writeAll("</div>\n</div>\n<pre class=\"hidden\">");
    try printEscapeHtml(stdout, input);
    try stdout.writeAll("</pre>\n</section>\n");
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
            } else if (std.mem.eql(u8, option, "single-color")) {
                options.single_color = true;
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
                try writeHtmlHeader(stdout);
                html_header_pending = false;
            }
            try writeHtmlOutput(stdout, input, out, arg, arg_index, style);
        }
    }

    if (!svg_only) {
        try stdout.writeAll("</body></html>\n");
    }
    try stdout.flush();
    try stderr.flush();
    if (exit_code != 0) std.process.exit(exit_code);
}
