const std = @import("std");
const pikchresque = @import("pikchresque.zig");

pub const PIKCHR_PLAINTEXT_ERRORS: c_uint = pikchresque.plaintext_errors;
pub const PIKCHR_DARK_MODE: c_uint = pikchresque.dark_mode;
pub const PIKCHR_EXTRA_UNIQUE_ID: c_uint = pikchresque.extra_unique_id;
pub const PIKCHR_SINGLE_COLOR: c_uint = pikchresque.pik_single_color;

/// Parse the zero-terminated Pikchr script in `source`.
///
/// On success, returns an SVG rendering. If the script contains an error,
/// returns the error text instead. Error text is HTML-formatted and safe to
/// insert into an HTML output stream unless `PIKCHR_PLAINTEXT_ERRORS` is set
/// in `flags`.
///
/// `flags` is a bitwise combination of the `PIKCHR_*` constants.
///
/// If `width` or `height` is non-null, the corresponding SVG dimension is
/// written through it. Each supplied dimension is set to `-1` when the script
/// contains an error.
///
/// If `class` is non-null, its value is included as the SVG class name.
///
/// The returned zero-terminated string is allocated by `malloc`; the caller
/// must release it with `free`. Returns null only if allocation fails.
export fn pikchr(
    source: [*:0]const u8,
    class: ?[*:0]const u8,
    flags: c_uint,
    width: ?*c_int,
    height: ?*c_int,
) ?[*:0]u8 {
    const options: pikchresque.PikOptions = @bitCast(@as(u32, @intCast(flags)));
    const rendered = pikchresque.pikchr(
        std.heap.c_allocator,
        std.mem.span(source),
        if (class) |name| std.mem.span(name) else "",
        options,
    ) catch return null;

    const ok = rendered.ok();
    if (width) |out| out.* = if (ok) @intCast(rendered.width) else -1;
    if (height) |out| out.* = if (ok) @intCast(rendered.height) else -1;
    return rendered.svg.ptr;
}

test "C interface returns malloc-owned output" {
    var width: c_int = undefined;
    var height: c_int = undefined;
    const output = pikchr("", "pikchr", 0, &width, &height).?;
    defer std.c.free(output);

    try std.testing.expectEqualStrings(
        "<!-- empty pikchr diagram -->\n",
        std.mem.span(output),
    );
    try std.testing.expectEqual(@as(c_int, 0), width);
    try std.testing.expectEqual(@as(c_int, 0), height);
}

test "C interface accepts optional output arguments" {
    const output = pikchr("", null, PIKCHR_PLAINTEXT_ERRORS, null, null).?;
    defer std.c.free(output);

    try std.testing.expectEqualStrings(
        "<!-- empty pikchr diagram -->\n",
        std.mem.span(output),
    );
}

test "C interface reports rendering errors with negative dimensions" {
    var width: c_int = undefined;
    var height: c_int = undefined;
    const output = pikchr(
        "box width\n",
        "pikchr",
        PIKCHR_PLAINTEXT_ERRORS,
        &width,
        &height,
    ).?;
    defer std.c.free(output);

    try std.testing.expectEqual(@as(c_int, -1), width);
    try std.testing.expectEqual(@as(c_int, -1), height);
}
