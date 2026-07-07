const std = @import("std");
const OOM = std.mem.Allocator.Error;
const pik = @import("pikchr");

pub const plaintext_errors: u32 = pik.PIKCHR_PLAINTEXT_ERRORS;
pub const dark_mode: u32 = pik.PIKCHR_DARK_MODE;
pub const extra_unique_id: u32 = pik.PIKCHR_EXTRA_UNIQUE_ID;
pub const pik_single_color = pik.PIKCHR_SINGLE_COLOR;

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

/// Configurable options for Pikchr rendering.
pub const PikOptions = packed struct(u32) {
    plaintext_errors: bool,
    dark_mode: bool,
    extra_unique_id: bool,
    single_color: bool,
    reserved: u28 = 0,

    pub const default: PikOptions = .{
        .plaintext_errors = false,
        .dark_mode = false,
        .extra_unique_id = false,
        .single_color = false,
    };
};

/// Render a Pikchr diagram as an SVG.
pub fn pikchr(
    allocator: std.mem.Allocator,
    source: []const u8,
    class: []const u8,
    options: PikOptions,
) OOM!PikchrSvg {
    const out = try pik.render(allocator, source, class, @bitCast(options));
    return .{
        .svg = out.text,
        .width = out.width,
        .height = out.height,
        .n_err = out.n_err,
    };
}

test "empty input renders the upstream empty diagram marker" {
    const out = try pikchr(std.testing.allocator, "", "pikchr", PikOptions.default);
    defer out.deinit(std.testing.allocator);
    try std.testing.expect(out.ok());
    try std.testing.expectEqualStrings("<!-- empty pikchr diagram -->\n", out.svg);
}

test "SVG dimensions are unsigned" {
    try std.testing.expect(@TypeOf(@as(PikchrSvg, undefined).width) == u32);
    try std.testing.expect(@TypeOf(@as(PikchrSvg, undefined).height) == u32);
}

test "Pik options default has no flags" {
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(PikOptions.default)));
}

test "Pik options map to C flags" {
    var options = PikOptions.default;
    options.plaintext_errors = true;
    try std.testing.expectEqual(
        plaintext_errors,
        @as(u32, @bitCast(options)),
    );

    options = PikOptions.default;
    options.dark_mode = true;
    try std.testing.expectEqual(
        dark_mode,
        @as(u32, @bitCast(options)),
    );

    options = PikOptions.default;
    options.extra_unique_id = true;
    try std.testing.expectEqual(
        extra_unique_id,
        @as(u32, @bitCast(options)),
    );

    options = PikOptions.default;
    options.single_color = true;
    try std.testing.expectEqual(
        pik_single_color,
        @as(u32, @bitCast(options)),
    );
}
