//! Role-specific dark-mode transitions in OKLCH. Light-mode colors are unchanged.

/// The visual role of a diagram color, independent of SVG fill versus stroke.
pub const Role = enum { accent, background, text };

/// Convert packed sRGB to a dark-mode color, preserving OKLCH hue and chroma
/// until memex maps the result back into the sRGB gamut.
pub fn convert(rgb_value: i32, role: Role) i32 {
    var color = Rgb.fromPacked(rgb_value).toOklch();
    color.l = switch (role) {
        .accent => accentLightness(color.l, color.c),
        .background => backgroundLightness(color.l, color.c),
        .text => textLightness(color.l, color.c),
    };
    return color.toRgb().toPacked(i32);
}

fn accentLightness(lightness: f64, chroma: f64) f64 {
    const colored = 0.35 + 0.45 * lightness;
    const neutral = 0.85 + 0.10 * lightness;
    return neutral + smoothstep(chroma / NEUTRAL_CHROMA) * (colored - neutral);
}

fn backgroundLightness(lightness: f64, chroma: f64) f64 {
    // Keep pale neutrals bright, but give colored text room above tinted fills.
    const highlight = 0.08 - 0.18 * smoothstep(chroma / NEUTRAL_CHROMA);
    return 0.12 + 0.55 * lightness + highlight * smoothstep(2.0 * lightness - 1.0);
}

fn textLightness(lightness: f64, chroma: f64) f64 {
    // A gentler lift leaves more sRGB chroma available for darker colors.
    const colored = 0.36 + 0.59 * lightness;
    const neutral = 0.95 + 0.04 * lightness;
    const weight = smoothstep(chroma / NEUTRAL_CHROMA);
    return neutral + weight * (colored - neutral);
}

fn smoothstep(value: f64) f64 {
    const t = std.math.clamp(value, 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

const NEUTRAL_CHROMA: f64 = 0.04;

//| Tests

const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

test "dark gray ramps remain neutral and preserve lightness order for every role" {
    for ([_]Role{ .accent, .background, .text }) |role| {
        var previous: f64 = -1.0;
        for ([_]i32{ 0, 0x333333, 0x808080, 0xcccccc, 0xffffff }) |rgb_value| {
            const converted = Rgb.fromPacked(convert(rgb_value, role));
            try expectApproxEqAbs(converted.r, converted.g, 1.0 / 255.0);
            try expectApproxEqAbs(converted.g, converted.b, 1.0 / 255.0);
            const lightness = converted.toOklch().l;
            try expect(lightness > previous);
            previous = lightness;
        }
        const black = Rgb.fromPacked(convert(0, role)).toOklch().l;
        const white = Rgb.fromPacked(convert(0xffffff, role)).toOklch().l;
        const endpoints: [2]f64 = switch (role) {
            .background => .{ 0.12, 0.75 },
            .text => .{ 0.95, 0.99 },
            .accent => .{ 0.85, 0.95 },
        };
        try expectApproxEqAbs(endpoints[0], black, 0.005);
        try expectApproxEqAbs(endpoints[1], white, 0.005);
    }
}

test "dark colors retain hue for an in-gamut muted color" {
    const original = Rgb.fromPacked(0x668899).toOklch();
    for ([_]Role{ .accent, .background, .text }) |role| {
        const converted = Rgb.fromPacked(convert(0x668899, role)).toOklch();
        try expectApproxEqAbs(original.h, converted.h, 2.0);
        try expectApproxEqAbs(original.c, converted.c, 0.005);
    }
}

test "dark colors map saturated primaries and secondaries into sRGB" {
    for ([_]i32{ 0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 0x00ffff, 0xff00ff }) |rgb_value| {
        for ([_]Role{ .accent, .background, .text }) |role| {
            const converted = convert(rgb_value, role);
            try expect(converted >= 0 and converted <= 0xffffff);
            const lightness = Rgb.fromPacked(converted).toOklch().l;
            const original = Rgb.fromPacked(rgb_value).toOklch();
            const original_lightness = original.l;
            const expected = switch (role) {
                .accent => 0.35 + 0.45 * original_lightness,
                .background => backgroundLightness(original_lightness, original.c),
                .text => 0.36 + 0.59 * original_lightness,
            };
            try expectApproxEqAbs(expected, lightness, 0.025);
        }
    }
}

test "near-neutral text stays bright without acquiring a color cast" {
    for ([_]i32{ 0x202020, 0x202122, 0x222120, 0x212022 }) |rgb_value| {
        const original = Rgb.fromPacked(rgb_value).toOklch();
        const converted = Rgb.fromPacked(convert(rgb_value, .text)).toOklch();
        try expect(converted.l > 0.94);
        try expectApproxEqAbs(original.c, converted.c, 0.005);
    }
}

test "text correction fades continuously into the colored text curve" {
    const lightness: f64 = 0.5;
    var previous = textLightness(lightness, 0.0);
    for (1..101) |step| {
        const chroma = @as(f64, @floatFromInt(step)) * 0.0005;
        const current = textLightness(lightness, chroma);
        try expect(current <= previous);
        try expect(previous - current < 0.006);
        previous = current;
    }
    try expectApproxEqAbs(@as(f64, 0.655), previous, 0.000001);
}

test "neutral borders separate from even the brightest fills" {
    const brightest_fill = Rgb.fromPacked(convert(0xffffff, .background)).toOklch().l;
    for ([_]i32{ 0, 0x202020, 0x202122, 0x222120, 0x212022 }) |rgb_value| {
        const original = Rgb.fromPacked(rgb_value).toOklch();
        const border = Rgb.fromPacked(convert(rgb_value, .accent)).toOklch();
        try expect(border.l - brightest_fill > 0.09);
        try expect(border.l < 0.90);
        try expectApproxEqAbs(original.c, border.c, 0.005);
    }
}

test "fill lift preserves dark tones and increases smoothly toward white" {
    for ([_]f64{ 0.0, 0.25, 0.5 }) |lightness| {
        try expectApproxEqAbs(0.12 + 0.55 * lightness, backgroundLightness(lightness, 0), 0.000001);
    }
    try expectApproxEqAbs(@as(f64, 0.5725), backgroundLightness(0.75, 0), 0.000001);
    var previous = backgroundLightness(0.5, 0);
    for (1..101) |step| {
        const lightness = 0.5 + @as(f64, @floatFromInt(step)) * 0.005;
        const current = backgroundLightness(lightness, 0);
        try expect(current > previous);
        try expect(current - previous < 0.005);
        previous = current;
    }
}

test "colored labels separate from their tinted fills and retain chroma" {
    // The troublesome top row of the roles diagram: red/pink, blue/light blue,
    // green/pale green. Check the final sRGB colors, after gamut mapping.
    const pairs = [_][2]i32{
        .{ 0xff0000, 0xffb6c1 },
        .{ 0x0000ff, 0xadd8e6 },
        .{ 0x008000, 0x98fb98 },
    };
    for (pairs) |pair| {
        const text = Rgb.fromPacked(convert(pair[0], .text)).toOklch();
        const fill = Rgb.fromPacked(convert(pair[1], .background)).toOklch();
        // The tuning trades some lightness separation for stronger text chroma
        // at the chosen fill weight; it is not a background-aware contrast guarantee.
        try expect(text.l - fill.l > 0.10);
        try expect(text.c > 0.17);
    }
}

test "tinted fill curves remain continuous and monotonic" {
    for ([_]f64{ 0.0, 0.01, 0.02, 0.03, 0.04, 0.2 }) |chroma| {
        var previous = backgroundLightness(0, chroma);
        for (1..201) |step| {
            const lightness = @as(f64, @floatFromInt(step)) / 200.0;
            const current = backgroundLightness(lightness, chroma);
            try expect(current > previous);
            try expect(current - previous < 0.005);
            previous = current;
        }
    }
}

const std = @import("std");
const Rgb = @import("memex_color").Rgb;
