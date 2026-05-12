const std = @import("std");
const pikchr = @import("pikchr");

pub const plaintext_errors: u32 = pikchr.PIKCHR_PLAINTEXT_ERRORS;
pub const dark_mode: u32 = pikchr.PIKCHR_DARK_MODE;
pub const extra_unique_id: u32 = pikchr.PIKCHR_EXTRA_UNIQUE_ID;

pub const Rendered = struct {
    allocator: std.mem.Allocator,
    text: []u8,
    width: i32,
    height: i32,

    pub fn deinit(rendered: Rendered) void {
        rendered.allocator.free(rendered.text);
    }

    pub fn ok(rendered: Rendered) bool {
        return rendered.width >= 0;
    }
};

pub const RenderError = error{OutOfMemory};

pub fn render(
    allocator: std.mem.Allocator,
    source: []const u8,
    class: []const u8,
    flags: u32,
) RenderError!Rendered {
    const out = try pikchr.render(allocator, source, class, flags);
    return .{
        .allocator = allocator,
        .text = out.text,
        .width = out.width,
        .height = out.height,
    };
}

test "empty input renders the upstream empty diagram marker" {
    const out = try render(std.testing.allocator, "", "pikchr", 0);
    defer out.deinit();
    try std.testing.expect(out.ok());
    try std.testing.expectEqualStrings("<!-- empty pikchr diagram -->\n", out.text);
}
