# Responsive color

The plan here is to emit `light-dark` responsive color schemes.

Currently, there's a DARKMODE flag, and when set, the doc is emitted in
a rather nice mirrored color scheme.  So the conversion part is already
sorted out, the problem is that the colors themselves are written into
the SVG directly.


## Class generator

Basically we need a `HashMap(f64, [4]u8)` for `fill` and `stroke`
values, and a `[4]u8` on `Pik` which is, idk, `varGen`.  Each time a
`PVar` is retrieved for `textcolor` or `fill` (fill) or for `color`
(stroke), we try to find it in the HashMap, if we don't, we generate a
new `varGen` name and insert that.  These go: `a`, `b`, `aa`, `ab`, and
so on.  We're not going to run out, there are limits put on the number
of tokens in a Pik script which make that impossible by construction.

Then, let's say `fill` ended up with `a` and `c`: when we emit the CSS,
we turn those into `#_fa` and `#_fc`.  Then we replace the style
generators with class emitters: everything is already taking classes,
so we just give it `_fa`, `_fc`.  Stroke, same thing, but it's `#_sb`,
`_sb`.  We still store the color as an `f64`, just now we're using it as
a key.

We'll add the _responsive_ CSS last, right now, this is just replacing
all the stroke and fill inline styles with top-level class-directed
CSS.  Easy to make it responsive once that's in.

This neatly avoids any thinking about variables and such: we care only
when they're used as colors, and not otherwise.  Looks like the right
place to find the values is `pik_after_adding_attributes`, that
prevents us from making a color class for the default value (black) if
it never actually gets used, however rare that might be.

There's a little more to it, mostly tracking transparency, which is
also visible by `pik_after_adding_attributes`: if we're not going
to use `fill` then we don't want to hash it.  But not much, this is
basically it.
