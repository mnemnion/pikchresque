const std = @import("std");
const OOM = std.mem.Allocator.Error;
const pik = @import("pikchr");

pub const plaintext_errors: u32 = pik.PIKCHR_PLAINTEXT_ERRORS;
pub const dark_mode: u32 = pik.PIKCHR_DARK_MODE;
pub const extra_unique_id: u32 = pik.PIKCHR_EXTRA_UNIQUE_ID;

/// The SVG rendering of a Pikchr diagram.
pub const PikchrSvg = struct {
    svg: [:0]u8,
    width: u32,
    height: u32,
    n_err: u32,

    pub fn deinit(rendered: *const PikchrSvg, allocator: std.mem.Allocator) void {
        allocator.free(rendered.svg);
    }

    pub fn ok(rendered: *const PikchrSvg) bool {
        return rendered.n_err == 0;
    }
};

/// Render a Pikchr diagram as an SVG.
pub fn pikchr(
    allocator: std.mem.Allocator,
    source: []const u8,
    class: []const u8,
    flags: u32,
) OOM!PikchrSvg {
    const out = try pik.render(allocator, source, class, flags);
    return .{
        .svg = out.text,
        .width = out.width,
        .height = out.height,
        .n_err = out.n_err,
    };
}

test "empty input renders the upstream empty diagram marker" {
    const out = try pikchr(std.testing.allocator, "", "pikchr", 0);
    defer out.deinit(std.testing.allocator);
    try std.testing.expect(out.ok());
    try std.testing.expectEqualStrings("<!-- empty pikchr diagram -->\n", out.svg);
}

test "SVG dimensions are unsigned" {
    try std.testing.expect(@TypeOf(@as(PikchrSvg, undefined).width) == u32);
    try std.testing.expect(@TypeOf(@as(PikchrSvg, undefined).height) == u32);
}
