const std = @import("std");

pub const plaintext_errors: u32 = 0x0001;
pub const dark_mode: u32 = 0x0002;
pub const extra_unique_id: u32 = 0x0004;

extern fn pikchr(
    zText: [*:0]const u8,
    zClass: [*:0]const u8,
    mFlags: c_uint,
    pnWidth: ?*c_int,
    pnHeight: ?*c_int,
) ?[*:0]u8;

pub const Rendered = struct {
    text: [:0]u8,
    width: i32,
    height: i32,

    pub fn deinit(rendered: Rendered) void {
        std.c.free(rendered.text.ptr);
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
    const source_z = allocator.dupeZ(u8, source) catch return error.OutOfMemory;
    defer allocator.free(source_z);

    const class_z = allocator.dupeZ(u8, class) catch return error.OutOfMemory;
    defer allocator.free(class_z);

    var width: c_int = 0;
    var height: c_int = 0;
    const out = pikchr(source_z.ptr, class_z.ptr, @intCast(flags), &width, &height) orelse {
        return error.OutOfMemory;
    };

    return .{
        .text = std.mem.span(out),
        .width = @intCast(width),
        .height = @intCast(height),
    };
}

test "empty input renders the upstream empty diagram marker" {
    const out = try render(std.testing.allocator, "", "pikchr", 0);
    defer out.deinit();
    try std.testing.expect(out.ok());
    try std.testing.expectEqualStrings("<!-- empty pikchr diagram -->\n", out.text);
}
